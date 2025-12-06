// pages/media_viewer_page.dart
// 统一的媒体查看器，支持本地文件和网络资源
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import '../models/media_item.dart';
import '../network/constant_sign.dart';

class MediaViewerPage extends StatefulWidget {
  final List<MediaItem> mediaItems;
  final int initialIndex;

  const MediaViewerPage({
    super.key,
    required this.mediaItems,
    required this.initialIndex,
  });

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  late int currentIndex;
  Player? _player;
  VideoController? _videoController;
  bool _isVideoInitialized = false;
  bool _isControlsVisible = true;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  double _volume = 100.0;
  bool _isFullScreen = false;

  // 鼠标悬停状态
  bool _isLeftHovered = false;
  bool _isRightHovered = false;
  bool _isTopHovered = false;

  // 拖动相关
  Offset _imagePosition = Offset.zero;
  double _scale = 1.0;
  double _baseScale = 1.0;

  // 视频状态
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // 控制栏自动隐藏计时器
  Timer? _hideControlsTimer;

  // 图片重载 key
  int _imageReloadKey = 0;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _loadCurrentMedia();
    _startHideControlsTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _disposeVideo();
    super.dispose();
  }

  void _loadCurrentMedia() {
    final currentItem = widget.mediaItems[currentIndex];

    if (currentItem.type == MediaItemType.video) {
      _initializeVideo(currentItem.getMediaSource());
    } else {
      _disposeVideo();
      _resetImageTransform();
    }
  }

  void _initializeVideo(String source) async {
    await _disposeVideo();

    try {
      _player = Player();
      _videoController = VideoController(_player!);

      _player!.stream.playing.listen((playing) {
        if (mounted) {
          setState(() {
            _isPlaying = playing;
          });
        }
      });

      _player!.stream.position.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      });

      _player!.stream.duration.listen((duration) {
        if (mounted) {
          setState(() {
            _duration = duration;
          });
        }
      });

      // 根据是本地还是网络资源加载
      final currentItem = widget.mediaItems[currentIndex];
      if (currentItem.sourceType == MediaSourceType.local) {
        await _player!.open(Media('file:///$source'));
      } else {
        // await _player!.open(Media(source));
        await _player!.open(Media("${AppConfig.minio()}/${source}"));
      }

      setState(() {
        _isVideoInitialized = true;
      });

      await _player!.play();
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法加载视频：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _disposeVideo() async {
    if (_player != null) {
      await _player!.dispose();
      _player = null;
      _videoController = null;
      _isVideoInitialized = false;
      _isPlaying = false;
      _position = Duration.zero;
      _duration = Duration.zero;
    }
  }

  void _resetImageTransform() {
    setState(() {
      _imagePosition = Offset.zero;
      _scale = 1.0;
      _baseScale = 1.0;
      _imageReloadKey = 0;
    });
  }

  void _navigateToPrevious() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
        _imageReloadKey = 0;
        _loadCurrentMedia();
      });
      _showControls(); // 切换媒体时显示控制栏
    }
  }

  void _navigateToNext() {
    if (currentIndex < widget.mediaItems.length - 1) {
      setState(() {
        currentIndex++;
        _imageReloadKey = 0;
        _loadCurrentMedia();
      });
      _showControls(); // 切换媒体时显示控制栏
    }
  }

  void _togglePlayPause() {
    if (_player != null && _isVideoInitialized) {
      if (_isPlaying) {
        _player!.pause();
      } else {
        _player!.play();
      }
      _showControls(); // 切换播放状态时显示控制栏
    }
  }

  void _changePlaybackSpeed(double speed) {
    if (_player != null && _isVideoInitialized) {
      _player!.setRate(speed);
    }

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _playbackSpeed = speed;
        });
      }
    });
  }

  void _changeVolume(double volume) {
    if (_player != null && _isVideoInitialized) {
      _player!.setVolume(volume);
      setState(() {
        _volume = volume;
      });
      _showControls(); // 调整音量时显示控制栏
    }
  }

  void _seekTo(Duration position) {
    if (_player != null && _isVideoInitialized) {
      _player!.seek(position);
      _showControls(); // 拖动进度时显示控制栏
    }
  }

  void _toggleFullScreen() async {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      await windowManager.setFullScreen(true);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      await windowManager.setFullScreen(false);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  // 启动自动隐藏控制栏的计时器
  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() {
          _isControlsVisible = false;
        });
      }
    });
  }

  // 显示控制栏并重启隐藏计时器
  void _showControls() {
    setState(() {
      _isControlsVisible = true;
    });
    _startHideControlsTimer();
  }

  // 处理鼠标移动
  void _onMouseMove() {
    if (!_isControlsVisible) {
      _showControls();
    } else {
      _startHideControlsTimer();
    }
  }

  void _showMediaInfo() {
    final currentItem = widget.mediaItems[currentIndex];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.01),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _MediaInfoDialog(item: currentItem, animation: animation);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );

        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(opacity: fadeAnimation, child: child),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${minutes}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.mediaItems[currentIndex];
    final isVideo = currentItem.type == MediaItemType.video;

    return Scaffold(
      backgroundColor: Colors.black,
      body: MouseRegion(
        onHover: (_) => _onMouseMove(),
        child: Stack(
          children: [
            // 主内容区域
            Center(child: isVideo ? _buildVideoView() : _buildImageView()),

            // 左侧切换按钮
            if (currentIndex > 0)
              Positioned(
                left: 20,
                top: 0,
                bottom: 0,
                child: Center(
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _isLeftHovered = true),
                    onExit: (_) => setState(() => _isLeftHovered = false),
                    child: AnimatedOpacity(
                      opacity: _isLeftHovered ? 1.0 : 0.3,
                      duration: const Duration(milliseconds: 200),
                      child: IconButton(
                        icon: const Icon(
                          Icons.chevron_left,
                          size: 48,
                          color: Colors.white,
                        ),
                        onPressed: _navigateToPrevious,
                      ),
                    ),
                  ),
                ),
              ),

            // 右侧切换按钮
            if (currentIndex < widget.mediaItems.length - 1)
              Positioned(
                right: 20,
                top: 0,
                bottom: 0,
                child: Center(
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _isRightHovered = true),
                    onExit: (_) => setState(() => _isRightHovered = false),
                    child: AnimatedOpacity(
                      opacity: _isRightHovered ? 1.0 : 0.3,
                      duration: const Duration(milliseconds: 200),
                      child: IconButton(
                        icon: const Icon(
                          Icons.chevron_right,
                          size: 48,
                          color: Colors.white,
                        ),
                        onPressed: _navigateToNext,
                      ),
                    ),
                  ),
                ),
              ),

            // 顶部工具栏
            if (_isControlsVisible || _isTopHovered)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isTopHovered = true),
                  onExit: (_) => setState(() => _isTopHovered = false),
                  child: _buildTopBar(),
                ),
              ),

            // 底部控制栏（仅视频）
            if (isVideo && (_isControlsVisible || _isTopHovered))
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildVideoControls(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageView() {
    final currentItem = widget.mediaItems[currentIndex];

    return GestureDetector(
      onScaleStart: (details) {
        _baseScale = _scale;
      },
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_baseScale * details.scale).clamp(0.5, 4.0);
          // 只有在缩放时才允许移动位置
          if (details.scale != 1.0) {
            _imagePosition += details.focalPointDelta;
          }
        });
      },
      onScaleEnd: (details) {
        // 如果缩放比例是1.0（即没有缩放），重置位置
        if (_scale == 1.0) {
          setState(() {
            _imagePosition = Offset.zero;
          });
        }
      },
      child: Transform.translate(
        offset: _imagePosition,
        child: Transform.scale(
          scale: _scale,
          child: currentItem.sourceType == MediaSourceType.local
              ? Image.file(
            File(currentItem.localPath!),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(Icons.error, color: Colors.white, size: 64),
              );
            },
          )
              : CachedNetworkImage(
            key: ValueKey('${currentItem.networkUrl}_$_imageReloadKey'),
            imageUrl: "${AppConfig.minio()}/${currentItem.networkUrl!}",
            cacheKey: '${currentItem.networkUrl}_$_imageReloadKey',
            fit: BoxFit.contain,
            fadeInDuration: const Duration(milliseconds: 200),
            fadeOutDuration: const Duration(milliseconds: 100),
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) {
              debugPrint('图片加载失败: $url, $error');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      '图片加载失败',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _imageReloadKey++;
                        });
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('重新加载'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVideoView() {
    if (_videoController == null || !_isVideoInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Video(controller: _videoController!, controls: NoVideoControls);
  }

  Widget _buildTopBar() {
    final currentItem = widget.mediaItems[currentIndex];

    return GestureDetector(
      // 添加拖拽功能
      onPanStart: (details) {
        windowManager.startDragging();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.move, // 鼠标悬停时显示移动光标
                child: Text(
                  currentItem.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Text(
              '${currentIndex + 1} / ${widget.mediaItems.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white, size: 24),
              onPressed: _showMediaInfo,
              tooltip: '媒体信息',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          Row(
            children: [
              Text(
                _formatDuration(_position),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                  ),
                  child: Slider(
                    value: _position.inMilliseconds.toDouble().clamp(
                      0.0,
                      _duration.inMilliseconds.toDouble(),
                    ),
                    max: _duration.inMilliseconds.toDouble(),
                    onChanged: (value) {
                      _seekTo(Duration(milliseconds: value.toInt()));
                    },
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 控制按钮
          Row(
            children: [
              // 播放/暂停
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _togglePlayPause,
              ),

              const SizedBox(width: 8),

              // 音量控制
              IconButton(
                icon: Icon(
                  _volume == 0 ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: () {
                  _changeVolume(_volume == 0 ? 100.0 : 0.0);
                },
              ),
              SizedBox(
                width: 80,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 10,
                    ),
                  ),
                  child: Slider(
                    value: _volume,
                    max: 100,
                    onChanged: _changeVolume,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),

              const Spacer(),

              // 倍速选择
              _buildSpeedSelector(),

              const SizedBox(width: 8),

              // 全屏按钮
              IconButton(
                icon: Icon(
                  _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: _toggleFullScreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedSelector() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    return PopupMenuButton<double>(
      key: ValueKey(_playbackSpeed),
      tooltip: '播放速度',
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_playbackSpeed}x',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          ],
        ),
      ),
      color: Colors.grey[900],
      elevation: 8,
      offset: const Offset(0, -10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (speed) {
        if (_player != null && _isVideoInitialized) {
          _player!.setRate(speed);
        }

        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            setState(() {
              _playbackSpeed = speed;
            });
          }
        });
      },
      itemBuilder: (BuildContext context) {
        return speeds.map((speed) {
          final isSelected = (_playbackSpeed - speed).abs() < 0.01;
          return PopupMenuItem<double>(
            value: speed,
            height: 42,
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    '${speed}x',
                    style: TextStyle(
                      color: isSelected ? Colors.blue[300] : Colors.white,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check, color: Colors.blue[300], size: 18),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}

// 媒体信息弹框
class _MediaInfoDialog extends StatelessWidget {
  final MediaItem item;
  final Animation<double> animation;

  const _MediaInfoDialog({required this.item, required this.animation});

  String _formatFileSize(int? bytes) {
    if (bytes == null) return 'Unknown';

    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  String _getFileExtension() {
    final name = item.name;
    final lastDot = name.lastIndexOf('.');
    if (lastDot != -1 && lastDot < name.length - 1) {
      return name.substring(lastDot + 1).toUpperCase();
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        margin: const EdgeInsets.only(top: 80, right: 20),
        width: 280,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('名称', item.name),
            _buildInfoRow('大小', _formatFileSize(item.fileSize)),
            _buildInfoRow('类型', _getFileExtension()),
            if (item.width != null && item.height != null)
              _buildInfoRow('分辨率', '${item.width}x${item.height}'),
            if (item.duration != null)
              _buildInfoRow('时长', _formatDuration(item.duration!)),
            _buildInfoRow(
              '来源',
              item.sourceType == MediaSourceType.local ? '本地文件' : '网络资源',
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${secs.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}