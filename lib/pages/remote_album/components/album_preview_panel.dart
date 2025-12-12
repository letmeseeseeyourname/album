// album/components/album_preview_panel.dart (增强版 - 添加重试机制)
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../network/constant_sign.dart';
import '../../../network/utils/dev_environment_helper.dart';
import '../../../user/models/resource_list_model.dart';
import '../../../user/my_instance.dart';
import '../../../user/provider/mine_provider.dart';

/// 预览重试配置
class PreviewRetryConfig {
  static const int maxImageRetries = 3; // 图片最大重试次数
  static const int maxVideoRetries = 3; // 视频最大重试次数
  static const int retryDelaySeconds = 2; // 重试延迟（秒）
  static const int warmUpTimeoutSeconds = 5; // 预热超时（秒）
}

/// 相册预览面板
/// 修复：图片预览被压缩的问题
class AlbumPreviewPanel extends StatefulWidget {
  final List<ResList> mediaItems;
  final int previewIndex;
  final VoidCallback onClose;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool canGoPrevious;
  final bool canGoNext;

  const AlbumPreviewPanel({
    super.key,
    required this.mediaItems,
    required this.previewIndex,
    required this.onClose,
    required this.onPrevious,
    required this.onNext,
    required this.canGoPrevious,
    required this.canGoNext,
  });

  @override
  State<AlbumPreviewPanel> createState() => _AlbumPreviewPanelState();
}

class _AlbumPreviewPanelState extends State<AlbumPreviewPanel> {
  Player? _videoPlayer;
  VideoController? _videoController;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  bool _showControls = true;

  // 用于触发图片重新加载的 key
  int _imageReloadKey = 0;

  // 🆕 重试相关状态
  int _imageRetryCount = 0;
  int _videoRetryCount = 0;
  bool _isImageLoading = false;
  bool _isVideoLoading = false;
  bool _imageLoadFailed = false;
  bool _videoLoadFailed = false;
  String? _lastImageError;
  String? _lastVideoError;
  Timer? _retryTimer;

  // 🆕 连接预热
  final Dio _dio = Dio();
  bool _isConnectionWarmedUp = false;
  DateTime? _lastWarmUpTime;
  static const Duration _warmUpValidDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    // 🆕 先预热连接，再加载媒体
    _warmUpAndLoadMedia();
  }

  @override
  void didUpdateWidget(AlbumPreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.previewIndex != widget.previewIndex) {
      // 🆕 切换媒体时重置所有状态
      _resetRetryState();
      _loadMedia();
    }
  }

  /// 🆕 重置重试状态
  void _resetRetryState() {
    _imageReloadKey = 0;
    _imageRetryCount = 0;
    _videoRetryCount = 0;
    _isImageLoading = false;
    _isVideoLoading = false;
    _imageLoadFailed = false;
    _videoLoadFailed = false;
    _lastImageError = null;
    _lastVideoError = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _disposeVideoPlayer();
    _dio.close();
    super.dispose();
  }

  /// 🆕 预热连接并加载媒体
  Future<void> _warmUpAndLoadMedia() async {
    await _warmUpConnection();
    _loadMedia();
  }

  /// 🆕 预热 MinIO 连接（唤醒 P2P 隧道）
  Future<bool> _warmUpConnection() async {
    // 检查预热是否仍有效
    if (_isConnectionWarmedUp && _lastWarmUpTime != null) {
      final elapsed = DateTime.now().difference(_lastWarmUpTime!);
      if (elapsed < _warmUpValidDuration) {
        debugPrint('[PreviewPanel] 连接预热仍有效，跳过预热');
        return true;
      }
    }

    final baseUrl = AppConfig.minio();
    debugPrint('[PreviewPanel] 开始预热连接: $baseUrl');

    try {
      await _dio.head(
        baseUrl,
        options: Options(
          sendTimeout: Duration(
              seconds: PreviewRetryConfig.warmUpTimeoutSeconds),
          receiveTimeout: Duration(
              seconds: PreviewRetryConfig.warmUpTimeoutSeconds),
          validateStatus: (status) => true,
        ),
      );

      _isConnectionWarmedUp = true;
      _lastWarmUpTime = DateTime.now();
      debugPrint('[PreviewPanel] 连接预热成功');
      return true;
    } catch (e) {
      debugPrint('[PreviewPanel] 连接预热失败: $e');

      // 等待后重试一次
      await Future.delayed(const Duration(milliseconds: 500));

      try {
        await _dio.head(
          baseUrl,
          options: Options(
            sendTimeout: Duration(
                seconds: PreviewRetryConfig.warmUpTimeoutSeconds),
            receiveTimeout: Duration(
                seconds: PreviewRetryConfig.warmUpTimeoutSeconds),
            validateStatus: (status) => true,
          ),
        );

        _isConnectionWarmedUp = true;
        _lastWarmUpTime = DateTime.now();
        debugPrint('[PreviewPanel] 连接预热第二次尝试成功');
        return true;
      } catch (e2) {
        debugPrint('[PreviewPanel] 连接预热第二次尝试也失败: $e2');
        return false;
      }
    }
  }

  void _loadMedia() {
    if (widget.previewIndex < 0 ||
        widget.previewIndex >= widget.mediaItems.length) {
      return;
    }

    final item = widget.mediaItems[widget.previewIndex];

    if (item.fileType == 'V') {
      final videoUrl = item.originPath ?? item.mediumPath ?? '';
      _initVideoPlayer(videoUrl);
    } else {
      _disposeVideoPlayer();
    }
  }

  void _initVideoPlayer(String url) {
    _disposeVideoPlayer();

    if (url.isEmpty) return;

    _isVideoLoading = true;
    _videoLoadFailed = false;
    _lastVideoError = null;

    if (mounted) setState(() {});

    _videoPlayer = Player();
    _videoController = VideoController(_videoPlayer!);

    final fullUrl = "${AppConfig.minio()}/$url";
    debugPrint('[PreviewPanel] 加载视频: $fullUrl');

    _videoPlayer!.open(Media(fullUrl));

    _videoPlayer!.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
          // 🆕 播放成功，重置重试计数
          if (playing) {
            _isVideoLoading = false;
            _videoLoadFailed = false;
            _videoRetryCount = 0;
          }
        });
      }
    });

    _videoPlayer!.stream.position.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _videoPlayer!.stream.duration.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
          // 🆕 获取到时长说明加载成功
          if (duration.inSeconds > 0) {
            _isVideoLoading = false;
            _videoLoadFailed = false;
          }
        });
      }
    });

    _videoPlayer!.stream.volume.listen((volume) {
      if (mounted) {
        setState(() {
          _volume = volume / 100;
        });
      }
    });

    // 🆕 监听错误
    _videoPlayer!.stream.error.listen((error) {
      if (mounted && error.isNotEmpty) {
        debugPrint('[PreviewPanel] 视频加载错误: $error');
        _handleVideoLoadError(error, url);
      }
    });
  }

  /// 🆕 处理视频加载错误
  void _handleVideoLoadError(String error, String url) {
    _lastVideoError = error;

    if (_videoRetryCount < PreviewRetryConfig.maxVideoRetries) {
      _videoRetryCount++;
      debugPrint('[PreviewPanel] 视频重试 $_videoRetryCount/${PreviewRetryConfig
          .maxVideoRetries}');

      // 标记需要重新预热
      _isConnectionWarmedUp = false;

      // 延迟后重试
      _retryTimer?.cancel();
      _retryTimer = Timer(
        Duration(seconds: PreviewRetryConfig.retryDelaySeconds),
            () async {
          if (mounted) {
            await _warmUpConnection();
            _initVideoPlayer(url);
          }
        },
      );

      _checkNetwork();
      setState(() {
        _isVideoLoading = true;
      });
    } else {
      // 超过最大重试次数
      setState(() {
        _isVideoLoading = false;
        _videoLoadFailed = true;
      });
      debugPrint('[PreviewPanel] 视频加载失败，已达最大重试次数');
    }
  }

  /// 🆕 手动重试视频
  void _retryVideo() {
    if (widget.previewIndex < 0 ||
        widget.previewIndex >= widget.mediaItems.length) {
      return;
    }

    final item = widget.mediaItems[widget.previewIndex];
    if (item.fileType != 'V') return;

    final videoUrl = item.originPath ?? item.mediumPath ?? '';
    if (videoUrl.isEmpty) return;

    // 重置重试计数
    _videoRetryCount = 0;
    _videoLoadFailed = false;
    _lastVideoError = null;
    _isConnectionWarmedUp = false;

    setState(() {
      _isVideoLoading = true;
    });

    // 预热后重新加载
    _warmUpConnection().then((_) {
      if (mounted) {
        _initVideoPlayer(videoUrl);
      }
    });
  }

  void _disposeVideoPlayer() {
    _videoPlayer?.dispose();
    _videoPlayer = null;
    _videoController = null;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _volume = 1.0;
  }

  void _togglePlayPause() {
    _videoPlayer?.playOrPause();
  }

  void _seekTo(Duration position) {
    _videoPlayer?.seek(position);
  }

  void _setVolume(double volume) {
    _videoPlayer?.setVolume(volume * 100);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.previewIndex < 0 ||
        widget.previewIndex >= widget.mediaItems.length) {
      return const SizedBox.shrink();
    }

    final item = widget.mediaItems[widget.previewIndex];

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildHeader(item),
          Expanded(
            child: _buildMediaContent(item),
          ),
        ],
      ),
    );
  }

  /// 顶部标题栏
  Widget _buildHeader(ResList item) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              item.fileName ?? 'Unknown',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${widget.previewIndex + 1} / ${widget.mediaItems.length}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onClose,
            tooltip: '关闭预览',
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
          ),
        ],
      ),
    );
  }

  /// 媒体内容区 - 修复版
  Widget _buildMediaContent(ResList item) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Stack(
        children: [
          // 🔑 修复：使用 Positioned.fill 确保图片/视频填满整个区域
          Positioned.fill(
            child: item.fileType == 'V'
                ? _buildVideoPreview()
                : _buildImagePreview(item),
          ),

          // 左侧切换按钮
          if (widget.canGoPrevious)
            Positioned(
              left: 16,
              top: 0,
              bottom: item.fileType == 'V' ? 64 : 0,
              child: Center(
                child: _buildNavigationButton(
                  icon: Icons.chevron_left,
                  onPressed: widget.onPrevious,
                  tooltip: '上一个',
                ),
              ),
            ),

          // 右侧切换按钮
          if (widget.canGoNext)
            Positioned(
              right: 16,
              top: 0,
              bottom: item.fileType == 'V' ? 64 : 0,
              child: Center(
                child: _buildNavigationButton(
                  icon: Icons.chevron_right,
                  onPressed: widget.onNext,
                  tooltip: '下一个',
                ),
              ),
            ),

          // 视频播放/暂停按钮
          if (item.fileType == 'V' && _videoController != null && !_isPlaying)
            Positioned.fill(
              bottom: 64,
              child: Center(
                child: IconButton(
                  icon: Icon(
                    Icons.play_circle_outline,
                    size: 80,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  onPressed: _togglePlayPause,
                ),
              ),
            ),

          // 视频控制栏
          if (item.fileType == 'V' && _videoController != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildVideoControls(),
            ),
        ],
      ),
    );
  }

  /// 导航按钮
  Widget _buildNavigationButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 28),
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: 28,
        padding: const EdgeInsets.all(12),
      ),
    );
  }

  /// 视频预览 - 增强版：带重试机制
  Widget _buildVideoPreview() {
    // 🆕 视频加载失败
    if (_videoLoadFailed) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam_off,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              const Text(
                '视频加载失败',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              if (_lastVideoError != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _lastVideoError!,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _retryVideo,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重新加载'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 🆕 视频加载中
    if (_videoController == null || _isVideoLoading) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Video(
        controller: _videoController!,
        controls: NoVideoControls,
      ),
    );
  }

  /// 图片预览 - 增强版：带自动重试
  Widget _buildImagePreview(ResList item) {
    final imageUrl = item.originPath ?? item.mediumPath ?? item.thumbnailPath;

    if (imageUrl == null || imageUrl.isEmpty) {
      return Center(
        child: Icon(
          Icons.image,
          size: 64,
          color: Colors.grey.shade400,
        ),
      );
    }

    return Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: CachedNetworkImage(
        key: ValueKey('${item.resId ?? imageUrl}_$_imageReloadKey'),
        imageUrl: "${AppConfig.minio()}/$imageUrl",
        cacheKey: '${item.resId ?? imageUrl}_$_imageReloadKey',
        fit: BoxFit.contain,
        alignment: Alignment.center,
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
        placeholder: (context, url) =>
        const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) {
          debugPrint('[PreviewPanel] 图片加载失败: $imageUrl, $error');

          // 🆕 检查是否需要自动重试
          if (_imageRetryCount < PreviewRetryConfig.maxImageRetries &&
              !_imageLoadFailed) {
            // 延迟后自动重试
            Future.delayed(
              Duration(seconds: PreviewRetryConfig.retryDelaySeconds),
                  () {
                if (mounted && !_imageLoadFailed) {
                  _imageRetryCount++;
                  debugPrint(
                      '[PreviewPanel] 图片自动重试 $_imageRetryCount/${PreviewRetryConfig
                          .maxImageRetries}');
                  _isConnectionWarmedUp = false; // 标记需要重新预热
                  _warmUpConnection().then((_) {
                    if (mounted) {
                      setState(() {
                        _imageReloadKey++;
                      });
                    }
                  });
                }
              },
            );

            _checkNetwork();
            // 显示重试中状态
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                ],
              ),
            );
          }

          // 超过最大重试次数，显示失败界面
          return _buildImageErrorWidget(imageUrl, error.toString());
        },
      ),
    );
  }

  /// 🆕 图片加载失败界面
  Widget _buildImageErrorWidget(String imageUrl, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            '图片加载失败',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // 重置重试计数并重新加载
              _imageRetryCount = 0;
              _imageLoadFailed = false;
              _isConnectionWarmedUp = false;

              _warmUpConnection().then((_) {
                if (mounted) {
                  setState(() {
                    _imageReloadKey++;
                  });
                }
              });
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重新加载'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  /// 视频控制栏
  Widget _buildVideoControls() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                _formatDuration(_position.inSeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 10),
                  ),
                  child: Slider(
                    value: _duration.inSeconds > 0
                        ? _position.inSeconds / _duration.inSeconds
                        : 0,
                    onChanged: (value) {
                      final position = Duration(
                        seconds: (value * _duration.inSeconds).toInt(),
                      );
                      _seekTo(position);
                    },
                    activeColor: Colors.orange,
                    inactiveColor: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
              Text(
                _formatDuration(_duration.inSeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: _togglePlayPause,
                tooltip: _isPlaying ? '暂停' : '播放',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                _volume == 0
                    ? Icons.volume_off
                    : _volume < 0.5
                    ? Icons.volume_down
                    : Icons.volume_up,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 80,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 4),
                    overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 8),
                  ),
                  child: Slider(
                    value: _volume,
                    onChanged: (value) {
                      setState(() {
                        _volume = value;
                      });
                      _setVolume(value);
                    },
                    activeColor: Colors.orange,
                    inactiveColor: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs
          .toString()
          .padLeft(2, '0')}';
    } else {
      return '$minutes:${secs.toString().padLeft(2, '0')}';
    }
  }

  ///p2p与局域网直接切换
  Future<void> _checkNetwork() async {
    var deviceCode = MyInstance().deviceCode;
    await MyNetworkProvider().getDevice(deviceCode);
    var p6IP = MyInstance().deviceModel?.p2pAddress;
    DevEnvironmentHelper().resetEnvironment(p6IP!);
  }
}