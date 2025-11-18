// pages/main_folder_page.dart
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
import '../album/manager/local_folder_upload_manager.dart';
import '../user/my_instance.dart';
import 'local_album/pages/folder_detail_page.dart';

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
  bool isGridView = true;  // 🆕 添加视图模式状态，默认为网格视图

  // 🆕 添加递归统计缓存
  int _cachedImageCount = 0;
  int _cachedVideoCount = 0;
  double _cachedTotalSizeMB = 0.0;  // 缓存的总文件大小(MB)
  bool _isCountingFiles = false;

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

    // 🆕 选择改变时,触发递归统计
    _updateSelectedFileCounts();
  }

  void _cancelSelection() {
    setState(() {
      selectedIndices.clear();
      isSelectionMode = false;
      // 🆕 清除缓存
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

  // 🆕 全选/取消全选
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

    // 🆕 选择改变时,触发递归统计
    if (selectedIndices.isNotEmpty) {
      _updateSelectedFileCounts();
    }
  }

  // 🆕 切换视图模式
  void _toggleViewMode(bool isGrid) {
    setState(() {
      isGridView = isGrid;
    });
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

  /// 获取选中项的总大小（MB）- 返回递归统计的实际文件大小
  double _getSelectedTotalSize() {
    return _cachedTotalSizeMB;
  }

  /// 🆕 递归统计文件夹中的图片数量(包含所有子目录)
  Future<int> _countImagesInFolder(String folderPath) async {
    int count = 0;
    try {
      final directory = Directory(folderPath);
      await for (var entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final ext = entity.path.split('.').last.toLowerCase();
          if (['bmp', 'gif', 'jpg', 'jpeg', 'png', 'webp', 'wbmp', 'heic'].contains(ext)) {
            count++;
          }
        }
      }
    } catch (e) {
      print('Error counting images in folder $folderPath: $e');
    }
    return count;
  }

  /// 🆕 递归统计文件夹中的视频数量(包含所有子目录)
  Future<int> _countVideosInFolder(String folderPath) async {
    int count = 0;
    try {
      final directory = Directory(folderPath);
      await for (var entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final ext = entity.path.split('.').last.toLowerCase();
          if (['mp4', 'mov', 'avi', '3gp', 'mkv', '3gp2'].contains(ext)) {
            count++;
          }
        }
      }
    } catch (e) {
      print('Error counting videos in folder $folderPath: $e');
    }
    return count;
  }

  /// 🆕 递归统计文件夹中所有文件的总大小(包含所有子目录,返回字节数)
  Future<int> _calculateFolderSize(String folderPath) async {
    int totalSize = 0;
    try {
      final directory = Directory(folderPath);
      await for (var entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            totalSize += stat.size;
          } catch (e) {
            print('Error getting file size for ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      print('Error calculating folder size for $folderPath: $e');
    }
    return totalSize;
  }

  /// 🆕 异步更新选中文件夹的文件统计(递归统计所有子目录)
  Future<void> _updateSelectedFileCounts() async {
    if (_isCountingFiles || selectedIndices.isEmpty) {
      return;
    }

    // 🔧 修复: 通过setState设置统计状态,触发UI更新
    setState(() {
      _isCountingFiles = true;
    });

    try {
      int imageCount = 0;
      int videoCount = 0;
      int totalSizeBytes = 0;  // 总大小(字节)

      for (var index in selectedIndices) {
        if (index < folders.length) {
          final folderPath = folders[index].path;
          imageCount += await _countImagesInFolder(folderPath);
          videoCount += await _countVideosInFolder(folderPath);
          totalSizeBytes += await _calculateFolderSize(folderPath);
        }
      }

      if (mounted) {
        setState(() {
          _cachedImageCount = imageCount;
          _cachedVideoCount = videoCount;
          _cachedTotalSizeMB = totalSizeBytes / (1024 * 1024);  // 转换为MB
          _isCountingFiles = false;
        });
      }
    } catch (e) {
      print('Error updating file counts: $e');
      // 🔧 修复: 确保即使发生错误也重置统计状态
      if (mounted) {
        setState(() {
          _isCountingFiles = false;
        });
      }
    }
  }

  /// 获取选中项的图片数量(返回递归统计的结果)
  int _getSelectedImageCount() {
    return _cachedImageCount;
  }

  /// 获取选中项的视频数量(返回递归统计的结果)
  int _getSelectedVideoCount() {
    return _cachedVideoCount;
  }

  /// 🆕 格式化文件大小显示(自动选择MB或GB单位)
  String _formatFileSize(double sizeMB) {
    if (sizeMB < 1024) {
      // 小于1GB时，使用MB
      return '${sizeMB.toStringAsFixed(2)}MB';
    } else {
      // 大于等于1GB时，使用GB
      double sizeGB = sizeMB / 1024;
      return '${sizeGB.toStringAsFixed(2)}GB';
    }
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
          _buildStaticNavButton(Icons.home, '此电脑', true),
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

  // 🆕 构建视图切换器
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

  // 🆕 构建单个视图按钮
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

  // 🆕 构建列表视图
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
                    pageBuilder: (context, animation, secondaryAnimation) => FolderDetailPageRefactored(
                      folder: folder,
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
              // 🆕 全选/取消全选按钮
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
              // 🆕 视图切换器
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
                    pageBuilder: (context, animation, secondaryAnimation) => FolderDetailPageRefactored(
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
          )
              : _buildListView(),  // 🆕 列表视图
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
            // 🆕 显示统计中状态或统计结果
            _isCountingFiles
                ? Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '正在统计文件...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            )
                : Text(
              '已选：${_formatFileSize(_getSelectedTotalSize())} · ${_getSelectedImageCount()}张照片/${_getSelectedVideoCount()}条视频',
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