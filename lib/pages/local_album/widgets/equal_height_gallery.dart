// widgets/equal_height_gallery.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../../models/file_item.dart';
import '../../../services/thumbnail_helper.dart';

/// 等高画廊组件 - 实现图片、视频和文件夹等高排列布局
///
/// 核心特点：
/// 1. 文件夹、图片、视频混合在同一行显示
/// 2. 每行具有相同的高度
/// 3. 宽度根据原始宽高比自动调整
/// 4. 使用 ThumbnailHelper 生成视频缩略图
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
  // 全局宽高比缓存（跨组件实例共享）
  static final Map<String, double> _globalAspectRatioCache = {};

  // 视频缩略图缓存（跨组件实例共享）
  static final Map<String, String> _videoThumbnailCache = {};

  // 正在加载的路径集合（防止重复加载）
  static final Set<String> _loadingAspectRatioPaths = {};
  static final Set<String> _loadingThumbnailPaths = {};

  // 默认宽高比
  static const double _defaultAspectRatio = 4 / 3;
  static const double _videoDefaultAspectRatio = 16 / 9;
  // 文件夹使用 1:1 的宽高比（正方形）
  static const double _folderAspectRatio = 1.0;

  // 所有项目列表（文件夹在前，媒体在后）
  late List<_ItemData> _allItems;

  // 预计算的行布局
  List<_RowLayout>? _rowLayouts;
  double? _lastAvailableWidth;

  @override
  void initState() {
    super.initState();
    _prepareItems();
  }

  @override
  void didUpdateWidget(EqualHeightGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _prepareItems();
      _rowLayouts = null;
    }
  }

  /// 准备项目数据（文件夹在前，媒体在后，混合排列）
  void _prepareItems() {
    _allItems = [];

    // 先添加文件夹
    for (int i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      if (item.type == FileItemType.folder) {
        _allItems.add(_ItemData(
          item: item,
          originalIndex: i,
        ));
      }
    }

    // 再添加媒体文件
    for (int i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      if (item.type == FileItemType.image || item.type == FileItemType.video) {
        _allItems.add(_ItemData(
          item: item,
          originalIndex: i,
        ));
        // 预加载宽高比
        _preloadAspectRatio(item);
        // 预加载视频缩略图
        if (item.type == FileItemType.video) {
          _preloadVideoThumbnail(item);
        }
      }
    }
  }

  /// 预加载宽高比
  void _preloadAspectRatio(FileItem item) {
    if (_globalAspectRatioCache.containsKey(item.path)) return;
    if (_loadingAspectRatioPaths.contains(item.path)) return;

    _loadingAspectRatioPaths.add(item.path);
    _loadAspectRatioAsync(item);
  }

  /// 预加载视频缩略图
  void _preloadVideoThumbnail(FileItem item) {
    if (_videoThumbnailCache.containsKey(item.path)) return;
    if (_loadingThumbnailPaths.contains(item.path)) return;

    _loadingThumbnailPaths.add(item.path);
    _loadVideoThumbnailAsync(item);
  }

  /// 异步加载图片宽高比
  Future<void> _loadAspectRatioAsync(FileItem item) async {
    try {
      final file = File(item.path);
      if (!await file.exists()) {
        _loadingAspectRatioPaths.remove(item.path);
        return;
      }

      if (item.type == FileItemType.image) {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: 100,
        );
        final frame = await codec.getNextFrame();
        final image = frame.image;

        final aspectRatio = image.width / image.height;
        _globalAspectRatioCache[item.path] = aspectRatio;

        image.dispose();
        codec.dispose();
      } else {
        _globalAspectRatioCache[item.path] = _videoDefaultAspectRatio;
      }

      _loadingAspectRatioPaths.remove(item.path);

      if (mounted) {
        setState(() {
          _rowLayouts = null;
        });
      }
    } catch (e) {
      _loadingAspectRatioPaths.remove(item.path);
      _globalAspectRatioCache[item.path] =
      item.type == FileItemType.video ? _videoDefaultAspectRatio : _defaultAspectRatio;
    }
  }

  /// 异步加载视频缩略图（使用 ThumbnailHelper）
  Future<void> _loadVideoThumbnailAsync(FileItem item) async {
    try {
      if (kDebugMode) {
        print('EqualHeightGallery: Generating thumbnail for: ${item.path}');
      }

      final thumbnailPath = await ThumbnailHelper.generateThumbnail(item.path);

      if (thumbnailPath != null) {
        final file = File(thumbnailPath);
        if (await file.exists()) {
          _videoThumbnailCache[item.path] = thumbnailPath;

          // 从缩略图获取实际宽高比
          try {
            final bytes = await file.readAsBytes();
            final codec = await ui.instantiateImageCodec(bytes, targetWidth: 100);
            final frame = await codec.getNextFrame();
            final image = frame.image;
            final aspectRatio = image.width / image.height;
            _globalAspectRatioCache[item.path] = aspectRatio;
            image.dispose();
            codec.dispose();
          } catch (e) {
            // 使用默认宽高比
          }

          if (kDebugMode) {
            print('EqualHeightGallery: Thumbnail generated at: $thumbnailPath');
          }

          if (mounted) {
            setState(() {
              _rowLayouts = null;
            });
          }
        }
      }

      _loadingThumbnailPaths.remove(item.path);
    } catch (e) {
      if (kDebugMode) {
        print('EqualHeightGallery: Error generating thumbnail: $e');
      }
      _loadingThumbnailPaths.remove(item.path);
    }
  }

  /// 获取宽高比
  double _getAspectRatio(FileItem item) {
    if (item.type == FileItemType.folder) {
      return _folderAspectRatio;
    }
    if (_globalAspectRatioCache.containsKey(item.path)) {
      return _globalAspectRatioCache[item.path]!;
    }
    return item.type == FileItemType.video ? _videoDefaultAspectRatio : _defaultAspectRatio;
  }

  /// 获取视频缩略图路径
  String? _getVideoThumbnail(FileItem item) {
    return _videoThumbnailCache[item.path];
  }

  /// 检查视频缩略图是否正在加载
  bool _isLoadingThumbnail(FileItem item) {
    return _loadingThumbnailPaths.contains(item.path);
  }

  @override
  Widget build(BuildContext context) {
    if (_allItems.isEmpty) {
      return const Center(
        child: Text(
          '此文件夹为空',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
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

  /// 计算所有行的布局（文件夹和媒体混合在一起）
  List<_RowLayout> _calculateRowLayouts(double availableWidth) {
    final List<_RowLayout> rows = [];
    List<_ItemData> currentRowItems = [];
    double currentRowAspectRatioSum = 0;

    for (final itemData in _allItems) {
      final aspectRatio = _getAspectRatio(itemData.item);

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
      totalAspectRatio += _getAspectRatio(item.item);
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
      final aspectRatio = _getAspectRatio(item.item);
      final itemWidth = rowHeight * aspectRatio;
      itemLayouts.add(_ItemLayout(
        itemData: item,
        width: itemWidth,
      ));
    }

    return _RowLayout(
      items: itemLayouts,
      height: rowHeight,
    );
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
            child: itemLayout.itemData.item.type == FileItemType.folder
                ? _FolderItemWidget(
              key: ValueKey(itemLayout.itemData.item.path),
              itemData: itemLayout.itemData,
              width: itemLayout.width,
              height: rowLayout.height,
              isSelected: widget.selectedIndices.contains(itemLayout.itemData.originalIndex),
              showCheckbox: widget.isSelectionMode ||
                  widget.selectedIndices.contains(itemLayout.itemData.originalIndex),
              onTap: () => widget.onItemTap(itemLayout.itemData.originalIndex),
              onDoubleTap: () => widget.onItemDoubleTap(itemLayout.itemData.originalIndex),
              onLongPress: () => widget.onItemLongPress(itemLayout.itemData.originalIndex),
              onCheckboxToggle: () => widget.onCheckboxToggle(itemLayout.itemData.originalIndex),
            )
                : _MediaItemWidget(
              key: ValueKey(itemLayout.itemData.item.path),
              itemData: itemLayout.itemData,
              width: itemLayout.width,
              height: rowLayout.height,
              isSelected: widget.selectedIndices.contains(itemLayout.itemData.originalIndex),
              showCheckbox: widget.isSelectionMode ||
                  widget.selectedIndices.contains(itemLayout.itemData.originalIndex),
              videoThumbnailPath: _getVideoThumbnail(itemLayout.itemData.item),
              isLoadingThumbnail: _isLoadingThumbnail(itemLayout.itemData.item),
              onTap: () => widget.onItemTap(itemLayout.itemData.originalIndex),
              onDoubleTap: () => widget.onItemDoubleTap(itemLayout.itemData.originalIndex),
              onLongPress: () => widget.onItemLongPress(itemLayout.itemData.originalIndex),
              onCheckboxToggle: () => widget.onCheckboxToggle(itemLayout.itemData.originalIndex),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 文件夹项目组件（布局与 FileItemCard 一致）
class _FolderItemWidget extends StatefulWidget {
  final _ItemData itemData;
  final double width;
  final double height;
  final bool isSelected;
  final bool showCheckbox;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  final VoidCallback onCheckboxToggle;

  const _FolderItemWidget({
    super.key,
    required this.itemData,
    required this.width,
    required this.height,
    required this.isSelected,
    required this.showCheckbox,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onCheckboxToggle,
  });

  @override
  State<_FolderItemWidget> createState() => _FolderItemWidgetState();
}

class _FolderItemWidgetState extends State<_FolderItemWidget> {
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
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            children: [
              // 文件夹卡片内容（与 FileItemCard 布局一致）
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? Colors.orange.shade50
                      : (_isHovered ? Colors.grey.shade100 : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isSelected
                        ? Colors.orange
                        : (_isHovered ? Colors.grey.shade300 : Colors.grey.shade200),
                    width: widget.isSelected ? 2 : 1,
                  ),
                ),
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
                          width: widget.width * 0.5,
                          height: widget.height * 0.4,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 文件夹名称
                    Expanded(
                      flex: 1,
                      child: Text(
                        widget.itemData.item.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // 复选框 - 右上角
              if (widget.showCheckbox || _isHovered)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: widget.onCheckboxToggle,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: AnimatedContainer(
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
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 媒体项目组件（图片/视频）
class _MediaItemWidget extends StatefulWidget {
  final _ItemData itemData;
  final double width;
  final double height;
  final bool isSelected;
  final bool showCheckbox;
  final String? videoThumbnailPath;
  final bool isLoadingThumbnail;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  final VoidCallback onCheckboxToggle;

  const _MediaItemWidget({
    super.key,
    required this.itemData,
    required this.width,
    required this.height,
    required this.isSelected,
    required this.showCheckbox,
    required this.videoThumbnailPath,
    required this.isLoadingThumbnail,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onCheckboxToggle,
  });

  @override
  State<_MediaItemWidget> createState() => _MediaItemWidgetState();
}

class _MediaItemWidgetState extends State<_MediaItemWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.itemData.item.type == FileItemType.video;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 图片/视频缩略图
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: _buildThumbnail(),
              ),

              // 悬停遮罩
              if (_isHovered && !widget.isSelected)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.black.withOpacity(0.1),
                  ),
                ),

              // 选中状态边框
              if (widget.isSelected)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.orange,
                      width: 3,
                    ),
                  ),
                ),

              // 视频播放按钮
              if (isVideo)
                Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),

              // 视频标识标签
              if (isVideo)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam, color: Colors.white, size: 14),
                        SizedBox(width: 2),
                        Text(
                          '视频',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),

              // 复选框 - 右上角
              if (widget.showCheckbox || _isHovered)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: widget.onCheckboxToggle,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: AnimatedContainer(
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
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: widget.isSelected
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建缩略图
  Widget _buildThumbnail() {
    final item = widget.itemData.item;
    final isVideo = item.type == FileItemType.video;

    if (isVideo) {
      return _buildVideoThumbnail();
    } else {
      return _buildImageThumbnail();
    }
  }

  /// 构建图片缩略图
  Widget _buildImageThumbnail() {
    return Image.file(
      File(widget.itemData.item.path),
      width: widget.width,
      height: widget.height,
      fit: BoxFit.cover,
      cacheWidth: (widget.width * 2).toInt().clamp(100, 800),
      cacheHeight: (widget.height * 2).toInt().clamp(100, 800),
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
          ),
        );
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          return child;
        }
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
    );
  }

  /// 构建视频缩略图
  Widget _buildVideoThumbnail() {
    if (widget.videoThumbnailPath != null) {
      return Image.file(
        File(widget.videoThumbnailPath!),
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        cacheWidth: (widget.width * 2).toInt().clamp(100, 800),
        cacheHeight: (widget.height * 2).toInt().clamp(100, 800),
        errorBuilder: (context, error, stackTrace) {
          return _buildVideoPlaceholder();
        },
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) {
            return child;
          }
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: frame != null ? child : _buildVideoPlaceholder(),
          );
        },
      );
    } else if (widget.isLoadingThumbnail) {
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
    } else {
      return _buildVideoPlaceholder();
    }
  }

  /// 构建视频占位符
  Widget _buildVideoPlaceholder() {
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

/// 项目数据
class _ItemData {
  final FileItem item;
  final int originalIndex;

  _ItemData({
    required this.item,
    required this.originalIndex,
  });
}

/// 行布局数据
class _RowLayout {
  final List<_ItemLayout> items;
  final double height;

  _RowLayout({
    required this.items,
    required this.height,
  });
}

/// 项目布局数据
class _ItemLayout {
  final _ItemData itemData;
  final double width;

  _ItemLayout({
    required this.itemData,
    required this.width,
  });
}