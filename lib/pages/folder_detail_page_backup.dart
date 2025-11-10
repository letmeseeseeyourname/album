// pages/folder_detail_page_backup.dart (重构版)
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../album/manager/local_folder_upload_manager.dart';
import '../controllers/folder_controller.dart';
import '../controllers/preview_controller.dart';
import '../controllers/selection_controller.dart';
import '../models/file_item.dart';
import '../models/folder_info.dart';
import '../user/my_instance.dart';
import '../utils/file_util.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/file_item_card.dart';
import '../widgets/file_list_item.dart';
import '../widgets/folder_top_bar.dart';
import '../widgets/preview_panel.dart';
import '../widgets/side_navigation.dart';
import '../widgets/upload_bottom_bar.dart';

/// 文件夹详情页面 - 重构版
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
  // 控制器 - 延迟初始化
  FolderController? _folderController;
  SelectionController? _selectionController;
  PreviewController? _previewController;

  // 上传管理器
  final LocalFolderUploadManager _uploadManager = LocalFolderUploadManager();

  // 上传状态
  bool _isUploading = false;
  LocalUploadProgress? _uploadProgress;

  @override
  void initState() {
    super.initState();

    // 初始化控制器
    _folderController = FolderController(widget.folder);
    _selectionController = SelectionController();
    _previewController = PreviewController();

    // 监听文件夹变化，更新选择控制器
    _folderController!.addListener(_onFolderChanged);

    // 监听预览控制器变化
    _previewController!.addListener(_onPreviewChanged);

    // 监听上传进度
    _uploadManager.addListener(_onUploadProgressChanged);

    // 加载初始文件
    _folderController!.loadFiles(widget.folder.path);
  }

  // 安全访问控制器的便捷方法
  FolderController get folderCtrl => _folderController!;
  SelectionController get selectionCtrl => _selectionController!;
  PreviewController get previewCtrl => _previewController!;

  @override
  void dispose() {
    _folderController?.removeListener(_onFolderChanged);
    _previewController?.removeListener(_onPreviewChanged);
    _uploadManager.removeListener(_onUploadProgressChanged);
    _folderController?.dispose();
    _selectionController?.dispose();
    _previewController?.dispose();
    super.dispose();
  }

  void _onFolderChanged() {
    // 文件列表变化时，更新选择控制器
    _selectionController?.updateFileItems(_folderController?.fileItems ?? []);
    setState(() {});
  }

  void _onPreviewChanged() {
    // 预览状态变化时，重新构建UI
    if (mounted) {
      setState(() {});
    }
  }

  void _onUploadProgressChanged() {
    if (mounted) {
      setState(() {
        _uploadProgress = _uploadManager.currentProgress;
        _isUploading = _uploadManager.isUploading;
      });
    }
  }

  void _handleNavigationChanged(int index) {
    if (index != widget.selectedNavIndex) {
      Navigator.pop(context);
      widget.onNavigationChanged?.call(index);
    }
  }

  /// 处理文件/文件夹点击
  void _handleItemTap(int index) {
    final item = folderCtrl.fileItems[index];

    if (selectionCtrl.isSelectionMode) {
      // 选择模式：切换选中状态
      selectionCtrl.toggleSelection(index);
    } else if (item.type == FileItemType.folder) {
      // 非选择模式：进入文件夹
      folderCtrl.navigateToFolder(item.path, item.name);
    } else {
      // 非选择模式：打开预览
      previewCtrl.openPreview(folderCtrl.fileItems, index);
    }
    setState(() {});
  }

  /// 处理文件/文件夹双击
  void _handleItemDoubleTap(int index) {
    final item = folderCtrl.fileItems[index];

    if (item.type == FileItemType.folder) {
      folderCtrl.navigateToFolder(item.path, item.name);
      setState(() {});
    }
  }

  /// 处理长按
  void _handleItemLongPress(int index) {
    selectionCtrl.toggleSelection(index);
    setState(() {});
  }

  /// 处理同步上传
  Future<void> _handleSync() async {
    if (selectionCtrl.selectedIndices.isEmpty) {
      _showMessage('请先选择要上传的文件或文件夹', isError: true);
      return;
    }

    if (_isUploading) {
      _showMessage('已有上传任务在进行中', isError: true);
      return;
    }

    // 获取选中的项目
    final selectedItems = selectionCtrl.getSelectedItems();

    // 分离文件和文件夹
    final selectedFiles = selectedItems
        .where((item) => item.type != FileItemType.folder)
        .toList();
    final selectedFolders = selectedItems
        .where((item) => item.type == FileItemType.folder)
        .toList();

    // 构建最终待上传文件列表
    final List<String> allFilesToUpload = [];
    allFilesToUpload.addAll(selectedFiles.map((item) => item.path));

    // 递归处理文件夹
    if (selectedFolders.isNotEmpty) {
      _showMessage('正在扫描选中的文件夹，请稍候...', isError: false);
      for (final folder in selectedFolders) {
        final filesInFolder = await compute(
          FileUtils.getAllMediaFilesRecursive,
          folder.path,
        );
        allFilesToUpload.addAll(filesInFolder);
      }
    }

    // 去重
    final finalUploadList = allFilesToUpload.toSet().toList();

    if (finalUploadList.isEmpty) {
      _showMessage('没有可上传的媒体文件', isError: true);
      return;
    }

    // 显示确认对话框
    final confirmed = await _showConfirmDialog(finalUploadList);
    if (!confirmed) return;

    // 开始上传
    setState(() {
      _isUploading = true;
    });

    await _uploadManager.uploadLocalFiles(
      finalUploadList,
      onProgress: (progress) {
        // 进度在 listener 中自动更新
      },
      onComplete: (success, message) {
        if (mounted) {
          setState(() {
            _isUploading = false;
            _uploadProgress = null;
            if (success) {
              selectionCtrl.clearSelection();
            }
          });
          _showMessage(message, isError: !success);
        }
      },
    );
  }

  /// 显示确认对话框
  Future<bool> _showConfirmDialog(List<String> filePaths) async {
    final analysis = await compute(FileAnalyzer.analyzeFiles, filePaths);

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
            Text('• ${analysis.imageCount} 张照片'),
            Text('• ${analysis.videoCount} 个视频'),
            Text('• 总大小：${analysis.totalSizeMB.toStringAsFixed(2)} MB'),
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

  /// 获取设备存储信息
  String _getDeviceStorageInfo() {
    final used = MyInstance().p6deviceInfoModel?.ttlUsed ?? 0;
    final scaled = used * 100.0;
    final usedPercent = scaled.round();
    final result = usedPercent / 100.0;
    return '设备剩余空间：${result}G';
  }

  @override
  Widget build(BuildContext context) {
    // 如果控制器未初始化，显示加载指示器
    if (_folderController == null || _selectionController == null || _previewController == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
                    flex: previewCtrl.showPreview ? 3 : 1,
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          // 顶部工具栏
                          FolderTopBar(
                            folderController: folderCtrl,
                            selectionController: selectionCtrl,
                            onNavigateBack: () => Navigator.pop(context),
                            isUploading: _isUploading,
                          ),

                          // 文件列表
                          Expanded(
                            child: _buildFileContent(),
                          ),

                          // 底部上传栏
                          UploadBottomBar(
                            selectionController: selectionCtrl,
                            isUploading: _isUploading,
                            uploadProgress: _uploadProgress,
                            onSyncPressed: _handleSync,
                            deviceStorageInfo: _getDeviceStorageInfo(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 预览面板
                  if (previewCtrl.showPreview)
                    Expanded(
                      flex: 2,
                      child: PreviewPanel(controller: previewCtrl),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileContent() {
    if (folderCtrl.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredFiles = folderCtrl.getFilteredFiles();

    if (filteredFiles.isEmpty) {
      return const Center(
        child: Text(
          '此文件夹为空',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    if (folderCtrl.isGridView) {
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
              final actualIndex =
              folderCtrl.fileItems.indexOf(filteredFiles[index]);
              return GestureDetector(
                onDoubleTap: _isUploading
                    ? null
                    : () => _handleItemDoubleTap(actualIndex),
                child: FileItemCard(
                  item: filteredFiles[index],
                  isSelected: selectionCtrl.isSelected(actualIndex),
                  showCheckbox: selectionCtrl.isSelectionMode ||
                      selectionCtrl.isSelected(actualIndex),
                  canSelect: true,
                  onTap: _isUploading
                      ? () {}
                      : () => _handleItemTap(actualIndex),
                  onLongPress: _isUploading
                      ? () {}
                      : () => _handleItemLongPress(actualIndex),
                  onCheckboxToggle: _isUploading
                      ? () {}
                      : () => selectionCtrl.toggleSelection(actualIndex),
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
        final actualIndex =
        folderCtrl.fileItems.indexOf(filteredFiles[index]);
        return GestureDetector(
          onDoubleTap:
          _isUploading ? null : () => _handleItemDoubleTap(actualIndex),
          child: FileListItem(
            item: filteredFiles[index],
            isSelected: selectionCtrl.isSelected(actualIndex),
            canSelect: selectionCtrl.isSelectionMode ||
                selectionCtrl.isSelected(actualIndex),
            onTap: _isUploading ? () {} : () => _handleItemTap(actualIndex),
            onCheckboxToggle: _isUploading
                ? () {}
                : () => selectionCtrl.toggleSelection(actualIndex),
          ),
        );
      },
    );
  }
}

/// 静态侧边导航（向后兼容）
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