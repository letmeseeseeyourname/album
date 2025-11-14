// widgets/preview_panel.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../models/file_item.dart';

/// 媒体预览面板
class PreviewPanel extends StatelessWidget {
  final FileItem item;
  final int currentIndex;
  final int totalCount;
  final bool isPlaying;
  final VideoController? videoController;
  final VoidCallback onClose;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTogglePlayPause;
  final bool canGoPrevious;
  final bool canGoNext;

  const PreviewPanel({
    super.key,
    required this.item,
    required this.currentIndex,
    required this.totalCount,
    required this.isPlaying,
    required this.videoController,
    required this.onClose,
    required this.onPrevious,
    required this.onNext,
    required this.onTogglePlayPause,
    required this.canGoPrevious,
    required this.canGoNext,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = item.type == FileItemType.video;

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // 媒体显示区域
          Center(
            child: isVideo ? _buildVideoPreview() : _buildImagePreview(),
          ),

          // 左侧切换按钮
          if (canGoPrevious)
            Positioned(
              left: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_left, size: 48, color: Colors.white),
                  onPressed: onPrevious,
                ),
              ),
            ),

          // 右侧切换按钮
          if (canGoNext)
            Positioned(
              right: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_right, size: 48, color: Colors.white),
                  onPressed: onNext,
                ),
              ),
            ),

          // 视频播放/暂停按钮
          if (isVideo)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    size: 80,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  onPressed: onTogglePlayPause,
                ),
              ),
            ),

          // 关闭按钮
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, size: 32, color: Colors.white),
              onPressed: onClose,
            ),
          ),

          // 文件名显示
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${currentIndex + 1}/$totalCount - ${item.name}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Image.file(
      File(item.path),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(Icons.error, color: Colors.white, size: 64),
        );
      },
    );
  }

  Widget _buildVideoPreview() {
    if (videoController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Video(
      controller: videoController!,
      controls: NoVideoControls,
    );
  }
}