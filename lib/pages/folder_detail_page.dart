// pages/folder_detail_page.dart
import 'dart:io';

import 'package:ablumwin/user/my_instance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../album/manager/local_folder_upload_manager.dart';
import '../models/file_item.dart';
import '../models/folder_info.dart';
import '../services/thumbnail_helper.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/file_item_card.dart';
import '../widgets/file_list_item.dart';
import '../widgets/side_navigation.dart';
// 导入独立的本地文件夹上传管理器


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
  // 使用独立的本地文件夹上传管理器
  final LocalFolderUploadManager _uploadManager = LocalFolderUploadManager();

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

  // 上传状态
  bool isUploading = false;
  LocalUploadProgress? uploadProgress;

  @override
  void initState() {
    super.initState();
    currentPath = widget.folder.path;
    _initPathSegments();
    _initializeHelper();
    _loadFiles(currentPath);

    // 监听上传进度
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

  void _initPathSegments() {
    final parts = widget.folder.path.split(Platform.pathSeparator);
    if (parts.isNotEmpty) {
      pathSegments = [parts[0], widget.folder.name];
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

  static Future<List<FileItem>> _loadFilesInBackground(String path) async {
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

  void _navigateToFolder(String folderPath, String folderName) {
    setState(() {
      currentPath = folderPath;
      pathSegments.add(folderName);
    });
    _loadFiles(folderPath);
  }

  void _navigateToPathSegment(int index) {
    if (index == 0) {
      Navigator.pop(context);
      return;
    }

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

  void _handleNavigationChanged(int index) {
    if (index != widget.selectedNavIndex) {
      Navigator.pop(context);
      widget.onNavigationChanged?.call(index);
    }
  }

  void _toggleSelection(int index) {
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

  void _toggleSelectAll() {
    setState(() {
      if (selectedIndices.length == _getSelectableCount()) {
        selectedIndices.clear();
        isSelectionMode = false;
      } else {
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

  void _cancelSelection() {
    setState(() {
      selectedIndices.clear();
      isSelectionMode = false;
    });
  }

  int _getSelectableCount() {
    return fileItems.where((item) => item.type != FileItemType.folder).length;
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

  /// 执行同步上传
  Future<void> _handleSync() async {
    if (selectedIndices.isEmpty) {
      _showMessage('请先选择要上传的文件', isError: true);
      return;
    }

    if (isUploading) {
      _showMessage('已有上传任务在进行中', isError: true);
      return;
    }

    // 获取选中的文件路径
    final selectedFiles = selectedIndices
        .map((index) => fileItems[index])
        .where((item) => item.type != FileItemType.folder)
        .map((item) => item.path)
        .toList();

    if (selectedFiles.isEmpty) {
      _showMessage('没有可上传的文件', isError: true);
      return;
    }

    // 显示确认对话框
    final confirmed = await _showConfirmDialog(selectedFiles.length);
    if (!confirmed) return;

    // 开始上传
    setState(() {
      isUploading = true;
    });

    // 使用独立的本地文件夹上传管理器
    await _uploadManager.uploadLocalFiles(
      selectedFiles,
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
  Future<bool> _showConfirmDialog(int fileCount) async {
    final imageCount = _getSelectedImageCount();
    final videoCount = _getSelectedVideoCount();
    final totalSize = _getSelectedTotalSize();

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认上传'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('即将上传 $fileCount 个文件：'),
            const SizedBox(height: 8),
            Text('• $imageCount 张照片'),
            Text('• $videoCount 个视频'),
            Text('• 总大小：${totalSize.toStringAsFixed(2)} MB'),
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
              return FileItemCard(
                item: filteredFiles[index],
                isSelected: selectedIndices.contains(actualIndex),
                showCheckbox: isSelectionMode || selectedIndices.contains(actualIndex),
                canSelect: filteredFiles[index].type != FileItemType.folder,
                onTap: isUploading
                    ? () {}
                    : () {
                  if (filteredFiles[index].type == FileItemType.folder) {
                    _navigateToFolder(
                      filteredFiles[index].path,
                      filteredFiles[index].name,
                    );
                  } else {
                    _toggleSelection(actualIndex);
                  }
                },
                onLongPress: isUploading
                    ? () {}
                    : () {
                  if (filteredFiles[index].type != FileItemType.folder) {
                    _toggleSelection(actualIndex);
                  }
                },
                onCheckboxToggle: isUploading
                    ? () {}
                    : () => _toggleSelection(actualIndex),
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
        return FileListItem(
          item: filteredFiles[index],
          isSelected: selectedIndices.contains(actualIndex),
          canSelect: filteredFiles[index].type != FileItemType.folder &&
              (isSelectionMode || selectedIndices.contains(actualIndex)),
          onTap: isUploading
              ? () {}
              : () {
            if (filteredFiles[index].type == FileItemType.folder) {
              _navigateToFolder(
                filteredFiles[index].path,
                filteredFiles[index].name,
              );
            } else {
              _toggleSelection(actualIndex);
            }
          },
          onCheckboxToggle: isUploading
              ? () {}
              : () => _toggleSelection(actualIndex),
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

// 注意：这里省略了 _FileItemCard 和 _FileListItem 的实现
// 它们与原文件保持一致