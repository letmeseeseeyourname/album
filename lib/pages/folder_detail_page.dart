// pages/folder_detail_page_backup.dart
import 'dart:io';
import 'package:ablumwin/user/my_instance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../album/manager/local_folder_upload_manager.dart';
import '../models/file_item.dart';
import '../models/folder_info.dart';
import '../services/thumbnail_helper.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/file_item_card.dart';
import '../widgets/file_list_item.dart';
import '../widgets/side_navigation.dart';
import '../models/media_item.dart';
import '../widgets/media_viewer_page.dart';
// MARK: - 辅助模型和静态方法 (用于在后台隔离区运行)

// 用于返回上传分析结果的模型
class UploadAnalysisResult {
  final int imageCount;
  final int videoCount;
  final int totalBytes;

  UploadAnalysisResult(this.imageCount, this.videoCount, this.totalBytes);
}

// 递归获取所有媒体文件路径
Future<List<String>> _getAllMediaFilesRecursive(String path) async {
  final mediaPaths = <String>[];
  final directory = Directory(path);
  if (!await directory.exists()) return mediaPaths;

  // 预定义媒体文件扩展名
  const mediaExtensions = [
    'bmp', 'gif', 'jpg', 'jpeg', 'png', 'webp', 'wbmp', 'heic', // Images
    'mp4', 'mov', 'avi', '3gp', 'mkv', '3gp2' // Videos
  ];

  try {
    // 递归遍历
    await for (var entity in directory.list(recursive: true)) {
      if (entity is File) {
        final ext = entity.path.split('.').last.toLowerCase();
        if (mediaExtensions.contains(ext)) {
          mediaPaths.add(entity.path);
        }
      }
    }
  } catch (e) {
    // 打印错误，但不阻止其他文件的收集
    print('Error accessing directory $path: $e');
  }

  return mediaPaths;
}

// 分析最终上传文件列表的统计数据
Future<UploadAnalysisResult> _analyzeFilesForUpload(
    List<String> filePaths) async {
  int imageCount = 0;
  int videoCount = 0;
  int totalBytes = 0;

  const imageExtensions = ['bmp', 'gif', 'jpg', 'jpeg', 'png', 'webp', 'wbmp', 'heic'];
  const videoExtensions = ['mp4', 'mov', 'avi', '3gp', 'mkv', '3gp2'];

  for (final path in filePaths) {
    try {
      final file = File(path);
      // 异步获取文件状态，避免阻塞
      final stat = await file.stat();
      if (stat.type == FileSystemEntityType.file) {
        final ext = path.split('.').last.toLowerCase();

        if (imageExtensions.contains(ext)) {
          imageCount++;
          totalBytes += stat.size;
        } else if (videoExtensions.contains(ext)) {
          videoCount++;
          totalBytes += stat.size;
        }
      }
    } catch (e) {
      // 忽略无法访问的文件
    }
  }

  return UploadAnalysisResult(imageCount, videoCount, totalBytes);
}

// 文件加载方法 (与原代码一致)
Future<List<FileItem>> _loadFilesInBackground(String path) async {
  final directory = Directory(path);
  final entities = await directory.list().toList();

  final items = <FileItem>[];

  for (var entity in entities) {
    if (entity is Directory) {
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

      if (['bmp', 'gif', 'jpg', 'jpeg', 'png', 'webp', 'wbmp', 'heic'].contains(ext)) {
        type = FileItemType.image;
      } else if (['mp4', 'mov', 'avi', '3gp', 'mkv', '3gp2'].contains(ext)) {
        type = FileItemType.video;
      }

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

// MARK: - FolderDetailPage State

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
  final ThumbnailHelper _helper = ThumbnailHelper();
  final LocalFolderUploadManager _uploadManager = LocalFolderUploadManager();

  List<FileItem> fileItems = [];
  List<String> pathSegments = [];  // 显示用的文件夹名称列表
  List<String> pathHistory = [];   // 完整路径历史记录
  String currentPath = '';
  bool isLoading = true;

  Set<int> selectedIndices = {};
  bool isSelectionMode = false;

  String filterType = 'all';
  bool isFilterMenuOpen = false;
  bool isGridView = true;

  bool isUploading = false;
  LocalUploadProgress? uploadProgress;

  // 预览相关状态
  bool _showPreview = false;
  int _previewIndex = -1;
  List<FileItem> _mediaItems = [];

  // 视频播放器相关
  Player? _videoPlayer;
  VideoController? _videoController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    currentPath = widget.folder.path;
    _initPathSegments();
    _initializeHelper();
    _loadFiles(currentPath);

    _uploadManager.addListener(_onUploadProgressChanged);
  }

  @override
  void dispose() {
    _uploadManager.removeListener(_onUploadProgressChanged);
    _disposeVideoPlayer();
    super.dispose();
  }

  void _onUploadProgressChanged() {
    if (mounted) {
      setState(() {
        uploadProgress = _uploadManager.currentProgress;
        isUploading = _uploadManager.isUploading;
      });
    }
  }

  void _initPathSegments() {
    final parts = widget.folder.path.split(Platform.pathSeparator);
    if (parts.isNotEmpty) {
      pathSegments = [parts[0], widget.folder.name];
      pathHistory = [parts[0], widget.folder.path];
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

  Future<void> _loadFiles(String path) async {
    setState(() {
      isLoading = true;
      fileItems.clear();
      selectedIndices.clear();
      isSelectionMode = false;
      // 关闭预览
      _closePreview();
    });

    try {
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

  void _navigateToFolder(String folderPath, String folderName) {
    setState(() {
      currentPath = folderPath;
      pathSegments.add(folderName);
      pathHistory.add(folderPath);
    });
    _loadFiles(folderPath);
  }

  void _navigateToPathSegment(int index) {
    if (index == 0) {
      Navigator.pop(context);
      return;
    }

    final targetPath = pathHistory[index];
    final targetSegments = pathSegments.sublist(0, index + 1);
    final targetHistory = pathHistory.sublist(0, index + 1);

    setState(() {
      pathSegments = targetSegments;
      pathHistory = targetHistory;
      currentPath = targetPath;
    });
    _loadFiles(targetPath);
  }

  // 新增：打开预览
  void _openPreview(int index) {
    // 获取所有媒体文件（图片和视频）
    final mediaItems = fileItems.where((item) =>
    item.type == FileItemType.image || item.type == FileItemType.video
    ).toList();

    // 找到当前项在媒体列表中的位置
    final currentItem = fileItems[index];
    final mediaIndex = mediaItems.indexOf(currentItem);

    if (mediaIndex >= 0) {
      setState(() {
        _showPreview = true;
        _previewIndex = mediaIndex;
        _mediaItems = mediaItems;
      });
      _loadPreviewMedia();
    }
  }

  // 新增：关闭预览
  void _closePreview() {
    _disposeVideoPlayer();
    setState(() {
      _showPreview = false;
      _previewIndex = -1;
      _mediaItems = [];
    });
  }

  // 新增：加载预览媒体
  void _loadPreviewMedia() {
    if (_previewIndex < 0 || _previewIndex >= _mediaItems.length) return;

    final item = _mediaItems[_previewIndex];

    if (item.type == FileItemType.video) {
      _initVideoPlayer(item.path);
    } else {
      _disposeVideoPlayer();
    }
  }

  // 新增：初始化视频播放器
  void _initVideoPlayer(String path) {
    _disposeVideoPlayer();

    _videoPlayer = Player();
    _videoController = VideoController(_videoPlayer!);

    _videoPlayer!.open(Media('file:///$path'));
    _videoPlayer!.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });
  }

  // 新增：释放视频播放器
  void _disposeVideoPlayer() {
    _videoPlayer?.dispose();
    _videoPlayer = null;
    _videoController = null;
    _isPlaying = false;
  }

  // 新增：切换到上一个文件
  void _previousMedia() {
    if (_previewIndex > 0) {
      setState(() {
        _previewIndex--;
      });
      _loadPreviewMedia();
    }
  }

  // 新增：切换到下一个文件
  void _nextMedia() {
    if (_previewIndex < _mediaItems.length - 1) {
      setState(() {
        _previewIndex++;
      });
      _loadPreviewMedia();
    }
  }

  // 新增：切换播放/暂停
  void _togglePlayPause() {
    if (_videoPlayer != null) {
      _videoPlayer!.playOrPause();
    }
  }
  void _openFullScreenViewer(int index) {
    final mediaItems = fileItems
        .where((item) =>
    item.type == FileItemType.image ||
        item.type == FileItemType.video)
        .map((fileItem) => MediaItem.fromFileItem(fileItem))
        .toList();

    final currentItem = fileItems[index];
    final mediaFileItems = fileItems
        .where((item) =>
    item.type == FileItemType.image ||
        item.type == FileItemType.video)
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

  void _handleNavigationChanged(int index) {
    if (index != widget.selectedNavIndex) {
      Navigator.pop(context);
      widget.onNavigationChanged?.call(index);
    }
  }

  // MARK: - 修复并启用文件夹选中逻辑

  void _toggleSelection(int index) {
    // 允许选中文件夹
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
    // 允许全选所有项目（文件和文件夹）
    setState(() {
      if (selectedIndices.length == fileItems.length) {
        selectedIndices.clear();
        isSelectionMode = false;
      } else {
        selectedIndices.clear();
        for (int i = 0; i < fileItems.length; i++) {
          selectedIndices.add(i);
        }
        isSelectionMode = true;
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      selectedIndices.clear();
      isSelectionMode = false;
    });
  }

  int _getSelectableCount() {
    // 可选数量是所有项目的数量
    return fileItems.length;
  }

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

  // MARK: - 递归同步逻辑修改

  /// 执行同步上传
  Future<void> _handleSync() async {
    if (selectedIndices.isEmpty) {
      _showMessage('请先选择要上传的文件或文件夹', isError: true);
      return;
    }

    if (isUploading) {
      _showMessage('已有上传任务在进行中', isError: true);
      return;
    }

    // 1. 获取所有选中的项目
    final selectedItems = selectedIndices
        .map((index) => fileItems[index])
        .toList();

    // 2. 分离文件和文件夹
    final selectedFiles = selectedItems.where((item) => item.type != FileItemType.folder).toList();
    final selectedFolders = selectedItems.where((item) => item.type == FileItemType.folder).toList();

    // 3. 构建最终待上传文件列表
    final List<String> allFilesToUpload = [];

    // 添加单独选中的文件路径 (确保是媒体文件)
    allFilesToUpload.addAll(selectedFiles.map((item) => item.path));

    // 递归处理选中的文件夹
    if (selectedFolders.isNotEmpty) {
      _showMessage('正在扫描选中的文件夹，请稍候...', isError: false);
      for (final folder in selectedFolders) {
        // 在后台线程递归获取所有媒体文件路径
        final filesInFolder = await compute(_getAllMediaFilesRecursive, folder.path);
        allFilesToUpload.addAll(filesInFolder);
      }
    }

    // 移除重复路径，并转为列表
    final finalUploadList = allFilesToUpload.toSet().toList();

    // 检查是否有文件需要上传
    if (finalUploadList.isEmpty) {
      _showMessage('没有可上传的媒体文件', isError: true);
      return;
    }

    // 4. 显示确认对话框 (传递实际的待上传文件列表进行准确统计)
    final confirmed = await _showConfirmDialog(finalUploadList);
    if (!confirmed) return;

    // 5. 开始上传
    setState(() {
      isUploading = true;
    });

    await _uploadManager.uploadLocalFiles(
      finalUploadList, // 传递实际的文件路径列表
      onProgress: (progress) {
        // 进度在 listener 中自动更新
      },
      onComplete: (success, message) {
        if (mounted) {
          setState(() {
            isUploading = false;
            uploadProgress = null;
            if (success) {
              // 清空选择
              selectedIndices.clear();
              isSelectionMode = false;
            }
          });
          _showMessage(message, isError: !success);
        }
      },
    );
  }

  /// 显示确认对话框
  Future<bool> _showConfirmDialog(List<String> filePaths) async {
    // 在后台线程中运行文件统计分析
    final analysis = await compute(_analyzeFilesForUpload, filePaths);

    final imageCount = analysis.imageCount;
    final videoCount = analysis.videoCount;
    final totalSizeMB = analysis.totalBytes / (1024 * 1024);

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认上传'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 使用准确的统计数据
            Text('即将上传 ${filePaths.length} 个文件：'),
            const SizedBox(height: 8),
            Text('• ${imageCount} 张照片'),
            Text('• ${videoCount} 个视频'),
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
    ) ?? false;
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

  // MARK: - 底部栏统计信息 (基于当前页面选中的项目，不递归)

  int _getSelectedImageCount() {
    return selectedIndices
        .where((index) => index < fileItems.length && fileItems[index].type == FileItemType.image)
        .length;
  }

  int _getSelectedVideoCount() {
    return selectedIndices
        .where((index) => index < fileItems.length && fileItems[index].type == FileItemType.video)
        .length;
  }

  double _getDeviceStorageUsed() {
    double used = MyInstance().p6deviceInfoModel?.ttlUsed ?? 0;
    double scaled = used * 100.0;
    int usedPercent = scaled.round();
    return usedPercent / 100.0;
  }

  double _getSelectedTotalSize() {
    // 只计算选中的文件（不包括文件夹本身的大小）
    int totalBytes = selectedIndices
        .where((index) => index < fileItems.length)
        .map((index) => fileItems[index])
        .where((item) => item.type != FileItemType.folder)
        .fold(0, (sum, item) => sum + item.size);
    return totalBytes / (1024 * 1024);
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
            widget.onNavigationChanged != null
                ? SideNavigation(
              selectedIndex: widget.selectedNavIndex,
              onNavigationChanged: _handleNavigationChanged,
            )
                : const _StaticSideNavigation(),
            Expanded(
              child: Row(
                children: [
                  // 主内容区域
                  Expanded(
                    flex: _showPreview ? 3 : 1,
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
                  // 预览区域
                  if (_showPreview)
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

  // 新增：构建预览面板
  Widget _buildPreviewPanel() {
    if (_previewIndex < 0 || _previewIndex >= _mediaItems.length) {
      return Container();
    }

    final item = _mediaItems[_previewIndex];
    final isVideo = item.type == FileItemType.video;

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // 媒体显示区域
          Center(
            child: isVideo ? _buildVideoPreview(item) : _buildImagePreview(item),
          ),

          // 左侧切换按钮
          if (_previewIndex > 0)
            Positioned(
              left: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_left, size: 48, color: Colors.white),
                  onPressed: _previousMedia,
                ),
              ),
            ),

          // 右侧切换按钮
          if (_previewIndex < _mediaItems.length - 1)
            Positioned(
              right: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_right, size: 48, color: Colors.white),
                  onPressed: _nextMedia,
                ),
              ),
            ),

          // 视频播放/暂停按钮
          if (isVideo)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    size: 80,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  onPressed: _togglePlayPause,
                ),
              ),
            ),

          // 关闭按钮
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, size: 32, color: Colors.white),
              onPressed: _closePreview,
            ),
          ),

          // 文件名显示
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_previewIndex + 1}/${_mediaItems.length} - ${item.name}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 新增：构建图片预览
  Widget _buildImagePreview(FileItem item) {
    return Image.file(
      File(item.path),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(Icons.error, color: Colors.white, size: 64),
        );
      },
    );
  }

  // 新增：构建视频预览
  Widget _buildVideoPreview(FileItem item) {
    if (_videoController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Video(
      controller: _videoController!,
      controls: NoVideoControls,
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: Row(
        children: [
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
          IconButton(
            icon: Icon(
              selectedIndices.length == _getSelectableCount() && selectedIndices.isNotEmpty
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
            ),
            onPressed: isUploading ? null : _toggleSelectAll,
            tooltip: selectedIndices.length == _getSelectableCount() && selectedIndices.isNotEmpty
                ? '取消全选'
                : '全选',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: '筛选',
            offset: const Offset(0, 45),
            enabled: !isUploading,
            onSelected: (value) {
              setState(() {
                filterType = value;
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
          IconButton(
            icon: Icon(
              Icons.grid_view,
              color: isGridView ? const Color(0xFF2C2C2C) : Colors.grey,
            ),
            onPressed: isUploading ? null : () {
              setState(() {
                isGridView = true;
              });
            },
            tooltip: '网格视图',
          ),
          IconButton(
            icon: Icon(
              Icons.list,
              color: !isGridView ? const Color(0xFF2C2C2C) : Colors.grey,
            ),
            onPressed: isUploading ? null : () {
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

    if (isGridView) {
      return _buildGridView(filteredFiles);
    } else {
      return _buildListView(filteredFiles);
    }
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
              final actualIndex = fileItems.indexOf(filteredFiles[index]);
              return GestureDetector(
                onDoubleTap: isUploading
                    ? null
                    : () {
                  // 双击进入文件夹
                  if (filteredFiles[index].type == FileItemType.folder) {
                    _navigateToFolder(
                      filteredFiles[index].path,
                      filteredFiles[index].name,
                    );
                  }else{
                    _openFullScreenViewer(actualIndex);  // 新增这行
                  }
                },
                child: FileItemCard(
                  item: filteredFiles[index],
                  isSelected: selectedIndices.contains(actualIndex),
                  showCheckbox: isSelectionMode || selectedIndices.contains(actualIndex),
                  canSelect: true,
                  onTap: isUploading
                      ? () {}
                      : () {
                    if (isSelectionMode) {
                      _toggleSelection(actualIndex);
                    } else if (filteredFiles[index].type == FileItemType.folder) {
                      _navigateToFolder(
                        filteredFiles[index].path,
                        filteredFiles[index].name,
                      );
                    } else {
                      // 单击图片或视频打开预览
                      _openPreview(actualIndex);
                    }
                  },
                  onLongPress: isUploading
                      ? () {}
                      : () {
                    _toggleSelection(actualIndex);
                  },
                  onCheckboxToggle: isUploading
                      ? () {}
                      : () => _toggleSelection(actualIndex),
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
        final actualIndex = fileItems.indexOf(filteredFiles[index]);
        return GestureDetector(
          onDoubleTap: isUploading
              ? null
              : () {
            // 双击进入文件夹
            if (filteredFiles[index].type == FileItemType.folder) {
              _navigateToFolder(
                filteredFiles[index].path,
                filteredFiles[index].name,
              );
            }
          },
          child: FileListItem(
            item: filteredFiles[index],
            isSelected: selectedIndices.contains(actualIndex),
            canSelect: isSelectionMode || selectedIndices.contains(actualIndex),
            onTap: isUploading
                ? () {}
                : () {
              if (isSelectionMode) {
                _toggleSelection(actualIndex);
              } else if (filteredFiles[index].type == FileItemType.folder) {
                _navigateToFolder(
                  filteredFiles[index].path,
                  filteredFiles[index].name,
                );
              } else {
                // 单击图片或视频打开预览
                _openPreview(actualIndex);
              }
            },
            onCheckboxToggle: isUploading
                ? () {}
                : () => _toggleSelection(actualIndex),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    if (selectedIndices.isEmpty && !isUploading) {
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
          // 左侧信息
          if (selectedIndices.isNotEmpty) ...[
            Text(
              '已选：${_getSelectedTotalSize().toStringAsFixed(2)}MB · ${_getSelectedImageCount()}张照片/${_getSelectedVideoCount()}条视频',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],

          // 上传进度
          if (isUploading && uploadProgress != null) ...[
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: uploadProgress!.progress,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(uploadProgress!.progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${uploadProgress!.uploadedFiles}/${uploadProgress!.totalFiles} · ${uploadProgress!.currentFileName ?? ""}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),

          // 右侧按钮
          Text(
            '设备剩余空间：${_getDeviceStorageUsed()}G',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 30),
          ElevatedButton(
            onPressed: isUploading ? null : _handleSync,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C2C2C),
              disabledBackgroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isUploading ? '上传中...' : '同步',
              style: const TextStyle(
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