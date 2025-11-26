// widgets/views/list_view.dart
import 'dart:async';
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
        return ImageListItem(
          key: ValueKey(item.path),
          item: item,
          isSelected: isSelected,
          canSelect: canSelect,
          onTap: () => widget.onItemTap(index),
          onCheckboxToggle: () => widget.onCheckboxToggle(index),
        );

      case FileItemType.video:
        return VideoListItem(
          key: ValueKey(item.path),
          item: item,
          isSelected: isSelected,
          canSelect: canSelect,
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