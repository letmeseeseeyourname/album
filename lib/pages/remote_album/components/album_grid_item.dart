// album/components/album_grid_item.dart (最优版 - 智能裁剪)
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../network/constant_sign.dart';
import '../../../user/models/resource_list_model.dart';

/// 相册网格项组件（最优版）
/// 负责单个相册项的显示和交互
/// 使用智能裁剪策略，尽量显示完整内容
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
              // 使用深灰色背景，让裁剪更自然
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
                  // 缩略图
                  _buildThumbnail(),
                  // 视频时长标签
                  if (resource.fileType == 'V')
                    _buildVideoDurationLabel(),
                  // 复选框
                  if (shouldShowCheckbox)
                    _buildCheckbox(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建缩略图（智能填充）
  Widget _buildThumbnail() {
    if (resource.thumbnailPath == null || resource.thumbnailPath!.isEmpty) {
      return _buildPlaceholder();
    }

    final imageUrl = "${AppConfig.minio()}/${resource.thumbnailPath!}";
    // debugPrint("imageUrl: $imageUrl");
    // 根据图片的宽高比决定填充方式
    final aspectRatio = _getImageAspectRatio();

    // 如果接近正方形(0.9-1.1)，使用 cover 填充
    // 如果是竖图或横图，使用 contain 保持完整性
    final fitMode = (aspectRatio > 0.9 && aspectRatio < 1.1)
        ? BoxFit.cover
        : BoxFit.contain;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fitMode,
      width: double.infinity,
      height: double.infinity,
      // 对于非正方形图片，适当增加缓存尺寸以保证清晰度
      memCacheWidth: fitMode == BoxFit.contain ? 400 : 300,
      memCacheHeight: fitMode == BoxFit.contain ? 400 : 300,
      maxWidthDiskCache: 400,
      maxHeightDiskCache: 400,
      placeholder: (context, url) => Container(
        color: Colors.grey.shade800,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        ),
      ),
      errorWidget: (context, url, error) => _buildPlaceholder(),
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }

  /// 获取图片的宽高比
  double _getImageAspectRatio() {
    if (resource.width != null &&
        resource.height != null &&
        resource.height! > 0) {
      return resource.width! / resource.height!;
    }
    // 默认假设是正方形
    return 1.0;
  }

  /// 构建占位图
  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade800,
      child: Center(
        child: Icon(
          resource.fileType == 'V' ? Icons.videocam : Icons.image,
          color: Colors.grey.shade400,
          size: 32,
        ),
      ),
    );
  }

  /// 构建视频时长标签
  Widget _buildVideoDurationLabel() {
    return Positioned(
      bottom: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          _formatDuration(resource.duration ?? 0),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  /// 构建复选框
  Widget _buildCheckbox() {
    return Positioned(
      top: 8,
      right: 8,
      child: GestureDetector(
        onTap: () {
          onCheckboxTap?.call();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isSelected ? Colors.orange : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.orange : Colors.grey.shade400,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: isSelected
              ? const Icon(
            Icons.check,
            color: Colors.white,
            size: 16,
          )
              : null,
        ),
      ),
    );
  }

  /// 格式化视频时长
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