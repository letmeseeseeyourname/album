// widgets/preview_panel.dart (修改版 - 布局风格与 AlbumPreviewPanel 一致)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../models/file_item.dart';

/// 媒体预览面板
/// 布局结构：顶部标题栏 + 媒体内容区 + 底部信息区
/// 与 AlbumPreviewPanel 风格保持一致
class PreviewPanel extends StatefulWidget {
  final FileItem item;
  final int currentIndex;
  final int totalCount;
  final VoidCallback onClose;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool canGoPrevious;
  final bool canGoNext;

  const PreviewPanel({
    super.key,
    required this.item,
    required this.currentIndex,
    required this.totalCount,
    required this.onClose,
    required this.onPrevious,
    required this.onNext,
    required this.canGoPrevious,
    required this.canGoNext,
  });

  @override
  State<PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<PreviewPanel> {
  Player? _videoPlayer;
  VideoController? _videoController;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  @override
  void didUpdateWidget(PreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path) {
      _loadMedia();
    }
  }

  @override
  void dispose() {
    _disposeVideoPlayer();
    super.dispose();
  }

  void _loadMedia() {
    if (widget.item.type == FileItemType.video) {
      _initVideoPlayer(widget.item.path);
    } else {
      _disposeVideoPlayer();
    }
  }

  void _initVideoPlayer(String path) {
    _disposeVideoPlayer();

    if (path.isEmpty) return;

    _videoPlayer = Player();
    _videoController = VideoController(_videoPlayer!);

    _videoPlayer!.open(Media(path));

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
    final isVideo = widget.item.type == FileItemType.video;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // 顶部标题栏
          _buildHeader(),
          // 媒体内容区（包含左右切换按钮）
          Expanded(
            child: _buildMediaContent(isVideo),
          ),
        ],
      ),
    );
  }

  /// 顶部标题栏
  Widget _buildHeader() {
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
              widget.item.name,
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
              '${widget.currentIndex + 1} / ${widget.totalCount}',
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
  Widget _buildMediaContent(bool isVideo) {
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
            child: isVideo ? _buildVideoPreview() : _buildImagePreview(),
          ),

          // 左侧切换按钮
          if (widget.canGoPrevious)
            Positioned(
              left: 16,
              top: 0,
              bottom: isVideo ? 64 : 0,
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
              bottom: isVideo ? 64 : 0,
              child: Center(
                child: _buildNavigationButton(
                  icon: Icons.chevron_right,
                  onPressed: widget.onNext,
                  tooltip: '下一个',
                ),
              ),
            ),

          // 视频播放/暂停按钮（居中显示，仅在暂停时显示）
          if (isVideo && _videoController != null && !_isPlaying)
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
          if (isVideo && _videoController != null)
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

  /// 图片预览
  Widget _buildImagePreview() {
    return Container(
      color: Colors.grey.shade100,
      child: Image.file(
        File(widget.item.path),
        fit: BoxFit.contain,
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