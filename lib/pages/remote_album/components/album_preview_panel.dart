// album/components/album_preview_panel.dart (修改版 - 适配 Flex 布局)
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../network/constant_sign.dart';
import '../../../user/models/resource_list_model.dart';

/// 相册预览面板
/// 负责右侧的媒体预览显示
/// 修改：移除固定宽度，适配 Flex 布局
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

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  @override
  void didUpdateWidget(AlbumPreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.previewIndex != widget.previewIndex) {
      _loadMedia();
    }
  }

  @override
  void dispose() {
    _disposeVideoPlayer();
    super.dispose();
  }

  void _loadMedia() {
    if (widget.previewIndex < 0 || widget.previewIndex >= widget.mediaItems.length) {
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

    _videoPlayer = Player();
    _videoController = VideoController(_videoPlayer!);

    final fullUrl = "${AppConfig.minio()}/$url";
    _videoPlayer!.open(Media(fullUrl));

    // 监听播放状态
    _videoPlayer!.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });

    // 监听播放进度
    _videoPlayer!.stream.position.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    // 监听视频时长
    _videoPlayer!.stream.duration.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    // 监听音量
    _videoPlayer!.stream.volume.listen((volume) {
      if (mounted) {
        setState(() {
          _volume = volume / 100;
        });
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
    if (widget.previewIndex < 0 || widget.previewIndex >= widget.mediaItems.length) {
      return const SizedBox.shrink();
    }

    final item = widget.mediaItems[widget.previewIndex];

    // 移除固定宽度，让 Expanded 控制宽度
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // 顶部标题栏
          _buildHeader(item),
          // 媒体内容区（包含左右切换按钮）
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
          // 左侧文件名
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
          // 索引显示
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
          // 右侧关闭按钮
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

  /// 媒体内容区
  Widget _buildMediaContent(ResList item) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Stack(
        children: [
          // 主内容
          Center(
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

          // 视频播放/暂停按钮（居中显示）
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

          // 视频控制栏（仅视频时显示）
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

  /// 视频预览
  Widget _buildVideoPreview() {
    if (_videoController == null) {
      return const Center(
        child: CircularProgressIndicator(),
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

  /// 图片预览
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
      child: Image.network(
        "${AppConfig.minio()}/$imageUrl",
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Icon(
              Icons.broken_image,
              size: 64,
              color: Colors.grey.shade400,
            ),
          );
        },
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
          // 进度条
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
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
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
          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 播放/暂停按钮
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
              // 音量控制
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
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
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
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${secs.toString().padLeft(2, '0')}';
    }
  }
}