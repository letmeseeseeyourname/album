// pages/folder_detail_page.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../models/file_item.dart';
import '../models/folder_info.dart';
import '../services/thumbnail_helper.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/side_navigation.dart';

class FolderDetailPage extends StatefulWidget {
  final FolderInfo folder;
  final int selectedNavIndex;
  final Function(int)? onNavigationChanged;

  const FolderDetailPage({
    super.key,
    required this.folder,
    this.selectedNavIndex = 0,  // 默认值
    this.onNavigationChanged,  // 可选参数
  });

  @override
  State<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends State<FolderDetailPage> {
  final ThumbnailHelper _helper = ThumbnailHelper();
  List<FileItem> fileItems = [];
  List<String> pathSegments = [];
  String currentPath = '';
  bool isLoading = true;

  // 选择模式相关
  Set<int> selectedIndices = {};
  bool isSelectionMode = false;

  // 文件类型筛选: 'all', 'image', 'video'
  String filterType = 'all';
  bool isFilterMenuOpen = false;

  // 视图模式: true为grid，false为list
  bool isGridView = true;

  @override
  void initState() {
    super.initState();
    currentPath = widget.folder.path;
    _initPathSegments();
    _initializeHelper();
    _loadFiles(currentPath);
  }

  void _initPathSegments() {
    // 初始化路径段：[磁盘, 文件夹名]
    final parts = widget.folder.path.split(Platform.pathSeparator);
    if (parts.isNotEmpty) {
      pathSegments = [parts[0], widget.folder.name];
    }
  }
  /// 初始化 C# 辅助程序并处理可能出现的错误。
  Future<void> _initializeHelper() async {
    try {
      await _helper.initializeHelper();
    } catch (e) {
      // 捕获并显示错误信息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('缩略图功能不可用:请确保 ThumbnailGenerator.exe 在 assets 目录'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadFiles(String path) async {
    setState(() {
      isLoading = true;
      fileItems.clear();
      // 清空选择状态，避免索引越界
      selectedIndices.clear();
      isSelectionMode = false;
    });

    try {
      // 在后台线程加载文件列表，避免阻塞UI
      final items = await compute(_loadFilesInBackground, path);

      if (mounted) {
        setState(() {
          fileItems = items;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading files: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // 在后台线程中执行的文件加载函数
  static Future<List<FileItem>> _loadFilesInBackground(String path) async {
    final directory = Directory(path);
    final entities = await directory.list().toList();

    final items = <FileItem>[];

    for (var entity in entities) {
      if (entity is Directory) {
        // 添加文件夹
        items.add(
          FileItem(
            name: entity.path.split(Platform.pathSeparator).last,
            path: entity.path,
            type: FileItemType.folder,
          ),
        );
      } else if (entity is File) {
        final ext = entity.path.split('.').last.toLowerCase();
        FileItemType? type;

        // 判断文件类型
        if ([ 'bmp', 'gif', 'jpg', 'jpeg', 'png', 'webp', 'wbmp', 'heic'].contains(ext)) {
          type = FileItemType.image;
        } else if (['mp4', 'mov', 'avi', '3gp', 'mkv', '3gp2'].contains(ext)) {
          type = FileItemType.video;
        }

        // 只添加文件夹、图片和视频
        if (type != null) {
          final stat = await entity.stat();
          items.add(
            FileItem(
              name: entity.path.split(Platform.pathSeparator).last,
              path: entity.path,
              type: type,
              size: stat.size,
            ),
          );
        }
      }
    }

    // 排序：文件夹在前，然后按名称排序
    items.sort((a, b) {
      if (a.type == FileItemType.folder && b.type != FileItemType.folder) {
        return -1;
      }
      if (a.type != FileItemType.folder && b.type == FileItemType.folder) {
        return 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return items;
  }

  void _navigateToFolder(String folderPath, String folderName) {
    setState(() {
      currentPath = folderPath;
      pathSegments.add(folderName);
    });
    _loadFiles(folderPath);
  }

  void _navigateToPathSegment(int index) {
    if (index == 0) {
      // 返回主页
      Navigator.pop(context);
      return;
    }

    // 返回到指定路径段
    final targetSegments = pathSegments.sublist(0, index + 1);
    final targetPath = _buildPathFromSegments(targetSegments);

    setState(() {
      pathSegments = targetSegments;
      currentPath = targetPath;
    });
    _loadFiles(targetPath);
  }

  String _buildPathFromSegments(List<String> segments) {
    if (segments.length <= 1) return widget.folder.path;

    // 重建路径
    final parts = widget.folder.path.split(Platform.pathSeparator);
    final basePath = parts
        .sublist(0, parts.length - 1)
        .join(Platform.pathSeparator);
    final additionalPath = segments.sublist(2).join(Platform.pathSeparator);

    if (additionalPath.isEmpty) {
      return widget.folder.path;
    }
    return '$basePath${Platform.pathSeparator}$additionalPath';
  }

  /// 处理导航切换：如果切换到不同的导航项，先返回主页面
  void _handleNavigationChanged(int index) {
    if (index != widget.selectedNavIndex) {
      // 先关闭详情页
      Navigator.pop(context);
      // 然后通知主页面切换导航
      widget.onNavigationChanged?.call(index);
    }
  }

  /// 切换选择
  void _toggleSelection(int index) {
    // 文件夹不参与选择，只选择图片和视频
    if (fileItems[index].type == FileItemType.folder) {
      return;
    }

    setState(() {
      if (selectedIndices.contains(index)) {
        selectedIndices.remove(index);
        if (selectedIndices.isEmpty) {
          isSelectionMode = false;
        }
      } else {
        selectedIndices.add(index);
        isSelectionMode = true;
      }
    });
  }

  /// 全选或取消全选
  void _toggleSelectAll() {
    setState(() {
      if (selectedIndices.length == _getSelectableCount()) {
        // 当前已全选，执行取消全选
        selectedIndices.clear();
        isSelectionMode = false;
      } else {
        // 执行全选（只选择图片和视频，不选文件夹）
        selectedIndices.clear();
        for (int i = 0; i < fileItems.length; i++) {
          if (fileItems[i].type != FileItemType.folder) {
            selectedIndices.add(i);
          }
        }
        isSelectionMode = true;
      }
    });
  }

  /// 取消选择
  void _cancelSelection() {
    setState(() {
      selectedIndices.clear();
      isSelectionMode = false;
    });
  }

  /// 获取可选择的项目数量（不包括文件夹）
  int _getSelectableCount() {
    return fileItems.where((item) => item.type != FileItemType.folder).length;
  }

  /// 获取过滤后的文件列表
  List<FileItem> _getFilteredFiles() {
    if (filterType == 'all') {
      return fileItems;
    } else if (filterType == 'image') {
      return fileItems.where((item) =>
      item.type == FileItemType.folder || item.type == FileItemType.image
      ).toList();
    } else if (filterType == 'video') {
      return fileItems.where((item) =>
      item.type == FileItemType.folder || item.type == FileItemType.video
      ).toList();
    }
    return fileItems;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomTitleBar(
        backgroundColor: Color(0xFFF5E8DC),
        rightTitleBgColor: Colors.white,
        showToolbar: true,
        child: Row(
          children: [
            // 如果提供了导航回调，使用可交互的导航；否则使用静态导航
            widget.onNavigationChanged != null
                ? SideNavigation(
              selectedIndex: widget.selectedNavIndex,
              onNavigationChanged: _handleNavigationChanged,
            )
                : const _StaticSideNavigation(),
            Expanded(
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildFileGrid(),
                    ),
                    _buildBottomBar(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: Row(
        children: [
          // 面包屑导航
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                for (int i = 0; i < pathSegments.length; i++) ...[
                  GestureDetector(
                    onTap: () => _navigateToPathSegment(i),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Text(
                        i == 0 ? '此电脑' : pathSegments[i],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: i == pathSegments.length - 1
                              ? Colors.black
                              : Colors.blue,
                          decoration: i == pathSegments.length - 1
                              ? null
                              : TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  if (i < pathSegments.length - 1)
                    const Text(' / ', style: TextStyle(fontSize: 16)),
                ],
              ],
            ),
          ),
          // 操作按钮
          // 全选/取消全选按钮
          IconButton(
            icon: Icon(
              selectedIndices.length == _getSelectableCount() && selectedIndices.isNotEmpty
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
            ),
            onPressed: _toggleSelectAll,
            tooltip: selectedIndices.length == _getSelectableCount() && selectedIndices.isNotEmpty
                ? '取消全选'
                : '全选',
          ),
          // 筛选按钮（带下拉菜单）
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: '筛选',
            offset: const Offset(0, 45),
            onSelected: (value) {
              setState(() {
                filterType = value;
                // 切换筛选类型时清除选择
                selectedIndices.clear();
                isSelectionMode = false;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    if (filterType == 'all')
                      const Icon(Icons.check, size: 20, color: Colors.orange)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 12),
                    const Text('全部'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'image',
                child: Row(
                  children: [
                    if (filterType == 'image')
                      const Icon(Icons.check, size: 20, color: Colors.orange)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 12),
                    const Text('照片'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'video',
                child: Row(
                  children: [
                    if (filterType == 'video')
                      const Icon(Icons.check, size: 20, color: Colors.orange)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 12),
                    const Text('视频'),
                  ],
                ),
              ),
            ],
          ),
          // Grid视图按钮
          IconButton(
            icon: Icon(
              Icons.grid_view,
              color: isGridView ? const Color(0xFF2C2C2C) : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                isGridView = true;
              });
            },
            tooltip: '网格视图',
          ),
          // List视图按钮
          IconButton(
            icon: Icon(
              Icons.list,
              color: !isGridView ? const Color(0xFF2C2C2C) : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                isGridView = false;
              });
            },
            tooltip: '列表视图',
          ),
        ],
      ),
    );
  }

  Widget _buildFileGrid() {
    final filteredFiles = _getFilteredFiles();

    if (filteredFiles.isEmpty) {
      return const Center(
        child: Text(
          '此文件夹为空',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    // 根据视图模式显示不同的布局
    if (isGridView) {
      return _buildGridView(filteredFiles);
    } else {
      return _buildListView(filteredFiles);
    }
  }

  /// 网格视图
  Widget _buildGridView(List<FileItem> filteredFiles) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const itemWidth = 140.0;
          const spacing = 20.0;
          final crossAxisCount =
          ((constraints.maxWidth + spacing) / (itemWidth + spacing))
              .floor()
              .clamp(1, 10);
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.85,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: filteredFiles.length,
            cacheExtent: 1000,
            itemBuilder: (context, displayIndex) {
              // 找到原始索引
              final originalIndex = fileItems.indexOf(filteredFiles[displayIndex]);
              final isSelected = selectedIndices.contains(originalIndex);
              final canSelect = filteredFiles[displayIndex].type != FileItemType.folder;

              return RepaintBoundary(
                child: _FileItemCard(
                  item: filteredFiles[displayIndex],
                  isSelected: isSelected,
                  showCheckbox: isSelectionMode,  // 修复：只在选择模式下显示所有复选框
                  canSelect: canSelect,
                  onTap: () {
                    if (isSelectionMode && canSelect) {
                      _toggleSelection(originalIndex);
                    } else if (filteredFiles[displayIndex].type == FileItemType.folder) {
                      _navigateToFolder(
                        filteredFiles[displayIndex].path,
                        filteredFiles[displayIndex].name,
                      );
                    }
                  },
                  onLongPress: () {
                    if (canSelect) {
                      _toggleSelection(originalIndex);
                    }
                  },
                  onCheckboxToggle: () {
                    if (canSelect) {
                      _toggleSelection(originalIndex);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// 列表视图
  Widget _buildListView(List<FileItem> filteredFiles) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: ListView.builder(
        itemCount: filteredFiles.length,
        itemBuilder: (context, displayIndex) {
          final originalIndex = fileItems.indexOf(filteredFiles[displayIndex]);
          final isSelected = selectedIndices.contains(originalIndex);
          final canSelect = filteredFiles[displayIndex].type != FileItemType.folder;
          final item = filteredFiles[displayIndex];

          return _FileListItem(
            item: item,
            isSelected: isSelected,
            canSelect: canSelect,
            onTap: () {
              if (isSelectionMode && canSelect) {
                _toggleSelection(originalIndex);
              } else if (item.type == FileItemType.folder) {
                _navigateToFolder(item.path, item.name);
              }
            },
            onCheckboxToggle: () {
              if (canSelect) {
                _toggleSelection(originalIndex);
              }
            },
          );
        },
      ),
    );
  }

  /// 计算选中项目中的照片数量
  int _getSelectedImageCount() {
    return selectedIndices
        .where((index) => index < fileItems.length && fileItems[index].type == FileItemType.image)
        .length;
  }

  /// 计算选中项目中的视频数量
  int _getSelectedVideoCount() {
    return selectedIndices
        .where((index) => index < fileItems.length && fileItems[index].type == FileItemType.video)
        .length;
  }

  /// 计算选中项目的总大小（MB）
  double _getSelectedTotalSize() {
    int totalBytes = selectedIndices
        .where((index) => index < fileItems.length)
        .map((index) => fileItems[index])
        .where((item) => item.type != FileItemType.folder)
        .fold(0, (sum, item) => sum + item.size);
    return totalBytes / (1024 * 1024);
  }

  /// 构建底部统计栏（只在有选中项时显示）
  Widget _buildBottomBar() {
    // 如果没有选中项，返回空容器
    if (selectedIndices.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Text(
            '已选：${_getSelectedTotalSize().toStringAsFixed(2)}MB · ${_getSelectedImageCount()}张照片/${_getSelectedVideoCount()}条视频',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const Spacer(),
          Text(
            '设备剩余空间：320GB',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 30),
          ElevatedButton(
            onPressed: () {
              // TODO: 实现同步功能
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C2C2C),
              padding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              '同步',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 静态导航组件（不可交互）- 用于向后兼容
class _StaticSideNavigation extends StatelessWidget {
  const _StaticSideNavigation();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      color: const Color(0xFFF5E8DC),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildNavButton(Icons.home, '本地图库', true),
          _buildNavButton(Icons.cloud, '相册图库', false),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2C2C2C) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.black,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _FileItemCard extends StatefulWidget {
  final FileItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onCheckboxToggle;
  final bool isSelected;
  final bool showCheckbox;
  final bool canSelect;

  const _FileItemCard({
    required this.item,
    required this.onTap,
    required this.onLongPress,
    required this.onCheckboxToggle,
    required this.isSelected,
    required this.showCheckbox,
    required this.canSelect,
  });

  @override
  State<_FileItemCard> createState() => _FileItemCardState();
}

class _FileItemCardState extends State<_FileItemCard> with AutomaticKeepAliveClientMixin {
  bool isHovered = false;
  String? videoThumbnailPath;
  bool isLoadingThumbnail = false;
  bool _hasAttemptedLoad = false;

  @override
  bool get wantKeepAlive => videoThumbnailPath != null;

  @override
  void initState() {
    super.initState();
    // 延迟生成视频缩略图，等待 widget 构建完成后再加载
    if (widget.item.type == FileItemType.video) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasAttemptedLoad) {
          _generateVideoThumbnail();
        }
      });
    }
  }

  Future<void> _generateVideoThumbnail() async {
    if (isLoadingThumbnail || _hasAttemptedLoad) return;

    setState(() {
      isLoadingThumbnail = true;
      _hasAttemptedLoad = true;
    });

    try {
      print('Generating thumbnail for: ${widget.item.path}');

      final thumbnailPath = await ThumbnailHelper.generateThumbnail(
        widget.item.path,
      );

      print('Thumbnail generated at: $thumbnailPath');

      if (mounted && thumbnailPath != null) {
        // 验证文件是否存在
        final file = File(thumbnailPath);
        if (await file.exists()) {
          print('Thumbnail file exists, size: ${await file.length()} bytes');
          setState(() {
            videoThumbnailPath = thumbnailPath;
            isLoadingThumbnail = false;
          });
          // 更新 keepAlive 状态
          updateKeepAlive();
        } else {
          print('Thumbnail file does not exist');
          setState(() {
            isLoadingThumbnail = false;
          });
        }
      } else {
        if (kDebugMode) {
          print('Thumbnail path is null or widget disposed');
        }
        if (mounted) {
          setState(() {
            isLoadingThumbnail = false;
          });
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error generating video thumbnail: $e');
        print('Stack trace: $stackTrace');
      }
      if (mounted) {
        setState(() {
          isLoadingThumbnail = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // 清理缩略图缓存（可选）
    if (videoThumbnailPath != null) {
      try {
        File(videoThumbnailPath!).delete();
      } catch (e) {
        // 忽略删除错误
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用以支持 AutomaticKeepAliveClientMixin
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: widget.item.type == FileItemType.folder
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: SizedBox(
          // 设置固定宽度和高度，确保所有item尺寸一致
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? Colors.orange.shade50
                      : (isHovered ? Colors.grey.shade100 : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isSelected
                        ? Colors.orange
                        : (isHovered ? Colors.grey.shade300 : Colors.transparent),
                    width: widget.isSelected ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildIcon(),
                    const SizedBox(height: 8),
                    // 使用 Flexible 包裹文本，确保不会溢出
                    Flexible(
                      child: Text(
                        widget.item.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.item.type != FileItemType.folder &&
                        widget.item.formattedSize.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.item.formattedSize,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
              ),
              // 复选框 - 只在可选择时显示
              if (widget.canSelect && (widget.showCheckbox || isHovered || widget.isSelected))
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
                            ? const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.white,
                        )
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

  Widget _buildIcon() {
    switch (widget.item.type) {
      case FileItemType.folder:
        return SizedBox(
          width: 80,
          height: 80,  // 统一高度为80，与图片和视频保持一致
          child: Center(
            child: SvgPicture.asset(
              'assets/icons/folder_icon.svg',
              width: 80,
              height: 64,
              fit: BoxFit.contain,
            ),
          ),
        );
      case FileItemType.image:
      // 显示图片缩略图，使用 cacheWidth 和 cacheHeight 优化内存
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(
              File(widget.item.path),
              fit: BoxFit.cover,
              // 关键优化：限制图片解码尺寸，减少内存占用
              cacheWidth: 160, // 2倍显示尺寸用于高清屏
              cacheHeight: 160,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.image, size: 32, color: Colors.grey);
              },
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) {
                  return child;
                }
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: child,
                );
              },
            ),
          ),
        );
      case FileItemType.video:
      // 显示视频首帧缩略图
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (videoThumbnailPath != null)
                  Image.file(
                    File(videoThumbnailPath!),
                    fit: BoxFit.cover,
                    // 优化：限制缩略图解码尺寸
                    cacheWidth: 160,
                    cacheHeight: 160,
                  )
                else if (isLoadingThumbnail)
                  Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  )
                else
                  Icon(Icons.videocam, size: 32, color: Colors.grey.shade600),
                // 播放按钮叠加层
                Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}

// 列表视图的文件项组件
class _FileListItem extends StatefulWidget {
  final FileItem item;
  final bool isSelected;
  final bool canSelect;
  final VoidCallback onTap;
  final VoidCallback onCheckboxToggle;

  const _FileListItem({
    required this.item,
    required this.isSelected,
    required this.canSelect,
    required this.onTap,
    required this.onCheckboxToggle,
  });

  @override
  State<_FileListItem> createState() => _FileListItemState();
}

class _FileListItemState extends State<_FileListItem> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.orange.shade50
                : (isHovered ? Colors.grey.shade50 : Colors.transparent),
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              // 复选框（只在可选择时显示）
              if (widget.canSelect)
                GestureDetector(
                  onTap: widget.onCheckboxToggle,
                  child: Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: widget.isSelected ? Colors.orange : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.isSelected ? Colors.orange : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: widget.isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                )
              else
                const SizedBox(width: 36),

              // 图标
              _buildIcon(),
              const SizedBox(width: 12),

              // 文件名
              Expanded(
                flex: 3,
                child: Text(
                  widget.item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 大小
              Expanded(
                flex: 1,
                child: Text(
                  widget.item.type == FileItemType.folder ? '-' : widget.item.formattedSize,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),

              const SizedBox(width: 20),

              // 类型
              Expanded(
                flex: 1,
                child: Text(
                  _getTypeText(),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    switch (widget.item.type) {
      case FileItemType.folder:
        return SizedBox(
          width: 32,
          height: 32,
          child: SvgPicture.asset(
            'assets/icons/folder_icon.svg',
            fit: BoxFit.contain,
          ),
        );
      case FileItemType.image:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(
              File(widget.item.path),
              fit: BoxFit.cover,
              cacheWidth: 64,
              cacheHeight: 64,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.image, size: 20, color: Colors.grey);
              },
            ),
          ),
        );
      case FileItemType.video:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(Icons.videocam, size: 20, color: Colors.grey.shade600),
        );
    }
  }

  String _getTypeText() {
    switch (widget.item.type) {
      case FileItemType.folder:
        return '文件夹';
      case FileItemType.image:
        return 'JPG';
      case FileItemType.video:
        return 'MP4';
    }
  }
}