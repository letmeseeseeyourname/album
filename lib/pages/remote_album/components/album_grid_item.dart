// album/components/album_grid_item.dart (优化版 v9)
//
// 改进点：
// 1. 使用 CachedNetworkImage 替代手动管理的 ImageLoadManager
// 2. 使用 assets/images/image_placeholder.png 作为占位符
// 3. 简化代码，提高可维护性

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../network/constant_sign.dart';
import '../../../user/models/resource_list_model.dart';

/// 相册网格项组件（优化版 v9）
/// 使用 CachedNetworkImage 进行图片加载和缓存
class AlbumGridItem extends StatelessWidget {
  final ResList resource;
  final int globalIndex;
  final bool isSelected;
  final bool isHovered;
  final bool shouldShowCheckbox;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onCheckboxTap;
  final VoidCallback? onHover;
  final VoidCallback? onHoverExit;

  const AlbumGridItem({
    super.key,
    required this.resource,
    required this.globalIndex,
    required this.isSelected,
    required this.isHovered,
    required this.shouldShowCheckbox,
    this.onTap,
    this.onDoubleTap,
    this.onCheckboxTap,
    this.onHover,
    this.onHoverExit,
  });

  String? get _imageUrl {
    final path = resource.thumbnailPath;
    if (path == null || path.isEmpty) return null;
    return "${AppConfig.minio()}/$path";
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHover?.call(),
      onExit: (_) => onHoverExit?.call(),
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: Colors.orange, width: 3)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnail(context),
                  if (resource.fileType == 'V') _buildVideoDurationLabel(),
                  if (shouldShowCheckbox) _buildCheckbox(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    final url = _imageUrl;
    if (url == null) return _buildDefaultThumbnail();

    final screenSize = MediaQuery.of(context).size;
    final scale = MediaQuery.of(context).devicePixelRatio;
    // 计算合适的图片缓存尺寸
    final imageSize = (screenSize.width / 8).clamp(100.0, 200.0);
    final cacheSize = (imageSize * scale).toInt();

    return CachedNetworkImage(
      imageUrl: url,
      memCacheWidth: cacheSize,
      memCacheHeight: cacheSize,
      fit: _getBoxFit(),
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildPlaceholder(),
    );
  }

  BoxFit _getBoxFit() {
    final aspectRatio = _getImageAspectRatio();
    return (aspectRatio > 0.9 && aspectRatio < 1.1) ? BoxFit.cover : BoxFit.contain;
  }

  double _getImageAspectRatio() {
    if (resource.width != null &&
        resource.height != null &&
        resource.height! > 0) {
      return resource.width! / resource.height!;
    }
    return 1.0;
  }

  /// 占位图组件
  Widget _buildPlaceholder() {
    final isVideo = resource.fileType == 'V';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isVideo
              ? [const Color(0xFF3A3A5C), const Color(0xFF2A2A4C)]
              : [Colors.grey.shade200, Colors.grey.shade300],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 43,
          height: 35,
          child: Image.asset(
            'assets/images/image_placeholder.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // 如果占位图加载失败，显示默认图标
              return Icon(
                isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                color: Colors.grey.shade400,
                size: 32,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultThumbnail() {
    final isVideo = resource.fileType == 'V';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isVideo
              ? [const Color(0xFF3A3A5C), const Color(0xFF2A2A4C)]
              : [const Color(0xFF4A5568), const Color(0xFF2D3748)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            if (resource.fileName != null && resource.fileName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  _truncateFileName(resource.fileName!),
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _truncateFileName(String fileName) {
    if (fileName.length <= 12) return fileName;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex > 0 && dotIndex < fileName.length - 1) {
      final name = fileName.substring(0, dotIndex);
      final ext = fileName.substring(dotIndex);
      if (name.length > 8) return '${name.substring(0, 6)}...$ext';
    }
    return '${fileName.substring(0, 9)}...';
  }

  Widget _buildVideoDurationLabel() {
    return Positioned(
      bottom: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: Colors.black54, borderRadius: BorderRadius.circular(4)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 12),
            const SizedBox(width: 2),
            Text(_formatDuration(resource.duration ?? 0),
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox() {
    return Positioned(
      top: 8,
      right: 8,
      child: GestureDetector(
        onTap: () => onCheckboxTap?.call(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isSelected ? Colors.orange : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
                color: isSelected ? Colors.orange : Colors.grey.shade400,
                width: 2),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
            ],
          ),
          child: isSelected
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : null,
        ),
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
    }
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}