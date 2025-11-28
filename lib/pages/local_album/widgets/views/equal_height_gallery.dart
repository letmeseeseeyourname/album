// widgets/views/equal_height_gallery.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../models/file_item.dart';
import '../../services/media_cache_service.dart';
import '../common/selection_checkbox.dart';
import '../items/folder_item.dart';
import '../items/image_item.dart';
import '../items/video_item.dart';
import 'file_view_factory.dart';

/// 等高画廊组件 - 实现图片、视频和文件夹等高排列布局
///
/// 核心特点：
/// 1. 文件夹、图片、视频混合在同一行显示
/// 2. 每行具有相同的高度
/// 3. 宽度根据原始宽高比自动调整
/// 4. 使用 MediaCacheService 统一管理缓存
class EqualHeightGallery extends StatefulWidget {
  final List<FileItem> items;
  final Set<int> selectedIndices;
  final bool isSelectionMode;
  final double targetRowHeight;
  final double spacing;
  final EdgeInsets padding;
  final Function(int actualIndex) onItemTap;
  final Function(int actualIndex) onItemDoubleTap;
  final Function(int actualIndex) onItemLongPress;
  final Function(int actualIndex) onCheckboxToggle;

  const EqualHeightGallery({
    super.key,
    required this.items,
    required this.selectedIndices,
    required this.isSelectionMode,
    this.targetRowHeight = 200.0,
    this.spacing = 4.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
    required this.onItemTap,
    required this.onItemDoubleTap,
    required this.onItemLongPress,
    required this.onCheckboxToggle,
  });

  @override
  State<EqualHeightGallery> createState() => _EqualHeightGalleryState();
}

class _EqualHeightGalleryState extends State<EqualHeightGallery> {
  final MediaCacheService _cacheService = MediaCacheService.instance;

  // 所有项目列表（文件夹在前，媒体在后）
  late List<_ItemData> _allItems;

  // 预计算的行布局
  List<_RowLayout>? _rowLayouts;
  double? _lastAvailableWidth;

  // 缓存更新订阅
  StreamSubscription<CacheUpdateEvent>? _cacheSubscription;

  @override
  void initState() {
    super.initState();
    _prepareItems();
    _subscribeToCacheUpdates();
  }

  @override
  void didUpdateWidget(EqualHeightGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _prepareItems();
      _rowLayouts = null;
    }
  }

  @override
  void dispose() {
    _cacheSubscription?.cancel();
    super.dispose();
  }

  /// 订阅缓存更新
  void _subscribeToCacheUpdates() {
    _cacheSubscription = _cacheService.onCacheUpdate.listen((event) {
      // 检查更新的路径是否在当前项目列表中
      final hasPath = _allItems.any((item) => item.item.path == event.path);
      if (hasPath && mounted) {
        setState(() {
          _rowLayouts = null; // 重新计算布局
        });
      }
    });
  }

  /// 准备项目数据（文件夹在前，媒体在后，混合排列）
  void _prepareItems() {
    _allItems = [];

    // 先添加文件夹
    for (int i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      if (item.type == FileItemType.folder) {
        _allItems.add(_ItemData(item: item, originalIndex: i));
      }
    }

    // 再添加媒体文件
    for (int i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      if (item.type == FileItemType.image || item.type == FileItemType.video) {
        _allItems.add(_ItemData(item: item, originalIndex: i));

        // 预加载宽高比
        _cacheService.preloadAspectRatio(item);

        // 预加载视频缩略图
        if (item.type == FileItemType.video) {
          _cacheService.preloadVideoThumbnail(item.path);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_allItems.isEmpty) {
      return const EmptyStateWidget();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - widget.padding.horizontal;

        if (_rowLayouts == null || _lastAvailableWidth != availableWidth) {
          _rowLayouts = _calculateRowLayouts(availableWidth);
          _lastAvailableWidth = availableWidth;
        }

        return ListView.builder(
          padding: widget.padding,
          itemCount: _rowLayouts!.length,
          itemBuilder: (context, rowIndex) {
            return Padding(
              padding: EdgeInsets.only(bottom: widget.spacing),
              child: _buildRow(_rowLayouts![rowIndex]),
            );
          },
        );
      },
    );
  }

  /// 计算所有行的布局
  List<_RowLayout> _calculateRowLayouts(double availableWidth) {
    final List<_RowLayout> rows = [];
    List<_ItemData> currentRowItems = [];
    double currentRowAspectRatioSum = 0;

    for (final itemData in _allItems) {
      final aspectRatio = _cacheService.getAspectRatio(
        itemData.item.path,
        itemData.item.type,
      );

      final newAspectRatioSum = currentRowAspectRatioSum + aspectRatio;
      final spacingCount = currentRowItems.length;
      final totalSpacing = widget.spacing * spacingCount;
      final newRowHeight = (availableWidth - totalSpacing) / newAspectRatioSum;

      if (currentRowItems.isNotEmpty && newRowHeight < widget.targetRowHeight * 0.7) {
        rows.add(_createRowLayout(currentRowItems, availableWidth));
        currentRowItems = [itemData];
        currentRowAspectRatioSum = aspectRatio;
      } else {
        currentRowItems.add(itemData);
        currentRowAspectRatioSum = newAspectRatioSum;
      }
    }

    if (currentRowItems.isNotEmpty) {
      rows.add(_createRowLayout(currentRowItems, availableWidth, isLastRow: true));
    }

    return rows;
  }

  /// 创建行布局
  _RowLayout _createRowLayout(
      List<_ItemData> items,
      double availableWidth,
      {bool isLastRow = false}
      ) {
    double totalAspectRatio = 0;
    for (final item in items) {
      totalAspectRatio += _cacheService.getAspectRatio(item.item.path, item.item.type);
    }

    final totalSpacing = widget.spacing * (items.length - 1);
    final availableForImages = availableWidth - totalSpacing;

    double rowHeight = availableForImages / totalAspectRatio;

    if (isLastRow && rowHeight > widget.targetRowHeight * 1.2) {
      rowHeight = widget.targetRowHeight;
    }

    rowHeight = rowHeight.clamp(widget.targetRowHeight * 0.5, widget.targetRowHeight * 1.5);

    final List<_ItemLayout> itemLayouts = [];
    for (final item in items) {
      final aspectRatio = _cacheService.getAspectRatio(item.item.path, item.item.type);
      final itemWidth = rowHeight * aspectRatio;
      itemLayouts.add(_ItemLayout(itemData: item, width: itemWidth));
    }

    return _RowLayout(items: itemLayouts, height: rowHeight);
  }

  /// 构建单行
  Widget _buildRow(_RowLayout rowLayout) {
    return SizedBox(
      height: rowLayout.height,
      child: Row(
        children: rowLayout.items.asMap().entries.map((entry) {
          final index = entry.key;
          final itemLayout = entry.value;

          return Padding(
            padding: EdgeInsets.only(
              right: index < rowLayout.items.length - 1 ? widget.spacing : 0,
            ),
            child: _buildItem(itemLayout, rowLayout.height),
          );
        }).toList(),
      ),
    );
  }

  /// 构建单个项目
  Widget _buildItem(_ItemLayout itemLayout, double height) {
    final itemData = itemLayout.itemData;
    final isSelected = widget.selectedIndices.contains(itemData.originalIndex);
    final showCheckbox = widget.isSelectionMode || isSelected;
    // 判断是否未上传
    final bool showUnuploadedIcon = itemData.item.isUploaded != true;

    switch (itemData.item.type) {
      case FileItemType.folder:
        return FolderItem(
          key: ValueKey(itemData.item.path),
          item: itemData.item,
          width: itemLayout.width,
          height: height,
          isSelected: isSelected,
          showCheckbox: showCheckbox,
          onTap: () => widget.onItemTap(itemData.originalIndex),
          onDoubleTap: () => widget.onItemDoubleTap(itemData.originalIndex),
          onLongPress: () => widget.onItemLongPress(itemData.originalIndex),
          onCheckboxToggle: () => widget.onCheckboxToggle(itemData.originalIndex),
          checkboxPosition: CheckboxPosition.topRight,
        );

      case FileItemType.image:
        return _ImageItemWithUploadStatus(
          key: ValueKey(itemData.item.path),
          item: itemData.item,
          width: itemLayout.width,
          height: height,
          isSelected: isSelected,
          showCheckbox: showCheckbox,
          showUnuploadedIcon: showUnuploadedIcon,
          onTap: () => widget.onItemTap(itemData.originalIndex),
          onDoubleTap: () => widget.onItemDoubleTap(itemData.originalIndex),
          onLongPress: () => widget.onItemLongPress(itemData.originalIndex),
          onCheckboxToggle: () => widget.onCheckboxToggle(itemData.originalIndex),
          checkboxPosition: CheckboxPosition.topRight,
        );

      case FileItemType.video:
        return _VideoItemWithUploadStatus(
          key: ValueKey(itemData.item.path),
          item: itemData.item,
          width: itemLayout.width,
          height: height,
          isSelected: isSelected,
          showCheckbox: showCheckbox,
          showUnuploadedIcon: showUnuploadedIcon,
          thumbnailPath: _cacheService.getVideoThumbnail(itemData.item.path),
          isLoadingThumbnail: _cacheService.isLoadingThumbnail(itemData.item.path),
          onTap: () => widget.onItemTap(itemData.originalIndex),
          onDoubleTap: () => widget.onItemDoubleTap(itemData.originalIndex),
          onLongPress: () => widget.onItemLongPress(itemData.originalIndex),
          onCheckboxToggle: () => widget.onCheckboxToggle(itemData.originalIndex),
          checkboxPosition: CheckboxPosition.topRight,
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

/// 带上传状态的图片项目包装组件
class _ImageItemWithUploadStatus extends StatelessWidget {
  final FileItem item;
  final double width;
  final double height;
  final bool isSelected;
  final bool showCheckbox;
  final bool showUnuploadedIcon;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  final VoidCallback onCheckboxToggle;
  final CheckboxPosition checkboxPosition;

  const _ImageItemWithUploadStatus({
    super.key,
    required this.item,
    required this.width,
    required this.height,
    required this.isSelected,
    required this.showCheckbox,
    required this.showUnuploadedIcon,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onCheckboxToggle,
    required this.checkboxPosition,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ImageItem(
          item: item,
          width: width,
          height: height,
          isSelected: isSelected,
          showCheckbox: showCheckbox,
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onLongPress: onLongPress,
          onCheckboxToggle: onCheckboxToggle,
          checkboxPosition: checkboxPosition,
        ),
        // 未上传状态图标 - 右下角
        if (showUnuploadedIcon)
          Positioned(
            right: 4,
            bottom: 4,
            child: _UnuploadedIcon(size: 20),
          ),
      ],
    );
  }
}

/// 带上传状态的视频项目包装组件
class _VideoItemWithUploadStatus extends StatelessWidget {
  final FileItem item;
  final double width;
  final double height;
  final bool isSelected;
  final bool showCheckbox;
  final bool showUnuploadedIcon;
  final String? thumbnailPath;
  final bool isLoadingThumbnail;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  final VoidCallback onCheckboxToggle;
  final CheckboxPosition checkboxPosition;

  const _VideoItemWithUploadStatus({
    super.key,
    required this.item,
    required this.width,
    required this.height,
    required this.isSelected,
    required this.showCheckbox,
    required this.showUnuploadedIcon,
    this.thumbnailPath,
    this.isLoadingThumbnail = false,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onCheckboxToggle,
    required this.checkboxPosition,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        VideoItem(
          item: item,
          width: width,
          height: height,
          isSelected: isSelected,
          showCheckbox: showCheckbox,
          thumbnailPath: thumbnailPath,
          isLoadingThumbnail: isLoadingThumbnail,
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onLongPress: onLongPress,
          onCheckboxToggle: onCheckboxToggle,
          checkboxPosition: checkboxPosition,
        ),
        // 未上传状态图标 - 右下角
        if (showUnuploadedIcon)
          Positioned(
            right: 4,
            bottom: 4,
            child: _UnuploadedIcon(size: 20),
          ),
      ],
    );
  }
}

/// 未上传状态图标组件
class _UnuploadedIcon extends StatelessWidget {
  final double size;

  const _UnuploadedIcon({
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

/// 等高视图构建器
class EqualHeightViewBuilder implements FileViewBuilder {
  final double targetRowHeight;
  final double spacing;

  const EqualHeightViewBuilder({
    this.targetRowHeight = 200.0,
    this.spacing = 4.0,
  });

  @override
  Widget build(BuildContext context, FileViewConfig config) {
    return EqualHeightGallery(
      items: config.items,
      selectedIndices: config.selectedIndices,
      isSelectionMode: config.isSelectionMode,
      targetRowHeight: targetRowHeight,
      spacing: spacing,
      padding: config.padding,
      onItemTap: config.callbacks.onTap,
      onItemDoubleTap: config.callbacks.onDoubleTap,
      onItemLongPress: config.callbacks.onLongPress,
      onCheckboxToggle: config.callbacks.onCheckboxToggle,
    );
  }
}

/// 项目数据
class _ItemData {
  final FileItem item;
  final int originalIndex;

  _ItemData({required this.item, required this.originalIndex});
}

/// 行布局数据
class _RowLayout {
  final List<_ItemLayout> items;
  final double height;

  _RowLayout({required this.items, required this.height});
}

/// 项目布局数据
class _ItemLayout {
  final _ItemData itemData;
  final double width;

  _ItemLayout({required this.itemData, required this.width});
}