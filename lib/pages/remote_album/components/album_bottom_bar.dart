// album/components/album_bottom_bar.dart (带调试信息)
import 'package:flutter/material.dart';
import '../managers/selection_manager.dart';
import '../managers/album_data_manager.dart';
import '../../../services/album_download_manager.dart';

/// 相册底部栏组件
/// 显示选中信息和下载按钮
class AlbumBottomBar extends StatelessWidget {
  final SelectionManager selectionManager;
  final AlbumDataManager dataManager;

  const AlbumBottomBar({
    super.key,
    required this.selectionManager,
    required this.dataManager,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([selectionManager, dataManager]),
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(
              top: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 左侧信息
              _buildInfoSection(),
              // 下载按钮
              _buildDownloadButton(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoSection() {
    final selectedSize = dataManager.calculateSelectedSize(
      selectionManager.selectedResIds,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          selectedSize,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '硬盘剩余空间：320GB',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadButton(BuildContext context) {
    final hasSelection = selectionManager.hasSelection;

    return ElevatedButton(
      onPressed: hasSelection ? () => _handleDownload(context) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        disabledForegroundColor: Colors.grey.shade600,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        hasSelection ? '下载 (${selectionManager.selectionCount})' : '下载',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  void _handleDownload(BuildContext context) async {
    // 获取选中的资源ID
    final selectedIds = selectionManager.selectedResIds;

    debugPrint('=== 开始下载流程 ===');
    debugPrint('选中的ID数量: ${selectedIds.length}');
    debugPrint('选中的ID列表: $selectedIds');

    // 通过ID获取资源对象
    final selectedResources = dataManager.getResourcesByIds(selectedIds);

    debugPrint('获取到的资源数量: ${selectedResources.length}');

    if (selectedResources.isEmpty) {
      debugPrint('错误: 没有找到对应的资源对象');

      // 显示详细的错误信息
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('下载失败'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('没有找到要下载的资源'),
              const SizedBox(height: 16),
              Text(
                '调试信息：\n'
                    '选中ID数: ${selectedIds.length}\n'
                    '找到资源: ${selectedResources.length}\n'
                    '总资源数: ${dataManager.allResources.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return;
    }

    debugPrint('准备下载资源:');
    for (var resource in selectedResources) {
      debugPrint('  - ${resource.fileName} (${resource.resId})');
    }

    final downloadPath = await AlbumDownloadManager.getDefaultDownloadPath();
    debugPrint('下载路径: $downloadPath');

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DownloadProgressDialog(
        resources: selectedResources,
        savePath: downloadPath,
      ),
    );
  }
}