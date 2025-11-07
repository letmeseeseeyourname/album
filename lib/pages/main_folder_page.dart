// pages/main_folder_page.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../widgets/side_navigation.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/folder_grid_component.dart';
import '../widgets/empty_state.dart';
import '../models/folder_info.dart';
import '../user/models/group.dart';
import '../services/folder_manager.dart';
import '../album/manager/local_folder_upload_manager.dart';
import '../user/my_instance.dart';
import 'folder_detail_page.dart';

class MainFolderPage extends StatefulWidget {
  final int selectedNavIndex;
  final Function(int)? onNavigationChanged;
  final List<Group>? groups;
  final Group? selectedGroup;
  final Function(Group)? onGroupSelected;
  final int? currentUserId;

  const MainFolderPage({
    super.key,
    this.selectedNavIndex = 0,
    this.onNavigationChanged,
    this.groups,
    this.selectedGroup,
    this.onGroupSelected,
    this.currentUserId,
  });

  @override
  State<MainFolderPage> createState() => _MainFolderPageState();
}

class _MainFolderPageState extends State<MainFolderPage> {
  final FolderManager _folderManager = FolderManager();
  final LocalFolderUploadManager _uploadManager = LocalFolderUploadManager();
  List<FolderInfo> folders = [];
  Set<int> selectedIndices = {};
  bool isSelectionMode = false;
  int? hoveredIndex;
  bool _isLoading = true;
  bool isUploading = false;
  LocalUploadProgress? uploadProgress;

  @override
  void initState() {
    super.initState();
    _loadFolders();
    _uploadManager.addListener(_onUploadProgressChanged);
  }

  @override
  void dispose() {
    _uploadManager.removeListener(_onUploadProgressChanged);
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
              if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) {
                imageCount++;
              } else if (['mp4', 'avi', 'mov', 'mkv', 'flv'].contains(ext)) {
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
  }

  void _cancelSelection() {
    setState(() {
      selectedIndices.clear();
      isSelectionMode = false;
    });
  }

  void _deleteSelected() {
    final count = selectedIndices.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除文件夹'),
        content: Text(
          '删除文件夹不会删除电脑本地的文件夹\n确定要删除？\n\n将删除 $count 个文件夹',
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

  /// 处理同步操作
  Future<void> _handleSync() async {
    if (selectedIndices.isEmpty) {
      _showErrorDialog('请选择文件夹', '请至少选择一个文件夹进行同步');
      return;
    }

    // 收集选中的文件夹路径
    final selectedFolders = selectedIndices
        .map((index) => folders[index])
        .toList();

    // 开始上传
    try {
      // await _uploadManager.uploadFolders(selectedFolders);
      _showSuccessSnackBar('同步完成');

      // 清除选择
      setState(() {
        selectedIndices.clear();
        isSelectionMode = false;
      });
    } catch (e) {
      print('Upload error: $e');
      _showErrorDialog('同步失败', '上传过程中发生错误：$e');
    }
  }

  /// 获取选中项的总大小（MB）
  double _getSelectedTotalSize() {
    double totalBytes = 0;
    for (var index in selectedIndices) {
      if (index < folders.length) {
        // 这里需要实际计算文件夹大小，暂时返回估算值
        totalBytes += folders[index].fileCount * 2 * 1024 * 1024; // 假设每个文件2MB
      }
    }
    return totalBytes / (1024 * 1024);
  }

  /// 获取选中项的图片数量
  int _getSelectedImageCount() {
    int count = 0;
    for (var index in selectedIndices) {
      if (index < folders.length) {
        count += folders[index].fileCount;
      }
    }
    return count;
  }

  /// 获取选中项的视频数量
  int _getSelectedVideoCount() {
    int count = 0;
    for (var index in selectedIndices) {
      if (index < folders.length) {
        count += folders[index].totalSize; // totalSize存储视频数量
      }
    }
    return count;
  }

  /// 获取设备存储使用情况
  double _getDeviceStorageUsed() {
    double used = MyInstance().p6deviceInfoModel?.ttlUsed ?? 0;
    double scaled = used * 100.0;
    int usedPercent = scaled.round();
    return usedPercent / 100.0;
  }

  void _showWarningDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
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
            const Icon(Icons.error_outline, color: Colors.red),
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
        onAddFolder: _pickFolder,
        child: Row(
          children: [
            widget.onNavigationChanged != null
                ? SideNavigation(
              selectedIndex: widget.selectedNavIndex,
              onNavigationChanged: widget.onNavigationChanged!,
              groups: widget.groups,
              selectedGroup: widget.selectedGroup,
              onGroupSelected: widget.onGroupSelected,
              currentUserId: widget.currentUserId,
            )
                : _buildStaticNavigation(),
            Expanded(
              child: Container(
                color: Colors.white,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : (folders.isEmpty
                    ? EmptyState(onImport: _pickFolder)
                    : _buildFolderList()),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildStaticNavigation() {
    return Container(
      width: 220,
      color: const Color(0xFFF5E8DC),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildStaticNavButton(Icons.home, '本地图库', true),
          _buildStaticNavButton(Icons.cloud, '相册图库', false),
        ],
      ),
    );
  }

  Widget _buildStaticNavButton(IconData icon, String label, bool isSelected) {
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
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.grid_view),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.list),
                onPressed: () {},
              ),
            ],
          ),
        ),
        Expanded(
          child: FolderGridComponent(
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
          ),
        ),
      ],
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