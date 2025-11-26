// widgets/views/grid_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../models/file_item.dart';
import '../../services/media_cache_service.dart';
import '../common/selection_checkbox.dart';
import '../items/folder_item.dart';
import '../items/image_item.dart';
import '../items/video_item.dart';
import 'file_view_factory.dart';

/// 网格视图组件
///
/// 使用统一的 MediaCacheService 管理缓存
class FileGridView extends StatefulWidget {
  final List<FileItem> items;
  final Set<int> selectedIndices;
  final bool isSelectionMode;
  final EdgeInsets padding;
  final double itemWidth;
  final double itemAspectRatio;
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
    this.itemAspectRatio = 0.85,
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
  final MediaCacheService _cacheService = MediaCacheService.instance;
  StreamSubscription<CacheUpdateEvent>? _cacheSubscription;

  @override
  void initState() {
    super.initState();
    _preloadThumbnails();
    _subscribeToCacheUpdates();
  }

  @override
  void didUpdateWidget(FileGridView oldWidget) {
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

    return Padding(
      padding: widget.padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = ((constraints.maxWidth + widget.spacing) /
              (widget.itemWidth + widget.spacing)).floor().clamp(1, 10);

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: widget.itemAspectRatio,
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
        return FolderItem(
          key: ValueKey(item.path),
          item: item,
          isSelected: isSelected,
          showCheckbox: showCheckbox,
          onTap: () => widget.onItemTap(index),
          onDoubleTap: () => widget.onItemDoubleTap(index),
          onLongPress: () => widget.onItemLongPress(index),
          onCheckboxToggle: () => widget.onCheckboxToggle(index),
          checkboxPosition: CheckboxPosition.topRight,
        );

      case FileItemType.image:
        return ImageItem(
          key: ValueKey(item.path),
          item: item,
          isSelected: isSelected,
          showCheckbox: showCheckbox,
          onTap: () => widget.onItemTap(index),
          onDoubleTap: () => widget.onItemDoubleTap(index),
          onLongPress: () => widget.onItemLongPress(index),
          onCheckboxToggle: () => widget.onCheckboxToggle(index),
          checkboxPosition: CheckboxPosition.topRight,
          borderRadius: BorderRadius.circular(8),
        );

      case FileItemType.video:
        return VideoItem(
          key: ValueKey(item.path),
          item: item,
          isSelected: isSelected,
          showCheckbox: showCheckbox,
          thumbnailPath: _cacheService.getVideoThumbnail(item.path),
          isLoadingThumbnail: _cacheService.isLoadingThumbnail(item.path),
          onTap: () => widget.onItemTap(index),
          onDoubleTap: () => widget.onItemDoubleTap(index),
          onLongPress: () => widget.onItemLongPress(index),
          onCheckboxToggle: () => widget.onCheckboxToggle(index),
          checkboxPosition: CheckboxPosition.topRight,
          borderRadius: BorderRadius.circular(8),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

/// 网格视图构建器
class GridViewBuilder implements FileViewBuilder {
  final double itemWidth;
  final double itemAspectRatio;
  final double spacing;

  const GridViewBuilder({
    this.itemWidth = 140.0,
    this.itemAspectRatio = 0.85,
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
      itemAspectRatio: itemAspectRatio,
      spacing: spacing,
      onItemTap: config.callbacks.onTap,
      onItemDoubleTap: config.callbacks.onDoubleTap,
      onItemLongPress: config.callbacks.onLongPress,
      onCheckboxToggle: config.callbacks.onCheckboxToggle,
    );
  }
}