// widgets/common/video_thumbnail.dart
import 'dart:io';
import 'package:flutter/material.dart';

/// 视频缩略图组件
///
/// 支持：
/// - 缩略图加载状态
/// - 播放按钮叠加
/// - 视频标签显示
class VideoThumbnail extends StatelessWidget {
  /// 缩略图路径
  final String? thumbnailPath;

  /// 是否正在加载
  final bool isLoading;

  /// 宽度
  final double? width;

  /// 高度
  final double? height;

  /// 是否显示播放按钮
  final bool showPlayButton;

  /// 是否显示视频标签
  final bool showVideoLabel;

  /// 播放按钮大小
  final double playButtonSize;

  /// 视频标签文本
  final String videoLabelText;

  /// 视频标签位置
  final VideoLabelPosition labelPosition;

  /// 圆角
  final BorderRadius borderRadius;

  const VideoThumbnail({
    super.key,
    this.thumbnailPath,
    this.isLoading = false,
    this.width,
    this.height,
    this.showPlayButton = true,
    this.showVideoLabel = true,
    this.playButtonSize = 48.0,
    this.videoLabelText = '视频',
    this.labelPosition = VideoLabelPosition.bottomLeft,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 缩略图或占位符
        ClipRRect(
          borderRadius: borderRadius,
          child: _buildThumbnailContent(),
        ),

        // 播放按钮
        if (showPlayButton)
          Center(
            child: _PlayButton(size: playButtonSize),
          ),

        // 视频标签
        if (showVideoLabel)
          _VideoLabel(
            text: videoLabelText,
            position: labelPosition,
          ),
      ],
    );
  }

  Widget _buildThumbnailContent() {
    if (thumbnailPath != null) {
      return Image.file(
        File(thumbnailPath!),
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheWidth: width != null ? (width! * 2).toInt().clamp(100, 800) : 400,
        cacheHeight: height != null ? (height! * 2).toInt().clamp(100, 800) : 400,
        errorBuilder: (context, error, stackTrace) => _VideoPlaceholder(),
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: frame != null ? child : _VideoPlaceholder(),
          );
        },
      );
    } else if (isLoading) {
      return _LoadingPlaceholder();
    } else {
      return _VideoPlaceholder();
    }
  }
}

/// 播放按钮
class _PlayButton extends StatelessWidget {
  final double size;

  const _PlayButton({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.play_arrow,
        color: Colors.white,
        size: size * 0.65,
      ),
    );
  }
}

/// 视频标签位置
enum VideoLabelPosition {
  bottomLeft,
  bottomRight,
  topLeft,
  topRight,
}

/// 视频标签
class _VideoLabel extends StatelessWidget {
  final String text;
  final VideoLabelPosition position;

  const _VideoLabel({
    required this.text,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: _isBottom ? 8 : null,
      top: _isTop ? 8 : null,
      left: _isLeft ? 8 : null,
      right: _isRight ? 8 : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam, color: Colors.white, size: 14),
            const SizedBox(width: 2),
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isBottom =>
      position == VideoLabelPosition.bottomLeft || position == VideoLabelPosition.bottomRight;
  bool get _isTop =>
      position == VideoLabelPosition.topLeft || position == VideoLabelPosition.topRight;
  bool get _isLeft =>
      position == VideoLabelPosition.bottomLeft || position == VideoLabelPosition.topLeft;
  bool get _isRight =>
      position == VideoLabelPosition.bottomRight || position == VideoLabelPosition.topRight;
}

/// 视频占位符
class _VideoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade300,
      child: Center(
        child: Icon(
          Icons.videocam,
          color: Colors.grey.shade500,
          size: 48,
        ),
      ),
    );
  }
}

/// 加载中占位符
class _LoadingPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.orange.shade700,
          ),
        ),
      ),
    );
  }
}

/// 图片缩略图组件
class ImageThumbnail extends StatelessWidget {
  final String imagePath;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const ImageThumbnail({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.file(
        File(imagePath),
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheWidth: width != null ? (width! * 2).toInt().clamp(100, 800) : 400,
        cacheHeight: height != null ? (height! * 2).toInt().clamp(100, 800) : 400,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
            ),
          );
        },
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: frame != null
                ? child
                : Container(
              color: Colors.grey.shade100,
              child: Center(
                child: Icon(
                  Icons.image,
                  color: Colors.grey.shade300,
                  size: 48,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}