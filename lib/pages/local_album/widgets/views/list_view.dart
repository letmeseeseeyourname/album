// widgets/views/list_view.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../models/file_item.dart';
import '../../services/media_cache_service.dart';
import '../items/folder_item.dart';
import '../items/image_item.dart';
import '../items/video_item.dart';
import 'file_view_factory.dart';

/// 列表视图组件
///
/// 使用统一的 MediaCacheService 管理缓存
class FileListView extends StatefulWidget {
  final List<FileItem> items;
  final Set<int> selectedIndices;
  final bool isSelectionMode;
  final EdgeInsets padding;
  final Function(int actualIndex) onItemTap;
  final Function(int actualIndex) onItemDoubleTap;
  final Function(int actualIndex) onCheckboxToggle;

  const FileListView({
    super.key,
    required this.items,
    required this.selectedIndices,
    required this.isSelectionMode,
    this.padding = const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
    required this.onItemTap,
    required this.onItemDoubleTap,
    required this.onCheckboxToggle,
  });

  @override
  State<FileListView> createState() => _FileListViewState();
}

class _FileListViewState extends State<FileListView> {
  final MediaCacheService _cacheService = MediaCacheService.instance;
  StreamSubscription<CacheUpdateEvent>? _cacheSubscription;

  @override
  void initState() {
    super.initState();
    _preloadThumbnails();
    _subscribeToCacheUpdates();
  }

  @override
  void didUpdateWidget(FileListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _preloadThumbnails();
    }
  }

  @override
  void dispose() {
    _cacheSubscription?.cancel();
    super.dispose();
  }

  void _preloadThumbnails() {
    for (final item in widget.items) {
      if (item.type == FileItemType.video) {
        _cacheService.preloadVideoThumbnail(item.path);
      }
    }
  }

  void _subscribeToCacheUpdates() {
    _cacheSubscription = _cacheService.onCacheUpdate.listen((event) {
      if (event.type == CacheUpdateType.thumbnail && mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const EmptyStateWidget();
    }

    return ListView.builder(
      padding: widget.padding,
      itemCount: widget.items.length,
      itemBuilder: (context, index) => _buildListItem(index),
    );
  }

  Widget _buildListItem(int index) {
    final item = widget.items[index];
    final isSelected = widget.selectedIndices.contains(index);
    final canSelect = widget.isSelectionMode || isSelected;
    // 判断是否未上传（仅对图片和视频显示）
    final bool showUnuploadedIcon = (item.type == FileItemType.image ||
        item.type == FileItemType.video) &&
        item.isUploaded != true;

    switch (item.type) {
      case FileItemType.folder:
        return GestureDetector(
          onDoubleTap: () => widget.onItemDoubleTap(index),
          child: FolderListItem(
            key: ValueKey(item.path),
            item: item,
            isSelected: isSelected,
            canSelect: canSelect,
            onTap: () => widget.onItemTap(index),
            onCheckboxToggle: () => widget.onCheckboxToggle(index),
          ),
        );

      case FileItemType.image:
        return _ImageListItemWithUploadStatus(
          key: ValueKey(item.path),
          item: item,
          isSelected: isSelected,
          canSelect: canSelect,
          showUnuploadedIcon: showUnuploadedIcon,
          onTap: () => widget.onItemTap(index),
          onCheckboxToggle: () => widget.onCheckboxToggle(index),
        );

      case FileItemType.video:
        return _VideoListItemWithUploadStatus(
          key: ValueKey(item.path),
          item: item,
          isSelected: isSelected,
          canSelect: canSelect,
          showUnuploadedIcon: showUnuploadedIcon,
          thumbnailPath: _cacheService.getVideoThumbnail(item.path),
          isLoadingThumbnail: _cacheService.isLoadingThumbnail(item.path),
          onTap: () => widget.onItemTap(index),
          onCheckboxToggle: () => widget.onCheckboxToggle(index),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

/// 带上传状态的图片列表项
class _ImageListItemWithUploadStatus extends StatefulWidget {
  final FileItem item;
  final bool isSelected;
  final bool canSelect;
  final bool showUnuploadedIcon;
  final VoidCallback onTap;
  final VoidCallback onCheckboxToggle;

  const _ImageListItemWithUploadStatus({
    super.key,
    required this.item,
    required this.isSelected,
    required this.canSelect,
    required this.showUnuploadedIcon,
    required this.onTap,
    required this.onCheckboxToggle,
  });

  @override
  State<_ImageListItemWithUploadStatus> createState() => _ImageListItemWithUploadStatusState();
}

class _ImageListItemWithUploadStatusState extends State<_ImageListItemWithUploadStatus> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 56,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.orange.shade50
                : (_isHovered ? Colors.grey.shade50 : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.orange
                  : (_isHovered ? Colors.grey.shade200 : Colors.transparent),
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              // 复选框
              if (widget.canSelect || _isHovered)
                GestureDetector(
                  onTap: widget.onCheckboxToggle,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: _buildCheckbox(),
                  ),
                )
              else
                const SizedBox(width: 32),
              const SizedBox(width: 12),
              // 缩略图
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Image.file(
                    File(widget.item.path),
                    fit: BoxFit.cover,
                    cacheWidth: 80,
                    cacheHeight: 80,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: Icon(Icons.broken_image, color: Colors.grey.shade400, size: 20),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 未上传状态图标
              if (widget.showUnuploadedIcon) ...[
                _UnuploadedListIcon(size: 18),
                const SizedBox(width: 8),
              ],
              // 文件名
              Expanded(
                child: Text(
                  widget.item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
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

/// 带上传状态的视频列表项
class _VideoListItemWithUploadStatus extends StatefulWidget {
  final FileItem item;
  final bool isSelected;
  final bool canSelect;
  final bool showUnuploadedIcon;
  final String? thumbnailPath;
  final bool isLoadingThumbnail;
  final VoidCallback onTap;
  final VoidCallback onCheckboxToggle;

  const _VideoListItemWithUploadStatus({
    super.key,
    required this.item,
    required this.isSelected,
    required this.canSelect,
    required this.showUnuploadedIcon,
    this.thumbnailPath,
    this.isLoadingThumbnail = false,
    required this.onTap,
    required this.onCheckboxToggle,
  });

  @override
  State<_VideoListItemWithUploadStatus> createState() => _VideoListItemWithUploadStatusState();
}

class _VideoListItemWithUploadStatusState extends State<_VideoListItemWithUploadStatus> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 56,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.orange.shade50
                : (_isHovered ? Colors.grey.shade50 : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.orange
                  : (_isHovered ? Colors.grey.shade200 : Colors.transparent),
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              // 复选框
              if (widget.canSelect || _isHovered)
                GestureDetector(
                  onTap: widget.onCheckboxToggle,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: _buildCheckbox(),
                  ),
                )
              else
                const SizedBox(width: 32),
              const SizedBox(width: 12),
              // 缩略图
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildThumbnail(),
                      // 播放图标
                      Center(
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 未上传状态图标
              if (widget.showUnuploadedIcon) ...[
                _UnuploadedListIcon(size: 18),
                const SizedBox(width: 8),
              ],
              // 文件名
              Expanded(
                child: Text(
                  widget.item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
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
        cacheWidth: 80,
        cacheHeight: 80,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    } else if (widget.isLoadingThumbnail) {
      return Container(
        color: Colors.grey.shade200,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
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
          size: 20,
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

/// 未上传状态图标组件（列表视图专用）
class _UnuploadedListIcon extends StatelessWidget {
  final double size;

  const _UnuploadedListIcon({
    this.size = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/claude.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // 如果图片加载失败，显示默认图标
          return Icon(
            Icons.cloud_off,
            size: size,
            color: Colors.grey.shade600,
          );
        },
      ),
    );
  }
}

/// 列表视图构建器
class ListViewBuilder implements FileViewBuilder {
  const ListViewBuilder();

  @override
  Widget build(BuildContext context, FileViewConfig config) {
    return FileListView(
      items: config.items,
      selectedIndices: config.selectedIndices,
      isSelectionMode: config.isSelectionMode,
      padding: config.padding,
      onItemTap: config.callbacks.onTap,
      onItemDoubleTap: config.callbacks.onDoubleTap,
      onCheckboxToggle: config.callbacks.onCheckboxToggle,
    );
  }
}