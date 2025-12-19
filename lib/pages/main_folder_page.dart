// pages/main_folder_page.dart (添加 hasUpdate 参数)
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../widgets/side_navigation.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/folder_grid_component.dart';
import '../widgets/empty_state.dart';
import '../models/folder_info.dart';
import '../user/models/group.dart';
import '../services/folder_manager.dart';
import '../user/my_instance.dart';
import '../widgets/upload_bottom_bar.dart';
import 'local_album/controllers/upload_coordinator.dart';
import 'local_album/pages/folder_detail_page.dart';
// MARK: - 辅助模型和静态方法 (用于在后台隔离区运行)

/// 用于返回上传分析结果的模型
class UploadAnalysisResult {
  final int imageCount;
  final int videoCount;
  final int totalBytes;

  UploadAnalysisResult(this.imageCount, this.videoCount, this.totalBytes);
}

/// 递归获取所有媒体文件路径
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

/// 分析最终上传文件列表的统计数据
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

class MainFolderPage extends StatefulWidget {
  final int selectedNavIndex;
  final Function(int)? onNavigationChanged;
  final List<Group>? groups;
  final Group? selectedGroup;
  final Future<void> Function(Group)? onGroupSelected;
  final int? currentUserId;
  final bool isGroupsLoading;
  final bool hasUpdate; // 🆕 添加升级状态参数

  const MainFolderPage({
    super.key,
    this.selectedNavIndex = 0,
    this.onNavigationChanged,
    this.groups,
    this.selectedGroup,
    this.onGroupSelected,
    this.currentUserId,
    this.isGroupsLoading = false,
    this.hasUpdate = false, // 🆕 默认值
  });

  @override
  State<MainFolderPage> createState() => _MainFolderPageState();
}

class _MainFolderPageState extends State<MainFolderPage> with UploadCoordinatorMixin {
  final FolderManager _folderManager = FolderManager();
  // final LocalFolderUploadManager _uploadManager = LocalFolderUploadManager();
  // LocalUploadProgress? uploadProgress;
  // bool isUploading = false;
  List<FolderInfo> folders = [];
  Set<int> selectedIndices = {};
  bool isSelectionMode = false;
  int? hoveredIndex;
  bool _isLoading = true;
  bool isGridView = true;  // 添加视图模式状态，默认为网格视图

  // 添加递归统计缓存
  int _cachedImageCount = 0;
  int _cachedVideoCount = 0;
  double _cachedTotalSizeMB = 0.0;  // 缓存的总文件大小(MB)
  bool _isCountingFiles = false;

  @override
  void initState() {
    super.initState();
    _loadFolders();
    // _uploadManager.addListener(_onUploadProgressChanged);
  }

  @override
  void dispose() {
    // _uploadManager.removeListener(_onUploadProgressChanged);
    super.dispose();
  }

  // void _onUploadProgressChanged() {
  //   if (mounted) {
  //     setState(() {
  //       uploadProgress = _uploadManager.currentProgress;
  //       isUploading = _uploadManager.isUploading;
  //     });
  //   }
  // }

  /// 从持久化存储加载本地图库文件夹列表
  Future<void> _loadFolders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final loadedFolders = await _folderManager.getLocalFolders();
      if (mounted) {
        setState(() {
          folders = loadedFolders;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading local folders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickFolder() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        // 检查是否已经添加过这个文件夹
        bool isDuplicate = folders.any((folder) => folder.path == selectedDirectory);

        if (isDuplicate) {
          final existingFolder = folders.firstWhere((folder) => folder.path == selectedDirectory);
          _showWarningDialog('该文件夹已添加', '文件夹 "${existingFolder.name}" 已经在列表中，无需重复添加。');
          return;
        }

        final folderName = selectedDirectory.split(Platform.pathSeparator).last;
        final directory = Directory(selectedDirectory);
        int imageCount = 0;
        int videoCount = 0;

        try {
          await for (var entity in directory.list()) {
            if (entity is File) {
              final ext = entity.path.split('.').last.toLowerCase();
              if (['bmp', 'gif', 'jpg', 'jpeg', 'png', 'webp', 'wbmp', 'heic'].contains(ext)) {
                imageCount++;
              } else if (['mp4', 'mov', 'avi', '3gp', 'mkv', '3gp2'].contains(ext)) {
                videoCount++;
              }
            }
          }
        } catch (e) {
          print('Error scanning directory: $e');
        }

        final newFolder = FolderInfo(
          name: folderName,
          path: selectedDirectory,
          fileCount: imageCount,
          totalSize: videoCount,
        );

        await _folderManager.addLocalFolder(newFolder);
        await _loadFolders();
        _showSuccessSnackBar('已添加文件夹 "$folderName"');
      }
    } catch (e) {
      print('Error picking folder: $e');
      _showErrorDialog('添加失败', '无法添加文件夹，请重试。');
    }
  }

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

    // 选择改变时,触发递归统计
    _updateSelectedFileCounts();
  }

  void _cancelSelection() {
    setState(() {
      selectedIndices.clear();
      isSelectionMode = false;
      // 清除缓存
      _cachedImageCount = 0;
      _cachedVideoCount = 0;
      _cachedTotalSizeMB = 0.0;
    });
  }

  void _deleteSelected() {
    final count = selectedIndices.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除文件夹'),
        content: Text(
          '删除文件夹不会删除电脑本地的文件夹\n确定要删除?\n\n将删除 $count 个文件夹',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '取消',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final sortedIndices = selectedIndices.toList()..sort((a, b) => b.compareTo(a));

              for (var index in sortedIndices) {
                if (index < folders.length) {
                  await _folderManager.removeLocalFolder(folders[index].path);
                }
              }

              await _loadFolders();

              setState(() {
                selectedIndices.clear();
                isSelectionMode = false;
              });

              _showSuccessSnackBar('已删除 $count 个文件夹');
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF2C2C2C),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              '确定',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // 全选/取消全选
  void _toggleSelectAll() {
    setState(() {
      if (selectedIndices.length == folders.length && folders.isNotEmpty) {
        // 如果已全选，则取消全选
        selectedIndices.clear();
        isSelectionMode = false;
        _cachedImageCount = 0;
        _cachedVideoCount = 0;
        _cachedTotalSizeMB = 0.0;
      } else {
        // 否则全选
        selectedIndices = Set.from(List.generate(folders.length, (index) => index));
        isSelectionMode = true;
      }
    });

    // 选择改变时,触发递归统计
    if (selectedIndices.isNotEmpty) {
      _updateSelectedFileCounts();
    }
  }

  // 切换视图模式
  void _toggleViewMode(bool isGrid) {
    setState(() {
      isGridView = isGrid;
    });
  }

  // MARK: - 文件夹上传逻辑

  /// 执行同步上传
  Future<void> _handleSync() async {
    if (selectedIndices.isEmpty) {
      _showMessage('请先选择要上传的文件夹', isError: true);
      return;
    }

    // 允许在有上传任务时添加新任务（支持多任务并发）
    // if (isUploading) {
    //   _showMessage('正在添加新的上传任务到队列...', isError: false);
    // }

    // 1. 获取所有选中的文件夹
    final selectedFolders = selectedIndices
        .map((index) => folders[index])
        .toList();

    // 2. 构建最终待上传文件列表
    final List<String> allFilesToUpload = [];

    // 递归处理选中的文件夹
    //_showMessage('正在扫描选中的文件夹，请稍候...', isError: false);
    for (final folder in selectedFolders) {
      // 在后台线程递归获取所有媒体文件路径
      final filesInFolder = await compute(_getAllMediaFilesRecursive, folder.path);
      allFilesToUpload.addAll(filesInFolder);
    }

    // 移除重复路径，并转为列表
    final finalUploadList = allFilesToUpload.toSet().toList();

    // 检查是否有文件需要上传
    if (finalUploadList.isEmpty) {
      _showMessage('没有可上传的媒体文件', isError: true);
      return;
    }

    // 3. 显示确认对话框 (传递实际的待上传文件列表进行准确统计)
    final confirmed = await _showConfirmDialog(finalUploadList);
    if (!confirmed) return;

    // ✅ 新增：用户点击"开始上传"后，立即取消选中
    setState(() {
      selectedIndices.clear();
      isSelectionMode = false;
      _cachedImageCount = 0;
      _cachedVideoCount = 0;
      _cachedTotalSizeMB = 0.0;
    });

    // ✅ 使用 uploadCoordinator（来自 Mixin）
    await uploadCoordinator.startUpload(
      finalUploadList,
          (message, {isError = false}) {
        _showMessage(message, isError: isError);
      },
          (List<String> uploadedMd5s) {
        // 完成回调
        if (mounted && !isUploading) {
          setState(() {
            selectedIndices.clear();
            isSelectionMode = false;
            _cachedImageCount = 0;
            _cachedVideoCount = 0;
            _cachedTotalSizeMB = 0.0;
          });
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
            child: const Text(
              '取消',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF2C2C2C),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              '确认上传',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  /// 异步更新选中文件夹的递归文件统计
  Future<void> _updateSelectedFileCounts() async {
    if (selectedIndices.isEmpty) {
      setState(() {
        _cachedImageCount = 0;
        _cachedVideoCount = 0;
        _cachedTotalSizeMB = 0.0;
      });
      return;
    }

    // 显示加载中状态
    setState(() {
      _isCountingFiles = true;
    });

    // 获取所有选中的文件夹
    final selectedFolders = selectedIndices
        .map((index) => folders[index])
        .toList();

    // 收集所有待统计的文件路径
    final List<String> allFilePaths = [];
    for (final folder in selectedFolders) {
      final filesInFolder = await compute(_getAllMediaFilesRecursive, folder.path);
      allFilePaths.addAll(filesInFolder);
    }

    // 去重
    final uniquePaths = allFilePaths.toSet().toList();

    // 统计
    final analysis = await compute(_analyzeFilesForUpload, uniquePaths);

    // 更新状态
    if (mounted) {
      setState(() {
        _cachedImageCount = analysis.imageCount;
        _cachedVideoCount = analysis.videoCount;
        _cachedTotalSizeMB = analysis.totalBytes / (1024 * 1024);
        _isCountingFiles = false;
      });
    }
  }

  // 获取选中文件夹的照片数量（使用缓存）
  int _getSelectedImageCount() {
    return _cachedImageCount;
  }

  // 获取选中文件夹的视频数量（使用缓存）
  int _getSelectedVideoCount() {
    return _cachedVideoCount;
  }

  // 获取选中文件夹的总大小（使用缓存）
  double _getSelectedTotalSize() {
    return _cachedTotalSizeMB;
  }

  String _formatFileSize(double sizeMB) {
    if (sizeMB >= 1024) {
      return '${(sizeMB / 1024).toStringAsFixed(2)}GB';
    }
    return '${sizeMB.toStringAsFixed(2)}MB';
  }

  String _getDeviceStorageUsed() {
    final deviceInfo = MyInstance().p6deviceInfoModel;
    if (deviceInfo != null) {
      final usedGB = (deviceInfo.ttlAll!.toInt()-deviceInfo.ttlUsed!.toInt());
      return usedGB.toStringAsFixed(2);
    }
    return '0.00';
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showWarningDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomTitleBar(
        backgroundColor: Color(0xFFF5E8DC),
        rightTitleBgColor: Colors.white,
        showToolbar: true,
        showTabs: false,
        onAddFolder: _pickFolder,
        hasUpdate: widget.hasUpdate, // 🆕 传递升级状态给 CustomTitleBar
        child: Row(
          children: [
            SideNavigation(
              selectedIndex: widget.selectedNavIndex,
              onNavigationChanged: widget.onNavigationChanged ?? (index) {},
              groups: widget.groups,
              selectedGroup: widget.selectedGroup,
              onGroupSelected: widget.onGroupSelected,
              currentUserId: widget.currentUserId,
            ),
            Expanded(
              child: Container(
                color: Colors.white,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : folders.isEmpty
                    ? EmptyState(
                  onImport: _pickFolder,
                )
                    : Column(
                  children: [
                    Expanded(child: _buildFolderList()),
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

  Widget _buildViewSwitcher() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 网格视图按钮
          _buildViewButton(
            isSelected: isGridView,
            iconPath: 'assets/icons/grid_view.svg',
            onTap: () => _toggleViewMode(true),
            isLeft: true,
          ),
          // 列表视图按钮
          _buildViewButton(
            isSelected: !isGridView,
            iconPath: 'assets/icons/list_view.svg',
            onTap: () => _toggleViewMode(false),
            isLeft: false,
          ),
        ],
      ),
    );
  }

  Widget _buildViewButton({
    required bool isSelected,
    required String iconPath,
    required VoidCallback onTap,
    required bool isLeft,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45,
        height: 27,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF15181D) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.horizontal(
            left: isLeft ? const Radius.circular(8) : Radius.zero,
            right: !isLeft ? const Radius.circular(8) : Radius.zero,
          ),
        ),
        child: Center(
          child: SvgPicture.asset(
            iconPath,
            width: 13,
            height: 13,
            colorFilter: ColorFilter.mode(
              isSelected ? Colors.white : const Color(0xFF15181D),
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        final isSelected = selectedIndices.contains(index);
        final isHovered = hoveredIndex == index;

        return MouseRegion(
          onEnter: (_) {
            setState(() {
              hoveredIndex = index;
            });
          },
          onExit: (_) {
            setState(() {
              hoveredIndex = null;
            });
          },
          child: GestureDetector(
            onTap: () {
              if (isSelectionMode) {
                _toggleSelection(index);
              } else {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => FolderDetailPage(
                      folder: folder,
                      selectedNavIndex: widget.selectedNavIndex,
                      onNavigationChanged: widget.onNavigationChanged,
                      // 🆕 传递 group 参数
                      groups: widget.groups,
                      selectedGroup: widget.selectedGroup,
                      onGroupSelected: widget.onGroupSelected,
                      currentUserId: widget.currentUserId,
                      isGroupsLoading: widget.isGroupsLoading,
                    ),
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(milliseconds: 200),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                  ),
                );
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.orange.withOpacity(0.1)
                    : (isHovered ? Colors.grey.shade100 : Colors.white),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.orange : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // 复选框
                  if (isSelectionMode || isHovered)
                    Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        _toggleSelection(index);
                      },
                      activeColor: Colors.orange,
                    )
                  else
                    const SizedBox(width: 48),

                  // 文件夹图标
                  const Icon(
                    Icons.folder,
                    color: Colors.orange,
                    size: 32,
                  ),
                  const SizedBox(width: 16),

                  // 文件夹信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          folder.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          folder.path,
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

                  // 文件数量
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${folder.fileCount} 个文件',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFolderList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Row(
            children: [
              const Text(
                '此电脑',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (isSelectionMode) ...[
                TextButton(
                  onPressed: _cancelSelection,
                  child: const Text(
                    '取消选择',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: _deleteSelected,
                  child: const Text(
                    '删除',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              // 全选/取消全选按钮
              IconButton(
                icon: SvgPicture.asset(
                  selectedIndices.length == folders.length && folders.isNotEmpty
                      ? 'assets/icons/selected_all_icon.svg'
                      : 'assets/icons/unselect_all_icon.svg',
                  width: 20,
                  height: 20,
                ),
                onPressed: _toggleSelectAll,
                tooltip: selectedIndices.length == folders.length && folders.isNotEmpty
                    ? '取消全选'
                    : '全选',
              ),
              const SizedBox(width: 8),
              // 视图切换器
              _buildViewSwitcher(),
            ],
          ),
        ),
        Expanded(
          child: isGridView
              ? FolderGridComponent(
            folders: folders,
            selectedIndices: selectedIndices,
            isSelectionMode: isSelectionMode,
            hoveredIndex: hoveredIndex,
            onHoverChanged: (index) {
              setState(() {
                hoveredIndex = index;
              });
            },
            onFolderTap: (index) {
              if (isSelectionMode) {
                _toggleSelection(index);
              } else {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => FolderDetailPage(
                      folder: folders[index],
                      selectedNavIndex: widget.selectedNavIndex,
                      onNavigationChanged: widget.onNavigationChanged,
                      // 🆕 传递 group 参数
                      groups: widget.groups,
                      selectedGroup: widget.selectedGroup,
                      onGroupSelected: widget.onGroupSelected,
                      currentUserId: widget.currentUserId,
                      isGroupsLoading: widget.isGroupsLoading,
                    ),
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(milliseconds: 200),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                  ),
                );
              }
            },
            onFolderLongPress: (index) {},
            onCheckboxToggle: (index) {
              _toggleSelection(index);
            },
          )
              : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return UploadBottomBar(
      selectedCount: selectedIndices.length,
      selectedTotalSizeMB: _cachedTotalSizeMB,
      selectedImageCount: _cachedImageCount,
      selectedVideoCount: _cachedVideoCount,
      deviceStorageSurplusGB: double.tryParse(_getDeviceStorageUsed()) ?? 0,
      isUploading: isUploading,           // ✅ 来自 Mixin
      uploadProgress: uploadProgress,      // ✅ 来自 Mixin
      onUploadPressed: _handleSync,
      isCountingFiles: _isCountingFiles,
    );
  }
}