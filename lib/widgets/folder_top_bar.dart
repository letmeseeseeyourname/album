// widgets/folder_top_bar.dart
import 'package:flutter/material.dart';
import '../controllers/folder_controller.dart';
import '../controllers/selection_controller.dart';

/// 文件夹顶部工具栏
class FolderTopBar extends StatelessWidget {
  final FolderController folderController;
  final SelectionController selectionController;
  final VoidCallback? onNavigateBack;
  final bool isUploading;

  const FolderTopBar({
    super.key,
    required this.folderController,
    required this.selectionController,
    this.onNavigateBack,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: Row(
        children: [
          // 面包屑导航
          Expanded(
            child: _BreadcrumbNavigation(
              pathSegments: folderController.pathSegments,
              onSegmentTap: (index) {
                if (index == 0 && onNavigateBack != null) {
                  onNavigateBack!();
                } else {
                  folderController.navigateToPathSegment(index);
                }
              },
            ),
          ),

          // 全选按钮
          IconButton(
            icon: Icon(
              selectionController.selectedIndices.length ==
                  selectionController.getSelectableCount() &&
                  selectionController.selectedIndices.isNotEmpty
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
            ),
            onPressed: isUploading
                ? null
                : () => selectionController.toggleSelectAll(
              folderController.fileItems.length,
            ),
            tooltip: selectionController.selectedIndices.length ==
                selectionController.getSelectableCount() &&
                selectionController.selectedIndices.isNotEmpty
                ? '取消全选'
                : '全选',
          ),

          // 筛选菜单
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: '筛选',
            offset: const Offset(0, 45),
            enabled: !isUploading,
            onSelected: (value) {
              folderController.setFilterType(value);
              selectionController.clearSelection();
            },
            itemBuilder: (context) => [
              _buildFilterMenuItem('all', '全部', folderController.filterType),
              _buildFilterMenuItem('image', '照片', folderController.filterType),
              _buildFilterMenuItem('video', '视频', folderController.filterType),
            ],
          ),

          // 网格视图按钮
          IconButton(
            icon: Icon(
              Icons.grid_view,
              color: folderController.isGridView
                  ? const Color(0xFF2C2C2C)
                  : Colors.grey,
            ),
            onPressed: isUploading
                ? null
                : () => folderController.setViewMode(true),
            tooltip: '网格视图',
          ),

          // 列表视图按钮
          IconButton(
            icon: Icon(
              Icons.list,
              color: !folderController.isGridView
                  ? const Color(0xFF2C2C2C)
                  : Colors.grey,
            ),
            onPressed: isUploading
                ? null
                : () => folderController.setViewMode(false),
            tooltip: '列表视图',
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildFilterMenuItem(
      String value,
      String label,
      String currentFilter,
      ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (currentFilter == value)
            const Icon(Icons.check, size: 20, color: Colors.orange)
          else
            const SizedBox(width: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}

/// 面包屑导航组件
class _BreadcrumbNavigation extends StatelessWidget {
  final List<String> pathSegments;
  final Function(int) onSegmentTap;

  const _BreadcrumbNavigation({
    required this.pathSegments,
    required this.onSegmentTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (int i = 0; i < pathSegments.length; i++) ...[
          GestureDetector(
            onTap: () => onSegmentTap(i),
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
    );
  }
}