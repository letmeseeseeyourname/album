// album/components/album_grid_item.dart (优化版 - 超时处理)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../network/constant_sign.dart';
import '../../../user/models/resource_list_model.dart';

/// 相册网格项组件（优化版）
/// 负责单个相册项的显示和交互
/// 添加缩略图加载超时处理
class AlbumGridItem extends StatefulWidget {
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
  State<AlbumGridItem> createState() => _AlbumGridItemState();
}

class _AlbumGridItemState extends State<AlbumGridItem> {
  // 加载超时时间（秒）
  static const int _loadTimeoutSeconds = 5;

  // 加载状态
  bool _isLoading = true;
  bool _loadFailed = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _startTimeoutTimer();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(AlbumGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果资源变化，重置状态
    if (oldWidget.resource.resId != widget.resource.resId) {
      _resetLoadingState();
    }
  }

  void _resetLoadingState() {
    _timeoutTimer?.cancel();
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    _startTimeoutTimer();
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: _loadTimeoutSeconds), () {
      if (mounted && _isLoading) {
        setState(() {
          _loadFailed = true;
          _isLoading = false;
        });
        debugPrint('缩略图加载超时: ${widget.resource.thumbnailPath}');
      }
    });
  }

  void _onImageLoaded() {
    _timeoutTimer?.cancel();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _loadFailed = false;
      });
    }
  }

  void _onImageError() {
    _timeoutTimer?.cancel();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => widget.onHover?.call(),
      onExit: (_) => widget.onHoverExit?.call(),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
              border: widget.isSelected
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
                  if (widget.resource.fileType == 'V')
                    _buildVideoDurationLabel(),
                  // 复选框
                  if (widget.shouldShowCheckbox)
                    _buildCheckbox(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建缩略图（带超时处理）
  Widget _buildThumbnail() {
    // 如果没有缩略图路径或加载失败，显示默认图
    if (widget.resource.thumbnailPath == null ||
        widget.resource.thumbnailPath!.isEmpty ||
        _loadFailed) {
      return _buildDefaultThumbnail();
    }

    final imageUrl = "${AppConfig.minio()}/${widget.resource.thumbnailPath!}";
    final aspectRatio = _getImageAspectRatio();
    final fitMode = (aspectRatio > 0.9 && aspectRatio < 1.1)
        ? BoxFit.cover
        : BoxFit.contain;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fitMode,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: fitMode == BoxFit.contain ? 400 : 300,
      memCacheHeight: fitMode == BoxFit.contain ? 400 : 300,
      maxWidthDiskCache: 400,
      maxHeightDiskCache: 400,
      placeholder: (context, url) => _buildLoadingPlaceholder(),
      errorWidget: (context, url, error) {
        // 确保状态更新
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onImageError();
        });
        return _buildDefaultThumbnail();
      },
      imageBuilder: (context, imageProvider) {
        // 图片加载成功
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onImageLoaded();
        });
        return Image(
          image: imageProvider,
          fit: fitMode,
          width: double.infinity,
          height: double.infinity,
        );
      },
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }

  /// 获取图片的宽高比
  double _getImageAspectRatio() {
    if (widget.resource.width != null &&
        widget.resource.height != null &&
        widget.resource.height! > 0) {
      return widget.resource.width! / widget.resource.height!;
    }
    return 1.0;
  }

  /// 构建加载中的占位图
  Widget _buildLoadingPlaceholder() {
    final isVideo = widget.resource.fileType == 'V';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isVideo
              ? [const Color(0xFF3A3A5C), const Color(0xFF2A2A4C)]
              : [Colors.grey.shade700, Colors.grey.shade800],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '加载中...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建默认缩略图（加载失败或超时时显示）
  Widget _buildDefaultThumbnail() {
    final isVideo = widget.resource.fileType == 'V';

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
      child: Stack(
        children: [
          // 背景图案
          Positioned.fill(
            child: CustomPaint(
              painter: _ThumbnailPatternPainter(
                color: Colors.white.withOpacity(0.03),
              ),
            ),
          ),
          // 中心图标
          Center(
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
                // 文件名
                if (widget.resource.fileName != null && widget.resource.fileName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _truncateFileName(widget.resource.fileName!),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
          // 文件类型角标
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isVideo ? 'VIDEO' : 'IMAGE',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 截断文件名
  String _truncateFileName(String fileName) {
    if (fileName.length <= 12) return fileName;

    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex > 0 && dotIndex < fileName.length - 1) {
      final name = fileName.substring(0, dotIndex);
      final ext = fileName.substring(dotIndex);
      if (name.length > 8) {
        return '${name.substring(0, 6)}...$ext';
      }
    }
    return '${fileName.substring(0, 9)}...';
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 12,
            ),
            const SizedBox(width: 2),
            Text(
              _formatDuration(widget.resource.duration ?? 0),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
            ),
          ],
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
          widget.onCheckboxTap?.call();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: widget.isSelected ? Colors.orange : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isSelected ? Colors.orange : Colors.grey.shade400,
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
          child: widget.isSelected
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

/// 默认缩略图背景图案绘制器
class _ThumbnailPatternPainter extends CustomPainter {
  final Color color;

  _ThumbnailPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 20.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}