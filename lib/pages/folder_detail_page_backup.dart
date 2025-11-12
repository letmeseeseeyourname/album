// pages/folder_detail_page.dart
// 重构版本 - 保持所有原有功能，改善代码结构

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// 导入相关模块
import '../album/manager/local_folder_upload_manager.dart';
import '../models/file_item.dart';
import '../models/folder_info.dart';
import '../models/media_item.dart';
import '../services/thumbnail_helper.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/file_item_card.dart';
import '../widgets/file_list_item.dart';
import '../widgets/media_viewer_page.dart';
import '../widgets/side_navigation.dart';

// 导入拆分的组件和服务
part 'folder_detail/analysis_models.dart';
part 'folder_detail/file_service.dart';
part 'folder_detail/folder_detail_state.dart';
part 'folder_detail/ui_components.dart';

/// 文件夹详情页面主组件
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

class _FolderDetailPageState extends State<FolderDetailPage>
    with _FolderDetailStateMixin, _MediaPreviewMixin, _UploadMixin {

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  @override
  void dispose() {
    _disposeResources();
    _disposeVideoPlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 主体内容
          _buildMainContent(),

          // 自定义标题栏（覆盖在最上层）
          const CustomTitleBar(),
        ],
      ),
    );
  }

  /// 构建主体内容区域
  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Row(
        children: [
          // 侧边导航栏
          widget.onNavigationChanged != null
              ? SideNavigation(
            selectedIndex: widget.selectedNavIndex,
            onNavigationChanged: widget.onNavigationChanged!,
          )
              : const _StaticSideNavigation(),

          // 主内容区域
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              margin: EdgeInsets.only(right: showPreview ? 320 : 0),
              child: _buildFileExplorer(),
            ),
          ),

          // 预览面板
          _PreviewPanel(
            showPreview: showPreview,
            previewIndex: previewIndex,
            mediaItems: mediaItems,
            fileItems: fileItems,
            isPlaying: isPlaying,
            videoPlayer: videoPlayer,
            videoController: videoController,
            onClose: _closePreview,
            onOpenFullScreen: _openFullScreenViewer,
            onTogglePlay: _toggleVideoPlay,
            onVideoSliderChanged: _onVideoSliderChanged,
            onVideoSliderChangeEnd: _onVideoSliderChangeEnd,
          ),
        ],
      ),
    );
  }

  /// 构建文件浏览器区域
  Widget _buildFileExplorer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // 文件夹头部
          _FolderHeader(
            pathSegments: pathSegments,
            currentPath: currentPath,
            selectedCount: selectedIndices.length,
            isSelectionMode: isSelectionMode,
            isGridView: isGridView,
            filterType: filterType,
            isFilterMenuOpen: isFilterMenuOpen,
            onNavigateToPath: _navigateToPath,
            onToggleSelectAll: _toggleSelectAll,
            onClearSelection: _clearSelection,
            onToggleView: _toggleView,
            onFilterChanged: _onFilterChanged,
            onToggleFilterMenu: () => setState(() => isFilterMenuOpen = !isFilterMenuOpen),
          ),

          // 文件列表内容
          Expanded(
            child: isLoading
                ? const _LoadingIndicator()
                : _FileListContent(
              fileItems: _getFilteredFiles(),
              isGridView: isGridView,
              selectedIndices: selectedIndices,
              isSelectionMode: isSelectionMode,
              isUploading: isUploading,
              onItemTap: _onFileItemTap,
              onItemDoubleTap: _onFileItemDoubleTap,
              onItemLongPress: _toggleSelection,
              onCheckboxToggle: _toggleSelection,
            ),
          ),

          // 底部操作栏
          _BottomActionBar(
            selectedIndices: selectedIndices,
            isUploading: isUploading,
            uploadProgress: uploadProgress,
            onSync: _handleSync,
            getSelectedStats: _getSelectedStats,
            getDeviceStorage: _getDeviceStorageUsed,
          ),
        ],
      ),
    );
  }
}

/// State 混入 - 管理组件状态和初始化
mixin _FolderDetailStateMixin<T extends StatefulWidget> on State<T> {
  // 服务实例
  final ThumbnailHelper _helper = ThumbnailHelper();
  final LocalFolderUploadManager _uploadManager = LocalFolderUploadManager();

  // 文件浏览状态
  List<FileItem> fileItems = [];
  List<String> pathSegments = [];
  List<String> pathHistory = [];
  String currentPath = '';
  bool isLoading = true;

  // 选择状态
  Set<int> selectedIndices = {};
  bool isSelectionMode = false;

  // 视图和过滤状态
  String filterType = 'all';
  bool isFilterMenuOpen = false;
  bool isGridView = true;

  // 上传状态
  bool isUploading = false;
  LocalUploadProgress? uploadProgress;

  // 预览状态（给_MediaPreviewMixin使用）
  bool showPreview = false;
  int previewIndex = -1;
  List<FileItem> mediaItems = [];
  Player? videoPlayer;
  VideoController? videoController;
  bool isPlaying = false;

  void _initializeState() {
    final folder = (widget as FolderDetailPage).folder;
    currentPath = folder.path;
    _initPathSegments();
    _initializeHelper();
    _loadFiles(currentPath);
    _uploadManager.addListener(_onUploadProgressChanged);
  }

  void _disposeResources() {
    _uploadManager.removeListener(_onUploadProgressChanged);
  }

  void _initPathSegments() {
    final folder = (widget as FolderDetailPage).folder;
    final parts = folder.path.split(Platform.pathSeparator);
    if (parts.isNotEmpty) {
      pathSegments = [parts[0], folder.name];
      pathHistory = [parts[0], folder.path];
    }
  }

  Future<void> _initializeHelper() async {
    try {
      await _helper.initializeHelper();
    } catch (e) {
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

  void _onUploadProgressChanged() {
    if (mounted) {
      setState(() {
        uploadProgress = _uploadManager.currentProgress;
        isUploading = _uploadManager.isUploading;
      });
    }
  }

  // 文件加载和导航方法
  Future<void> _loadFiles(String path) async {
    setState(() {
      isLoading = true;
      fileItems.clear();
      selectedIndices.clear();
      isSelectionMode = false;
      // 关闭预览
      showPreview = false;
      previewIndex = -1;
    });

    try {
      final items = await compute(FileService.loadFilesInBackground, path);

      if (mounted) {
        setState(() {
          fileItems = items;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载文件失败: $e')),
        );
      }
    }
  }

  void _navigateToFolder(String path, String name) {
    setState(() {
      currentPath = path;
      pathSegments.add(name);
      pathHistory.add(path);
    });
    _loadFiles(path);
  }

  void _navigateToPath(int index) {
    if (index < pathHistory.length - 1) {
      setState(() {
        currentPath = pathHistory[index];
        pathSegments = pathSegments.sublist(0, index + 1);
        pathHistory = pathHistory.sublist(0, index + 1);
      });
      _loadFiles(currentPath);
    }
  }

  // 选择操作方法
  void _toggleSelection(int index) {
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

  void _toggleSelectAll() {
    setState(() {
      if (selectedIndices.length == fileItems.length) {
        selectedIndices.clear();
        isSelectionMode = false;
      } else {
        selectedIndices = Set.from(List.generate(fileItems.length, (i) => i));
        isSelectionMode = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      selectedIndices.clear();
      isSelectionMode = false;
    });
  }

  // 视图和过滤方法
  void _toggleView() {
    setState(() => isGridView = !isGridView);
  }

  void _onFilterChanged(String type) {
    setState(() {
      filterType = type;
      isFilterMenuOpen = false;
    });
  }

  List<FileItem> _getFilteredFiles() {
    switch (filterType) {
      case 'image':
        return fileItems.where((item) => item.type == FileItemType.image).toList();
      case 'video':
        return fileItems.where((item) => item.type == FileItemType.video).toList();
      default:
        return fileItems;
    }
  }

  // 文件操作回调
  void _onFileItemTap(int index) {
    final state = this as _FolderDetailPageState;
    if (isSelectionMode) {
      _toggleSelection(index);
    } else if (fileItems[index].type == FileItemType.folder) {
      _navigateToFolder(fileItems[index].path, fileItems[index].name);
    } else {
      state._openPreview(index);
    }
  }

  void _onFileItemDoubleTap(int index) {
    final state = this as _FolderDetailPageState;
    if (fileItems[index].type == FileItemType.folder) {
      _navigateToFolder(fileItems[index].path, fileItems[index].name);
    } else {
      state._openFullScreenViewer(index);
    }
  }

  // 获取统计信息
  Map<String, dynamic> _getSelectedStats() {
    double totalSize = 0;
    int imageCount = 0;
    int videoCount = 0;

    for (int index in selectedIndices) {
      if (index < fileItems.length) {
        final item = fileItems[index];
        totalSize += item.size / (1024 * 1024);
        if (item.type == FileItemType.image) imageCount++;
        if (item.type == FileItemType.video) videoCount++;
      }
    }

    return {
      'totalSize': totalSize,
      'imageCount': imageCount,
      'videoCount': videoCount,
    };
  }

  String _getDeviceStorageUsed() {
    return '100.4/498.5';
  }
}

/// 媒体预览混入
mixin _MediaPreviewMixin<T extends StatefulWidget> on State<T> {

  void _openPreview(int index) {
    final state = this as _FolderDetailStateMixin;
    final items = state.fileItems;
    if (index >= 0 && index < items.length) {
      final item = items[index];
      if (item.type != FileItemType.folder) {
        setState(() {
          state.showPreview = true;
          state.previewIndex = index;
          state.mediaItems = items.where((i) => i.type != FileItemType.folder).toList();
        });

        if (item.type == FileItemType.video) {
          _initVideoPlayer(item.path);
        }
      }
    }
  }

  void _closePreview() {
    final state = this as _FolderDetailStateMixin;
    setState(() {
      state.showPreview = false;
      state.previewIndex = -1;
    });
    _disposeVideoPlayer();
  }

  void _openFullScreenViewer(int index) {
    final state = this as _FolderDetailStateMixin;
    final items = state.fileItems;
    final mediaFiles = items
        .where((item) => item.type != FileItemType.folder)
        .map((item) => MediaItem.fromFileItem(item))
        .toList();

    if (mediaFiles.isNotEmpty) {
      _disposeVideoPlayer();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MediaViewerPage(
            mediaItems: mediaFiles,
            initialIndex: mediaFiles.indexWhere(
                  (m) => m.localPath == items[index].path,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _initVideoPlayer(String path) async {
    final state = this as _FolderDetailStateMixin;
    await _disposeVideoPlayer();

    state.videoPlayer = Player();
    state.videoController = VideoController(state.videoPlayer!);

    await state.videoPlayer!.open(Media(path));
    await state.videoPlayer!.play();

    setState(() => state.isPlaying = true);
  }

  Future<void> _disposeVideoPlayer() async {
    final state = this as _FolderDetailStateMixin;
    if (state.videoPlayer != null) {
      await state.videoPlayer!.dispose();
      state.videoPlayer = null;
      state.videoController = null;
      setState(() => state.isPlaying = false);
    }
  }

  void _toggleVideoPlay() async {
    final state = this as _FolderDetailStateMixin;
    if (state.videoPlayer != null) {
      if (state.isPlaying) {
        await state.videoPlayer!.pause();
      } else {
        await state.videoPlayer!.play();
      }
      setState(() => state.isPlaying = !state.isPlaying);
    }
  }

  void _onVideoSliderChanged(double value) {
    // 实现视频进度调整
  }

  void _onVideoSliderChangeEnd(double value) {
    final state = this as _FolderDetailStateMixin;
    if (state.videoPlayer != null) {
      state.videoPlayer!.seek(Duration(seconds: value.toInt()));
    }
  }
}

/// 上传功能混入
mixin _UploadMixin<T extends StatefulWidget> on State<T> {
  Future<void> _handleSync() async {
    final state = this as _FolderDetailStateMixin;

    if (state.selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择要上传的文件或文件夹')),
      );
      return;
    }

    if (state.isUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已有上传任务在进行中')),
      );
      return;
    }

    // 获取所有选中的项目
    final selectedItems = state.selectedIndices
        .map((index) => state.fileItems[index])
        .toList();

    // 分离文件和文件夹
    final selectedFiles = selectedItems.where((item) => item.type != FileItemType.folder).toList();
    final selectedFolders = selectedItems.where((item) => item.type == FileItemType.folder).toList();

    // 构建最终待上传文件列表
    final List<String> allFilesToUpload = [];

    // 添加单独选中的文件路径
    allFilesToUpload.addAll(selectedFiles.map((item) => item.path));

    // 递归处理选中的文件夹
    if (selectedFolders.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在扫描选中的文件夹，请稍候...')),
      );

      for (final folder in selectedFolders) {
        // 在后台线程递归获取所有媒体文件路径
        final filesInFolder = await compute(
            FileService.getAllMediaFilesRecursive,
            folder.path
        );
        allFilesToUpload.addAll(filesInFolder);
      }
    }

    // 移除重复路径
    final finalUploadList = allFilesToUpload.toSet().toList();

    // 检查是否有文件需要上传
    if (finalUploadList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可上传的媒体文件')),
      );
      return;
    }

    // 显示确认对话框
    final confirmed = await _showUploadConfirmDialog(finalUploadList);

    if (confirmed == true) {
      await _startUploadFiles(finalUploadList);
    }
  }

  Future<bool?> _showUploadConfirmDialog(List<String> filePaths) async {
    // 分析文件统计
    final analysis = await compute(
        FileService.analyzeFilesForUpload,
        filePaths
    );

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认上传'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('即将上传 ${filePaths.length} 个文件：'),
            const SizedBox(height: 8),
            Text('• ${analysis.imageCount} 张照片'),
            Text('• ${analysis.videoCount} 个视频'),
            Text('• 总大小：${analysis.formattedSize}'),
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
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C2C2C),
            ),
            child: const Text('开始上传'),
          ),
        ],
      ),
    );
  }

  Future<void> _startUploadFiles(List<String> filePaths) async {
    final state = this as _FolderDetailStateMixin;

    setState(() {
      state.isUploading = true;
    });

    await state._uploadManager.uploadLocalFiles(
      filePaths,
      onProgress: (progress) {
        // 进度在 listener 中自动更新
      },
      onComplete: (success, message) {
        if (mounted) {
          setState(() {
            state.isUploading = false;
            state.uploadProgress = null;
            if (success) {
              // 清空选择
              state.selectedIndices.clear();
              state.isSelectionMode = false;
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message ?? (success ? '上传完成' : '上传失败')),
              backgroundColor: success ? Colors.green : Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
    );
  }
}

/// 静态侧边导航组件
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