// widgets/views/grid_view.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../../../models/file_item.dart';
import '../../../../services/thumbnail_helper.dart';
import 'file_view_factory.dart';

/// 网格视图组件
///
/// 显示文件夹、图片、视频的网格布局
/// Item 布局：正方形缩略图 + 名称 + 大小
class FileGridView extends StatefulWidget {
  final List<FileItem> items;
  final Set<int> selectedIndices;
  final bool isSelectionMode;
  final EdgeInsets padding;
  final double itemWidth;
  final double spacing;
  final Function(int actualIndex) onItemTap;
  final Function(int actualIndex) onItemDoubleTap;
  final Function(int actualIndex) onItemLongPress;
  final Function(int actualIndex) onCheckboxToggle;

  const FileGridView({
    super.key,
    required this.items,
    required this.selectedIndices,
    required this.isSelectionMode,
    this.padding = const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
    this.itemWidth = 140.0,
    this.spacing = 10.0,
    required this.onItemTap,
    required this.onItemDoubleTap,
    required this.onItemLongPress,
    required this.onCheckboxToggle,
  });

  @override
  State<FileGridView> createState() => _FileGridViewState();
}

class _FileGridViewState extends State<FileGridView> {
  // 视频缩略图缓存
  static final Map<String, String> _videoThumbnailCache = {};
  static final Set<String> _loadingThumbnailPaths = {};

  @override
  void initState() {
    super.initState();
    _preloadThumbnails();
  }

  @override
  void didUpdateWidget(FileGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _preloadThumbnails();
    }
  }

  void _preloadThumbnails() {
    for (final item in widget.items) {
      if (item.type == FileItemType.video) {
        _preloadVideoThumbnail(item);
      }
    }
  }

  void _preloadVideoThumbnail(FileItem item) {
    if (_videoThumbnailCache.containsKey(item.path)) return;
    if (_loadingThumbnailPaths.contains(item.path)) return;

    _loadingThumbnailPaths.add(item.path);
    _loadVideoThumbnailAsync(item);
  }

  Future<void> _loadVideoThumbnailAsync(FileItem item) async {
    try {
      final thumbnailPath = await ThumbnailHelper.generateThumbnail(item.path);
      if (thumbnailPath != null) {
        final file = File(thumbnailPath);
        if (await file.exists()) {
          _videoThumbnailCache[item.path] = thumbnailPath;
          if (mounted) {
            setState(() {});
          }
        }
      }
      _loadingThumbnailPaths.remove(item.path);
    } catch (e) {
      if (kDebugMode) {
        print('FileGridView: Error generating thumbnail: $e');
      }
      _loadingThumbnailPaths.remove(item.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Center(
        child: Text(
          '此文件夹为空',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Padding(
      padding: widget.padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = ((constraints.maxWidth + widget.spacing) /
              (widget.itemWidth + widget.spacing)).floor().clamp(1, 10);

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.85, // 宽高比，留出名称和大小的空间
              crossAxisSpacing: widget.spacing,
              mainAxisSpacing: widget.spacing,
            ),
            itemCount: widget.items.length,
            itemBuilder: (context, index) => _buildGridItem(index),
          );
        },
      ),
    );
  }

  Widget _buildGridItem(int index) {
    final item = widget.items[index];
    final isSelected = widget.selectedIndices.contains(index);
    final showCheckbox = widget.isSelectionMode || isSelected;

    switch (item.type) {
      case FileItemType.folder:
        return _FolderGridItem(
          item: item,
          isSelected: isSelected,
          showCheckbox: showCheckbox,
          onTap: () => widget.onItemTap(index),
          onDoubleTap: () => widget.onItemDoubleTap(index),
          onLongPress: () => widget.onItemLongPress(index),
          onCheckboxToggle: () => widget.onCheckboxToggle(index),
        );

      case FileItemType.image:
        return _ImageGridItem(
          item: item,
          isSelected: isSelected,
          showCheckbox: showCheckbox,
          onTap: () => widget.onItemTap(index),
          onDoubleTap: () => widget.onItemDoubleTap(index),
          onLongPress: () => widget.onItemLongPress(index),
          onCheckboxToggle: () => widget.onCheckboxToggle(index),
        );

      case FileItemType.video:
        return _VideoGridItem(
          item: item,
          isSelected: isSelected,
          showCheckbox: showCheckbox,
          thumbnailPath: _videoThumbnailCache[item.path],
          isLoadingThumbnail: _loadingThumbnailPaths.contains(item.path),
          onTap: () => widget.onItemTap(index),
          onDoubleTap: () => widget.onItemDoubleTap(index),
          onLongPress: () => widget.onItemLongPress(index),
          onCheckboxToggle: () => widget.onCheckboxToggle(index),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

/// 未上传状态图标组件
class UnuploadedIcon extends StatelessWidget {
  final double size;

  const UnuploadedIcon({
    super.key,
    this.size = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/claude_white.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // 如果图片加载失败，显示默认图标
            return Icon(
              Icons.cloud_off,
              size: size * 0.7,
              color: Colors.white,
            );
          },
        ),
      ),
    );
  }
}

/// 文件夹网格项
class _FolderGridItem extends StatefulWidget {
  final FileItem item;
  final bool isSelected;
  final bool showCheckbox;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  final VoidCallback onCheckboxToggle;

  const _FolderGridItem({
    required this.item,
    required this.isSelected,
    required this.showCheckbox,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onCheckboxToggle,
  });

  @override
  State<_FolderGridItem> createState() => _FolderGridItemState();
}

class _FolderGridItemState extends State<_FolderGridItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.orange.shade50
                : (_isHovered ? Colors.grey.shade100 : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.orange
                  : (_isHovered ? Colors.grey.shade300 : Colors.transparent),
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              // 文件夹内容
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 文件夹图标
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/folder_icon.svg',
                          width: 70,
                          height: 56,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 文件夹名称
                    Text(
                      widget.item.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // 复选框
              if (widget.showCheckbox || _isHovered)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: widget.onCheckboxToggle,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: _buildCheckbox(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: widget.isSelected ? Colors.orange : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.isSelected ? Colors.orange : Colors.grey.shade400,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: widget.isSelected
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}

/// 图片网格项
class _ImageGridItem extends StatefulWidget {
  final FileItem item;
  final bool isSelected;
  final bool showCheckbox;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  final VoidCallback onCheckboxToggle;

  const _ImageGridItem({
    required this.item,
    required this.isSelected,
    required this.showCheckbox,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onCheckboxToggle,
  });

  @override
  State<_ImageGridItem> createState() => _ImageGridItemState();
}

class _ImageGridItemState extends State<_ImageGridItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // 判断是否未上传（isUploaded 为 false 或 null 时显示图标）
    final bool showUnuploadedIcon = widget.item.isUploaded != true;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.orange.shade50
                : (_isHovered ? Colors.grey.shade50 : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.orange
                  : (_isHovered ? Colors.grey.shade300 : Colors.transparent),
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              // 主内容
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    // 正方形图片缩略图
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Stack(
                          children: [
                            // 图片
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(widget.item.path),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                cacheWidth: 200,
                                cacheHeight: 200,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                                    ),
                                  );
                                },
                                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                  if (wasSynchronouslyLoaded) return child;
                                  return AnimatedOpacity(
                                    opacity: frame == null ? 0 : 1,
                                    duration: const Duration(milliseconds: 300),
                                    child: frame != null
                                        ? child
                                        : Container(
                                      color: Colors.grey.shade100,
                                      child: Icon(Icons.image, color: Colors.grey.shade300, size: 40),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // 未上传状态图标 - 右下角
                            if (showUnuploadedIcon)
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: UnuploadedIcon(size: 20),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 文件名
                    Text(
                      widget.item.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // 文件大小
                    Text(
                      _formatFileSize(widget.item.size),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // 复选框
              if (widget.showCheckbox || _isHovered)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: widget.onCheckboxToggle,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: _buildCheckbox(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: widget.isSelected ? Colors.orange : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.isSelected ? Colors.orange : Colors.grey.shade400,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: widget.isSelected
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// 视频网格项
class _VideoGridItem extends StatefulWidget {
  final FileItem item;
  final bool isSelected;
  final bool showCheckbox;
  final String? thumbnailPath;
  final bool isLoadingThumbnail;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  final VoidCallback onCheckboxToggle;

  const _VideoGridItem({
    required this.item,
    required this.isSelected,
    required this.showCheckbox,
    this.thumbnailPath,
    this.isLoadingThumbnail = false,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onCheckboxToggle,
  });

  @override
  State<_VideoGridItem> createState() => _VideoGridItemState();
}

class _VideoGridItemState extends State<_VideoGridItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // 判断是否未上传
    final bool showUnuploadedIcon = widget.item.isUploaded != true;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.orange.shade50
                : (_isHovered ? Colors.grey.shade50 : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.orange
                  : (_isHovered ? Colors.grey.shade300 : Colors.transparent),
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              // 主内容
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    // 正方形视频缩略图
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // 缩略图
                              _buildThumbnail(),
                              // 播放按钮
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              // 未上传状态图标 - 右下角
                              if (showUnuploadedIcon)
                                Positioned(
                                  right: 4,
                                  bottom: 4,
                                  child: UnuploadedIcon(size: 20),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 文件名
                    Text(
                      widget.item.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // 文件大小
                    Text(
                      _formatFileSize(widget.item.size),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // 复选框
              if (widget.showCheckbox || _isHovered)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: widget.onCheckboxToggle,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: _buildCheckbox(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (widget.thumbnailPath != null) {
      return Image.file(
        File(widget.thumbnailPath!),
        fit: BoxFit.cover,
        cacheWidth: 200,
        cacheHeight: 200,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            child: frame != null ? child : _buildPlaceholder(),
          );
        },
      );
    } else if (widget.isLoadingThumbnail) {
      return Container(
        color: Colors.grey.shade200,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.orange.shade700,
            ),
          ),
        ),
      );
    } else {
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(
          Icons.videocam,
          color: Colors.grey.shade400,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildCheckbox() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: widget.isSelected ? Colors.orange : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.isSelected ? Colors.orange : Colors.grey.shade400,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: widget.isSelected
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// 网格视图构建器
class GridViewBuilder implements FileViewBuilder {
  final double itemWidth;
  final double spacing;

  const GridViewBuilder({
    this.itemWidth = 140.0,
    this.spacing = 10.0,
  });

  @override
  Widget build(BuildContext context, FileViewConfig config) {
    return FileGridView(
      items: config.items,
      selectedIndices: config.selectedIndices,
      isSelectionMode: config.isSelectionMode,
      padding: config.padding,
      itemWidth: itemWidth,
      spacing: spacing,
      onItemTap: config.callbacks.onTap,
      onItemDoubleTap: config.callbacks.onDoubleTap,
      onItemLongPress: config.callbacks.onLongPress,
      onCheckboxToggle: config.callbacks.onCheckboxToggle,
    );
  }
}