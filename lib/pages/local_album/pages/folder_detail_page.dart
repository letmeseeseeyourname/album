// pages/folder_detail_page.dart
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
import '../services/media_cache_service.dart';
import '../../../services/thumbnail_helper.dart';
import '../../../widgets/custom_title_bar.dart';
import '../widgets/folder_detail_bottom_bar.dart';
import '../widgets/folder_detail_top_bar.dart';
import '../widgets/views/file_view_factory.dart';
import '../widgets/views/equal_height_gallery.dart';
import '../widgets/views/grid_view.dart';
import '../widgets/views/list_view.dart';
import '../../../widgets/media_viewer_page.dart';
import '../widgets/preview_panel.dart';
import '../../../widgets/side_navigation.dart';

/// 文件夹详情页面
///
/// 优化版本：
/// - 使用 FileViewFactory 统一管理视图
/// - 使用 MediaCacheService 统一管理缓存
/// - 组件化和模块化设计
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

class _FolderDetailPageState extends State<FolderDetailPage> {
  // 服务
  final ThumbnailHelper _thumbnailHelper = ThumbnailHelper();
  final FileService _fileService = FileService();
  final MediaCacheService _cacheService = MediaCacheService.instance;

  // 控制器
  late final PathNavigationController _pathController;
  late final SelectionController _selectionController;
  late final PreviewController _previewController;
  late final UploadCoordinator _uploadCoordinator;

  // 状态
  List<FileItem> _fileItems = [];
  bool _isLoading = true;
  ViewMode _viewMode = ViewMode.grid;

  @override
  void initState() {
    super.initState();
    _registerViewBuilders();
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
      _previewController.closePreview();
    });

    try {
      final items = await _fileService.loadFiles(path);

      // 预加载媒体缓存
      _cacheService.preloadBatch(items);

      if (mounted) {
        setState(() {
          _fileItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// ✅ 刷新当前文件列表（用于上传成功后更新状态）
  Future<void> _refreshFiles() async {
    try {
      final items = await _fileService.loadFiles(_pathController.currentPath);

      // 预加载媒体缓存
      _cacheService.preloadBatch(items);

      if (mounted) {
        setState(() {
          _fileItems = items;
        });
      }
    } catch (e) {
      // 刷新失败时静默处理
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
  }

  void _toggleSelectAll() {
    setState(() => _selectionController.toggleSelectAll(_fileItems.length));
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

  // ============ 预览相关 ============

  void _openPreview(int index) {
    setState(() => _previewController.openPreview(index, _fileItems));
    _loadPreviewMedia();
  }

  void _closePreview() {
    setState(() => _previewController.closePreview());
  }

  void _loadPreviewMedia() {
    final item = _previewController.getCurrentPreviewItem();
    if (item != null && item.type == FileItemType.video) {
      _previewController.initVideoPlayer(item.path, (playing) {
        if (mounted) setState(() {});
      });
    } else {
      _previewController.disposeVideoPlayer();
    }
  }

  void _previousMedia() {
    setState(() => _previewController.previousMedia());
    _loadPreviewMedia();
  }

  void _nextMedia() {
    setState(() => _previewController.nextMedia());
    _loadPreviewMedia();
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
    if (mounted) setState(() {});
  }

  Future<void> _handleSync() async {
    if (_selectionController.selectedCount == 0) {
      _showMessage('请先选择要上传的文件或文件夹', isError: true);
      return;
    }

    final selectedItems = _selectionController.getSelectedItems(_fileItems);
    final hasFolder = selectedItems.any((item) => item.type == FileItemType.folder);
    if (hasFolder) {
      _showMessage('正在扫描选中的文件夹，请稍候...', isError: false);
    }

    final prepareResult = await _uploadCoordinator.prepareUpload(selectedItems);

    if (!prepareResult.success) {
      _showMessage(prepareResult.message!, isError: true);
      return;
    }

    final confirmed = await _showConfirmDialog(
      prepareResult.filePaths!,
      prepareResult.imageCount!,
      prepareResult.videoCount!,
      prepareResult.totalSizeMB!,
    );

    if (!confirmed) return;

    setState(() => _selectionController.cancelSelection());

    await _uploadCoordinator.startUpload(
      prepareResult.filePaths!,
          (String message, {bool isError = false}) => _showMessage(message, isError: isError),
          () {
        if (mounted) {
          setState(() {});
          // ✅ 上传完成后刷新文件列表，更新上传状态图标
          _refreshFiles();
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
    ) ?? false;
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

  double _getDeviceStorageUsed() {
    double used = MyInstance().p6deviceInfoModel?.ttlUsed ?? 0;
    double scaled = used * 100.0;
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
                          Expanded(child: _buildContent()),
                          _buildBottomBar(),
                        ],
                      ),
                    ),
                  ),

                  // 预览区域
                  if (_previewController.showPreview)
                    Expanded(flex: 2, child: _buildPreviewPanel()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final isSelectAllChecked = _selectionController.selectedCount == _fileItems.length &&
        _selectionController.selectedCount > 0;

    return FolderDetailTopBar(
      pathSegments: _pathController.pathSegments,
      onPathSegmentTap: _navigateToPathSegment,
      isSelectAllChecked: isSelectAllChecked,
      onSelectAllToggle: _toggleSelectAll,
      filterType: _selectionController.filterType,
      onFilterChange: _setFilterType,
      viewMode: _viewMode,
      onViewModeChange: _setViewMode,
      isUploading: _uploadCoordinator.isUploading,
      selectedCount: _selectionController.selectedCount,
      onCancelSelection: _cancelSelection,
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
      onTogglePlayPause: _previewController.togglePlayPause,
      canGoPrevious: _previewController.previewIndex > 0,
      canGoNext: _previewController.previewIndex < _previewController.mediaItems.length - 1,
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