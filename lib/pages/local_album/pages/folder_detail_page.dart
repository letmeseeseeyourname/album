// pages/folder_detail_page_refactored.dart
import 'package:flutter/material.dart';
import 'package:ablumwin/user/my_instance.dart';

import '../../../album/manager/local_folder_upload_manager.dart';
import '../controllers/path_navigation_controller.dart';
import '../controllers/preview_controller.dart';
import '../controllers/selection_controller.dart';
import '../controllers/upload_coordinator.dart';
import '../../../models/file_item.dart';
import '../../../models/folder_info.dart';
import '../../../models/media_item.dart';
import '../services/file_service.dart';
import '../../../services/thumbnail_helper.dart';
import '../../../widgets/custom_title_bar.dart';
import '../../../widgets/file_item_card.dart';
import '../../../widgets/file_list_item.dart';
import '../widgets/folder_detail_bottom_bar.dart';
import '../widgets/folder_detail_top_bar.dart';
import '../../../widgets/media_viewer_page.dart';
import '../widgets/preview_panel.dart';
import '../../../widgets/side_navigation.dart';

/// 重构后的文件夹详情页面
/// 使用控制器模式将业务逻辑从UI中分离
class FolderDetailPageRefactored extends StatefulWidget {
  final FolderInfo folder;
  final int selectedNavIndex;
  final Function(int)? onNavigationChanged;

  const FolderDetailPageRefactored({
    super.key,
    required this.folder,
    this.selectedNavIndex = 0,
    this.onNavigationChanged,
  });

  @override
  State<FolderDetailPageRefactored> createState() => _FolderDetailPageRefactoredState();
}

class _FolderDetailPageRefactoredState extends State<FolderDetailPageRefactored> {
  // 服务和辅助类
  final ThumbnailHelper _thumbnailHelper = ThumbnailHelper();
  final FileService _fileService = FileService();

  // 控制器
  late final PathNavigationController _pathController;
  late final SelectionController _selectionController;
  late final PreviewController _previewController;
  late final UploadCoordinator _uploadCoordinator;

  // 数据状态
  List<FileItem> _fileItems = [];
  bool _isLoading = true;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeHelper();
    _loadFiles(_pathController.currentPath);
  }

  @override
  void dispose() {
    _uploadCoordinator.removeListener(_onUploadProgressChanged);
    _previewController.dispose();
    super.dispose();
  }

  /// 初始化控制器
  void _initializeControllers() {
    _pathController = PathNavigationController();
    _pathController.initializePath(widget.folder.path, widget.folder.name);

    _selectionController = SelectionController();
    _previewController = PreviewController();

    _uploadCoordinator = UploadCoordinator(
      LocalFolderUploadManager(),
      _fileService,
    );
    _uploadCoordinator.addListener(_onUploadProgressChanged);
  }

  /// 初始化缩略图辅助工具
  Future<void> _initializeHelper() async {
    try {
      await _thumbnailHelper.initializeHelper();
    } catch (e) {
      if (mounted) {
        _showMessage('缩略图功能不可用:请确保 ThumbnailGenerator.exe 在 assets 目录', isError: true);
      }
    }
  }

  // ============ 数据加载 ============

  /// 加载文件列表
  Future<void> _loadFiles(String path) async {
    setState(() {
      _isLoading = true;
      _fileItems.clear();
      _selectionController.reset();
      _previewController.closePreview();
    });

    try {
      final items = await _fileService.loadFiles(path);

      if (mounted) {
        setState(() {
          _fileItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading files: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============ 导航相关 ============

  /// 导航到子文件夹
  void _navigateToFolder(String folderPath, String folderName) {
    _pathController.navigateToFolder(folderPath, folderName);
    _loadFiles(folderPath);
  }

  /// 导航到指定路径段
  void _navigateToPathSegment(int index) {
    final result = _pathController.navigateToSegment(index);
    if (result.shouldPopPage) {
      Navigator.pop(context);
    } else if (result.newPath != null) {
      _loadFiles(result.newPath!);
    }
  }

  /// 处理导航栏切换
  void _handleNavigationChanged(int index) {
    if (index != widget.selectedNavIndex) {
      Navigator.pop(context);
      widget.onNavigationChanged?.call(index);
    }
  }

  // ============ 选择相关 ============

  /// 切换选择状态
  void _toggleSelection(int index) {
    setState(() {
      _selectionController.toggleSelection(index);
    });
  }

  /// 全选/取消全选
  void _toggleSelectAll() {
    setState(() {
      _selectionController.toggleSelectAll(_fileItems.length);
    });
  }

  /// 设置筛选类型
  void _setFilterType(String type) {
    setState(() {
      _selectionController.setFilterType(type);
    });
  }

  /// 设置视图模式
  void _setViewMode(bool isGridView) {
    setState(() {
      _isGridView = isGridView;
    });
  }

  // ============ 预览相关 ============

  /// 打开预览
  void _openPreview(int index) {
    setState(() {
      _previewController.openPreview(index, _fileItems);
    });
    _loadPreviewMedia();
  }

  /// 关闭预览
  void _closePreview() {
    setState(() {
      _previewController.closePreview();
    });
  }

  /// 加载预览媒体
  void _loadPreviewMedia() {
    final item = _previewController.getCurrentPreviewItem();
    if (item != null && item.type == FileItemType.video) {
      _previewController.initVideoPlayer(item.path, (playing) {
        if (mounted) {
          setState(() {});
        }
      });
    } else {
      _previewController.disposeVideoPlayer();
    }
  }

  /// 切换到上一个媒体
  void _previousMedia() {
    setState(() {
      _previewController.previousMedia();
    });
    _loadPreviewMedia();
  }

  /// 切换到下一个媒体
  void _nextMedia() {
    setState(() {
      _previewController.nextMedia();
    });
    _loadPreviewMedia();
  }

  /// 打开全屏查看器
  void _openFullScreenViewer(int index) {
    final mediaItems = _fileItems
        .where((item) =>
    item.type == FileItemType.image || item.type == FileItemType.video)
        .map((fileItem) => MediaItem.fromFileItem(fileItem))
        .toList();

    final currentItem = _fileItems[index];
    final mediaFileItems = _fileItems
        .where((item) =>
    item.type == FileItemType.image || item.type == FileItemType.video)
        .toList();
    final mediaIndex = mediaFileItems.indexOf(currentItem);

    if (mediaIndex >= 0 && mediaItems.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MediaViewerPage(
            mediaItems: mediaItems,
            initialIndex: mediaIndex,
          ),
        ),
      );
    }
  }

  // ============ 上传相关 ============

  /// 上传进度变化回调
  void _onUploadProgressChanged() {
    if (mounted) {
      setState(() {
        // _uploadCoordinator.updateProgress();
      });
    }
  }

  // ============ 文件上传改进版 _handleSync 方法 ============
// 改进点:
// 1. 移除上传阻塞检查 - 允许多任务并发上传
// 2. 确认后立即取消选中 - 提升用户体验
// 3. 简化回调逻辑 - 不再在完成时操作选择状态

  /// 处理同步上传
  Future<void> _handleSync() async {
    if (_selectionController.selectedCount == 0) {
      _showMessage('请先选择要上传的文件或文件夹', isError: true);
      return;
    }

    // ✅ 改进2: 移除上传中的阻塞检查,允许继续选择并开启新的上传任务
    // ❌ 旧代码 (已删除):
    // if (_uploadCoordinator.isUploading) {
    //   _showMessage('已有上传任务在进行中', isError: true);
    //   return;
    // }

    // 准备上传
    final selectedItems = _selectionController.getSelectedItems(_fileItems);

    // 只在选中了文件夹时显示扫描提示
    final hasFolder = selectedItems.any((item) => item.type == FileItemType.folder);
    if (hasFolder) {
      _showMessage('正在扫描选中的文件夹，请稍候...', isError: false);
    }

    final prepareResult = await _uploadCoordinator.prepareUpload(selectedItems);

    if (!prepareResult.success) {
      _showMessage(prepareResult.message!, isError: true);
      return;
    }

    // 显示确认对话框
    final confirmed = await _showConfirmDialog(
      prepareResult.filePaths!,
      prepareResult.imageCount!,
      prepareResult.videoCount!,
      prepareResult.totalSizeMB!,
    );

    if (!confirmed) return;

    // ✅ 改进1: 用户确认上传后立即取消选中状态,允许继续选择其他文件
    // 这是新增的关键代码
    setState(() {
      _selectionController.cancelSelection();
    });

    // 开始上传
    await _uploadCoordinator.startUpload(
      prepareResult.filePaths!,
          (String message, {bool isError = false}) => _showMessage(message, isError: isError),
          () {
        // ✅ 改进3: 简化上传完成回调
        // ❌ 旧代码 (已删除):
        // if (mounted) {
        //   setState(() {
        //     if (_uploadCoordinator.uploadProgress != null) {
        //       _selectionController.cancelSelection();
        //     }
        //   });
        // }

        // ✅ 新代码 (简洁明了):
        if (mounted) {
          setState(() {
            // 上传完成后刷新界面即可
            // 选中状态已在确认时取消,无需再次操作
          });
        }
      },
    );
  }

  /// 显示确认对话框
  Future<bool> _showConfirmDialog(
      List<String> filePaths,
      int imageCount,
      int videoCount,
      double totalSizeMB,
      ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认上传'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('即将上传 ${filePaths.length} 个文件：'),
            const SizedBox(height: 8),
            Text('• $imageCount 张照片'),
            Text('• $videoCount 个视频'),
            Text('• 总大小：${totalSizeMB.toStringAsFixed(2)} MB'),
            const SizedBox(height: 16),
            const Text(
              '上传过程中请勿关闭窗口',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C2C2C),
            ),
            child: const Text('开始上传'),
          ),
        ],
      ),
    ) ??
        false;
  }

  /// 显示消息
  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============ 辅助方法 ============

  /// 获取设备存储使用情况
  double _getDeviceStorageUsed() {
    double used = MyInstance().p6deviceInfoModel?.ttlUsed ?? 0;
    double scaled = used * 100.0;
    int usedPercent = scaled.round();
    return usedPercent / 100.0;
  }

  // ============ UI构建 ============

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomTitleBar(
        backgroundColor: const Color(0xFFF5E8DC),
        rightTitleBgColor: Colors.white,
        showToolbar: true,
        child: Row(
          children: [
            // 侧边导航
            widget.onNavigationChanged != null
                ? SideNavigation(
              selectedIndex: widget.selectedNavIndex,
              onNavigationChanged: _handleNavigationChanged,
            )
                : const _StaticSideNavigation(),

            // 主内容区域
            Expanded(
              child: Row(
                children: [
                  // 文件列表区域
                  Expanded(
                    flex: _previewController.showPreview ? 3 : 1,
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          _buildTopBar(),
                          Expanded(
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : _buildFileGrid(),
                          ),
                          _buildBottomBar(),
                        ],
                      ),
                    ),
                  ),

                  // 预览区域
                  if (_previewController.showPreview)
                    Expanded(
                      flex: 2,
                      child: _buildPreviewPanel(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return FolderDetailTopBar(
      pathSegments: _pathController.pathSegments,
      onPathSegmentTap: _navigateToPathSegment,
      isSelectAllChecked: _selectionController.selectedCount == _fileItems.length &&
          _selectionController.selectedCount > 0,
      onSelectAllToggle: _toggleSelectAll,
      filterType: _selectionController.filterType,
      onFilterChange: _setFilterType,
      isGridView: _isGridView,
      onViewModeChange: _setViewMode,
      isUploading: _uploadCoordinator.isUploading,
    );
  }

  Widget _buildBottomBar() {
    return FolderDetailBottomBar(
      selectedCount: _selectionController.selectedCount,
      selectedTotalSizeMB: _selectionController.getSelectedTotalSize(_fileItems),
      selectedImageCount: _selectionController.getSelectedImageCount(_fileItems),
      selectedVideoCount: _selectionController.getSelectedVideoCount(_fileItems),
      deviceStorageUsedPercent: _getDeviceStorageUsed(),
      isUploading: _uploadCoordinator.isUploading,
      uploadProgress: _uploadCoordinator.uploadProgress,
      onSyncPressed: _handleSync,
    );
  }

  Widget _buildPreviewPanel() {
    final item = _previewController.getCurrentPreviewItem();
    if (item == null) return Container();

    return PreviewPanel(
      item: item,
      currentIndex: _previewController.previewIndex,
      totalCount: _previewController.mediaItems.length,
      isPlaying: _previewController.isPlaying,
      videoController: _previewController.videoController,
      onClose: _closePreview,
      onPrevious: _previousMedia,
      onNext: _nextMedia,
      onTogglePlayPause: () {
        _previewController.togglePlayPause();
      },
      canGoPrevious: _previewController.previewIndex > 0,
      canGoNext: _previewController.previewIndex < _previewController.mediaItems.length - 1,
    );
  }

  Widget _buildFileGrid() {
    final filteredFiles = _selectionController.getFilteredFiles(_fileItems);

    if (filteredFiles.isEmpty) {
      return const Center(
        child: Text(
          '此文件夹为空',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return _isGridView
        ? _buildGridView(filteredFiles)
        : _buildListView(filteredFiles);
  }

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
            itemBuilder: (context, index) {
              final actualIndex = _fileItems.indexOf(filteredFiles[index]);
              return GestureDetector(
                // ✅ 移除 isUploading 检查,允许上传时继续操作
                onDoubleTap: () {
                  if (filteredFiles[index].type == FileItemType.folder) {
                    _navigateToFolder(
                      filteredFiles[index].path,
                      filteredFiles[index].name,
                    );
                  } else {
                    _openFullScreenViewer(actualIndex);
                  }
                },
                child: FileItemCard(
                  item: filteredFiles[index],
                  isSelected: _selectionController.selectedIndices.contains(actualIndex),
                  showCheckbox: _selectionController.isSelectionMode ||
                      _selectionController.selectedIndices.contains(actualIndex),
                  canSelect: true,
                  // ✅ 移除 isUploading 检查,允许上传时选择文件
                  onTap: () {
                    if (_selectionController.isSelectionMode) {
                      _toggleSelection(actualIndex);
                    } else if (filteredFiles[index].type == FileItemType.folder) {
                      _navigateToFolder(
                        filteredFiles[index].path,
                        filteredFiles[index].name,
                      );
                    } else {
                      _openPreview(actualIndex);
                    }
                  },
                  // ✅ 移除 isUploading 检查
                  onLongPress: () => _toggleSelection(actualIndex),
                  // ✅ 移除 isUploading 检查
                  onCheckboxToggle: () => _toggleSelection(actualIndex),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildListView(List<FileItem> filteredFiles) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      itemCount: filteredFiles.length,
      itemBuilder: (context, index) {
        final actualIndex = _fileItems.indexOf(filteredFiles[index]);
        return GestureDetector(
          // ✅ 移除 isUploading 检查,允许上传时继续操作
          onDoubleTap: () {
            if (filteredFiles[index].type == FileItemType.folder) {
              _navigateToFolder(
                filteredFiles[index].path,
                filteredFiles[index].name,
              );
            }
          },
          child: FileListItem(
            item: filteredFiles[index],
            isSelected: _selectionController.selectedIndices.contains(actualIndex),
            canSelect: _selectionController.isSelectionMode ||
                _selectionController.selectedIndices.contains(actualIndex),
            // ✅ 移除 isUploading 检查,允许上传时选择文件
            onTap: () {
              if (_selectionController.isSelectionMode) {
                _toggleSelection(actualIndex);
              } else if (filteredFiles[index].type == FileItemType.folder) {
                _navigateToFolder(
                  filteredFiles[index].path,
                  filteredFiles[index].name,
                );
              } else {
                _openPreview(actualIndex);
              }
            },
            // ✅ 移除 isUploading 检查
            onCheckboxToggle: () => _toggleSelection(actualIndex),
          ),
        );
      },
    );
  }

}

// 静态导航组件（向后兼容）
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
