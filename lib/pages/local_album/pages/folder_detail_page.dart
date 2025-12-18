// pages/folder_detail_page.dart (修改版 - 支持文件夹递归统计)
import 'package:ablumwin/user/my_instance.dart';
import 'package:flutter/material.dart';

import '../../../models/file_item.dart';
import '../../../models/folder_info.dart';
import '../../../models/media_item.dart';
import '../../../services/sync_status_service.dart';
import '../../../services/thumbnail_helper.dart';
import '../../../widgets/custom_title_bar.dart';
import '../../../widgets/media_viewer_page.dart';
import '../../../widgets/side_navigation.dart';
import '../../../widgets/upload_bottom_bar.dart';
import '../controllers/path_navigation_controller.dart';
import '../controllers/selection_controller.dart';
import '../controllers/upload_coordinator.dart';
import '../services/file_service.dart';
import '../services/media_cache_service.dart';
import '../widgets/folder_detail_top_bar.dart';
import '../widgets/preview_panel.dart';
import '../widgets/views/equal_height_gallery.dart';
import '../widgets/views/file_view_factory.dart';
import '../widgets/views/grid_view.dart';
import '../widgets/views/list_view.dart';

/// 文件夹详情页面
///
/// 优化版本：
/// - 使用 FileViewFactory 统一管理视图
/// - 使用 MediaCacheService 统一管理缓存
/// - 组件化和模块化设计
/// - PreviewPanel 内部管理视频播放器
/// - ✅ 支持文件夹递归统计
class FolderDetailPage extends StatefulWidget {
  final FolderInfo folder;
  final int selectedNavIndex;
  final Function(int)? onNavigationChanged;

  const FolderDetailPage({
    super.key,
    required this.folder,
    this.selectedNavIndex = 0,
    this.onNavigationChanged,
  });

  @override
  State<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends State<FolderDetailPage> with UploadCoordinatorMixin {
  // 服务
  final ThumbnailHelper _thumbnailHelper = ThumbnailHelper();
  final FileService _fileService = FileService();
  final MediaCacheService _cacheService = MediaCacheService.instance;

  // 控制器
  late final PathNavigationController _pathController;
  late final SelectionController _selectionController;
  // late final UploadCoordinator _uploadCoordinator;

  // 状态
  List<FileItem> _fileItems = [];
  bool _isLoading = true;
  ViewMode _viewMode = ViewMode.grid;

  // 预览状态（简化版，不再需要 PreviewController）
  bool _showPreview = false;
  int _previewIndex = -1;
  List<FileItem> _mediaItems = []; // 只包含图片和视频的列表

  @override
  void initState() {
    super.initState();
    _registerViewBuilders();
    _initializeControllers();
    _initializeHelper();
    _initializeSyncService();  // 新增
    _loadFiles(_pathController.currentPath);
  }

  /// ✅ 初始化同步状态服务
  Future<void> _initializeSyncService() async {
    await SyncStatusService.instance.initialize();
  }

  /// ✅ 上传完成后刷新同步状态缓存
  Future<void> _onUploadComplete(List<String> uploadedMd5s) async {
    // 添加到缓存，避免重新拉取
    SyncStatusService.instance.addSyncedResIds(uploadedMd5s);
    // 刷新文件列表
    await _refreshFiles();
  }

  @override
  void dispose() {
    // _uploadCoordinator.removeListener(_onUploadProgressChanged);
    super.dispose();
  }

  /// 注册视图构建器
  void _registerViewBuilders() {
    FileViewFactory.register(ViewMode.equalHeight, const EqualHeightViewBuilder());
    FileViewFactory.register(ViewMode.grid, const GridViewBuilder());
    FileViewFactory.register(ViewMode.list, const ListViewBuilder());
  }

  /// 初始化控制器
  void _initializeControllers() {
    _pathController = PathNavigationController();
    _pathController.initializePath(widget.folder.path, widget.folder.name);

    _selectionController = SelectionController();

    // _uploadCoordinator = UploadCoordinator(
    //   LocalFolderUploadManager(),
    //   _fileService,
    // );
    // _uploadCoordinator.addListener(_onUploadProgressChanged);
  }

  /// 初始化缩略图辅助工具
  Future<void> _initializeHelper() async {
    try {
      await _thumbnailHelper.initializeHelper();
    } catch (e) {
      if (mounted) {
        _showMessage('缩略图功能不可用', isError: true);
      }
    }
  }

  // ============ 数据加载 ============

  Future<void> _loadFiles(String path) async {
    setState(() {
      _isLoading = true;
      _fileItems.clear();
      _selectionController.reset();
      _closePreview();
    });

    try {
      final items = await _fileService.loadFiles(path);

      // 预加载媒体缓存
      _cacheService.preloadBatch(items);

      if (mounted) {
        setState(() {
          _fileItems = items;
          _isLoading = false;
          // 更新媒体列表
          _updateMediaItems();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 更新媒体项列表（只包含图片和视频）
  void _updateMediaItems() {
    _mediaItems = _fileItems
        .where((item) => item.type == FileItemType.image || item.type == FileItemType.video)
        .toList();
  }

  /// 刷新当前文件列表
  Future<void> _refreshFiles() async {
    try {
      final items = await _fileService.loadFiles(_pathController.currentPath);

      // 预加载媒体缓存
      _cacheService.preloadBatch(items);

      if (mounted) {
        setState(() {
          _fileItems = items;
          _updateMediaItems();
        });
      }
    } catch (e) {
      debugPrint('Refresh files failed: $e');
    }
  }

  // ============ 导航相关 ============

  void _navigateToFolder(String folderPath, String folderName) {
    _pathController.navigateToFolder(folderPath, folderName);
    _loadFiles(folderPath);
  }

  void _navigateToPathSegment(int index) {
    final result = _pathController.navigateToSegment(index);
    if (result.shouldPopPage) {
      Navigator.pop(context);
    } else if (result.newPath != null) {
      _loadFiles(result.newPath!);
    }
  }

  void _handleNavigationChanged(int index) {
    if (index != widget.selectedNavIndex) {
      Navigator.pop(context);
      widget.onNavigationChanged?.call(index);
    }
  }

  // ============ 选择相关 ============

  void _toggleSelection(int index) {
    setState(() => _selectionController.toggleSelection(index));
    // ✅ 选择改变时，触发异步统计
    _updateSelectedStats();
  }

  void _toggleSelectAll() {
    setState(() => _selectionController.toggleSelectAll(_fileItems.length));
    // ✅ 选择改变时，触发异步统计
    _updateSelectedStats();
  }

  void _cancelSelection() {
    setState(() => _selectionController.cancelSelection());
  }

  void _setFilterType(String type) {
    setState(() => _selectionController.setFilterType(type));
  }

  void _setViewMode(ViewMode mode) {
    setState(() {
      _viewMode = mode;
      _selectionController.cancelSelection();
    });
  }

  /// ✅ 新增：异步更新选中项统计
  Future<void> _updateSelectedStats() async {
    if (_selectionController.selectedIndices.isEmpty) {
      return;
    }

    // 获取筛选后的文件列表
    final filteredFiles = _selectionController.getFilteredFiles(_fileItems);

    // 检查是否有选中文件夹，如果有则需要递归统计
    final hasFolder = _selectionController.hasSelectedFolders(filteredFiles);

    if (hasFolder) {
      // 有文件夹，需要异步递归统计
      await _selectionController.updateSelectedStats(
        filteredFiles,
        onUpdate: () {
          if (mounted) {
            setState(() {});
          }
        },
      );
    }
  }

  // ============ 预览相关（简化版）============

  void _openPreview(int index) {
    final item = _fileItems[index];
    // 只预览图片和视频
    if (item.type != FileItemType.image && item.type != FileItemType.video) {
      return;
    }

    // 找到在媒体列表中的索引
    final mediaIndex = _mediaItems.indexOf(item);
    if (mediaIndex >= 0) {
      setState(() {
        _showPreview = true;
        _previewIndex = mediaIndex;
      });
    }
  }

  void _closePreview() {
    setState(() {
      _showPreview = false;
      _previewIndex = -1;
    });
  }

  void _previousMedia() {
    if (_previewIndex > 0) {
      setState(() {
        _previewIndex--;
      });
    }
  }

  void _nextMedia() {
    if (_previewIndex < _mediaItems.length - 1) {
      setState(() {
        _previewIndex++;
      });
    }
  }

  void _openFullScreenViewer(int index) {
    final mediaItems = _fileItems
        .where((item) => item.type == FileItemType.image || item.type == FileItemType.video)
        .map((fileItem) => MediaItem.fromFileItem(fileItem))
        .toList();

    final currentItem = _fileItems[index];
    final mediaFileItems = _fileItems
        .where((item) => item.type == FileItemType.image || item.type == FileItemType.video)
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

  void _onUploadProgressChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleSync() async {
    // 检查是否有选中的文件
    final selectedItems = _selectionController.selectedIndices
        .map((index) => _fileItems[index])
        .toList();

    if (selectedItems.isEmpty) {
      _showMessage('请先选择要上传的图片或视频', isError: true);
      return;
    }

    // 准备上传 - 新API只需传入选中的项目列表
    final prepareResult = await uploadCoordinator.prepareUpload(selectedItems);

    if (!prepareResult.success) {
      _showMessage(prepareResult.message ?? '准备上传失败', isError: true);
      return;
    }

    if (prepareResult.filePaths == null || prepareResult.filePaths!.isEmpty) {
      return;
    }

    // 显示确认对话框
    final confirmed = await _showConfirmDialog(
      prepareResult.filePaths!,
      prepareResult.imageCount ?? 0,
      prepareResult.videoCount ?? 0,
      prepareResult.totalSizeMB ?? 0,
    );

    if (!confirmed) return;

    await uploadCoordinator.startUpload(
      prepareResult.filePaths!,
          (String message, {bool isError = false}) => _showMessage(message, isError: isError),
          (List<String> uploadedMd5s) {
        if (mounted) {
          setState(() {});
          _onUploadComplete(uploadedMd5s);
        }
      },
    );
  }

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
              style: TextStyle(color: Colors.orange, fontSize: 12),
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

  double _getDeviceStorageSurplus() {
    double used = MyInstance().p6deviceInfoModel?.ttlUsed ?? 0;
    double all = MyInstance().p6deviceInfoModel?.ttlAll ?? 0;
    double surplus = all - used;
    double scaled = surplus * 100.0;
    int usedPercent = scaled.round();
    return usedPercent / 100.0;
  }

  /// 创建文件项目回调
  FileItemCallbacks _createCallbacks() {
    return FileItemCallbacks(
      onTap: _handleItemTap,
      onDoubleTap: _handleItemDoubleTap,
      onLongPress: _toggleSelection,
      onCheckboxToggle: _toggleSelection,
    );
  }

  void _handleItemTap(int index) {
    final item = _fileItems[index];
    if (_selectionController.isSelectionMode) {
      _toggleSelection(index);
    } else if (item.type == FileItemType.folder) {
      _navigateToFolder(item.path, item.name);
    } else {
      _openPreview(index);
    }
  }

  void _handleItemDoubleTap(int index) {
    final item = _fileItems[index];
    if (item.type == FileItemType.folder) {
      _navigateToFolder(item.path, item.name);
    } else {
      _openFullScreenViewer(index);
    }
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

            // 主内容区域 - 使用 Flex 布局
            Expanded(
              child: Row(
                children: [
                  // 文件列表区域
                  Expanded(
                    flex: _showPreview ? 3 : 1,
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          _buildTopBar(),
                          Expanded(child: _buildContent()),
                          _buildBottomBar(),
                        ],
                      ),
                    ),
                  ),

                  // 预览区域
                  if (_showPreview) Expanded(flex: 2, child: _buildPreviewPanel()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final isSelectAllChecked =
        _selectionController.selectedCount == _fileItems.length && _selectionController.selectedCount > 0;

    return FolderDetailTopBar(
      pathSegments: _pathController.pathSegments,
      onPathSegmentTap: _navigateToPathSegment,
      isSelectAllChecked: isSelectAllChecked,
      onSelectAllToggle: _toggleSelectAll,
      filterType: _selectionController.filterType,
      onFilterChange: _setFilterType,
      viewMode: _viewMode,
      onViewModeChange: _setViewMode,
      isUploading: uploadCoordinator.isUploading,
      selectedCount: _selectionController.selectedCount,
      onCancelSelection: _cancelSelection,
    );
  }

  Widget _buildBottomBar() {
    // 获取筛选后的文件列表
    final filteredFiles = _selectionController.getFilteredFiles(_fileItems);

    // ✅ 检查是否有选中文件夹，决定使用哪种统计方式
    final hasFolder = _selectionController.hasSelectedFolders(filteredFiles);

    // 如果有文件夹且正在统计或已有缓存数据，使用缓存的统计结果
    final int imageCount;
    final int videoCount;
    final double totalSizeMB;

    if (hasFolder) {
      // 使用缓存的递归统计结果
      imageCount = _selectionController.cachedImageCount;
      videoCount = _selectionController.cachedVideoCount;
      totalSizeMB = _selectionController.cachedTotalSizeMB;
    } else {
      // 没有文件夹，使用原来的直接统计方式
      imageCount = _selectionController.getSelectedImageCount(filteredFiles);
      videoCount = _selectionController.getSelectedVideoCount(filteredFiles);
      totalSizeMB = _selectionController.getSelectedTotalSize(filteredFiles);
    }

    return UploadBottomBar(
      selectedCount: _selectionController.selectedCount,
      selectedTotalSizeMB: totalSizeMB,
      selectedImageCount: imageCount,
      selectedVideoCount: videoCount,
      deviceStorageSurplusGB: _getDeviceStorageSurplus(),
      isUploading: isUploading,           // ✅ 来自 Mixin
      uploadProgress: uploadProgress,      // ✅ 来自 Mixin
      onUploadPressed: _handleSync,
      isCountingFiles: _selectionController.isCountingFiles,
    );
  }

  Widget _buildPreviewPanel() {
    if (_previewIndex < 0 || _previewIndex >= _mediaItems.length) {
      return Container(color: Colors.white);
    }

    final item = _mediaItems[_previewIndex];

    return PreviewPanel(
      item: item,
      currentIndex: _previewIndex,
      totalCount: _mediaItems.length,
      onClose: _closePreview,
      onPrevious: _previousMedia,
      onNext: _nextMedia,
      canGoPrevious: _previewIndex > 0,
      canGoNext: _previewIndex < _mediaItems.length - 1,
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredFiles = _selectionController.getFilteredFiles(_fileItems);

    if (filteredFiles.isEmpty) {
      return const EmptyStateWidget();
    }

    // 使用工厂模式构建视图
    final config = FileViewConfig(
      items: filteredFiles,
      selectedIndices: _selectionController.selectedIndices,
      isSelectionMode: _selectionController.isSelectionMode,
      callbacks: _createCallbacks(),
    );

    return FileViewFactory.build(context, _viewMode, config);
  }
}

/// 静态导航组件
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
          _buildNavButton(Icons.cloud, '亲选相册', false),
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
        leading: Icon(icon, color: isSelected ? Colors.white : Colors.black),
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