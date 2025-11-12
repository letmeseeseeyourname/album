// album/components/album_toolbar.dart
import 'package:flutter/material.dart';
import '../managers/selection_manager.dart';

/// 相册工具栏组件
/// 负责显示工具栏按钮和选择状态
class AlbumToolbar extends StatelessWidget {
  final SelectionManager selectionManager;
  final bool isGridView;
  final VoidCallback onRefresh;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onToggleView;
  final List<String> allResourceIds;

  const AlbumToolbar({
    super.key,
    required this.selectionManager,
    required this.isGridView,
    required this.onRefresh,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onToggleView,
    required this.allResourceIds,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: selectionManager,
      builder: (context, child) {
        final hasSelection = selectionManager.hasSelection;

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 左侧标题或选中信息
              _buildLeftSection(hasSelection),
              // 右侧工具按钮
              _buildRightSection(context, hasSelection),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeftSection(bool hasSelection) {
    if (hasSelection) {
      return Row(
        children: [
          Text(
            '已选择 ${selectionManager.selectionCount} 项',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return const Text(
      '相册图库',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildRightSection(BuildContext context, bool hasSelection) {
    if (hasSelection) {
      // 有选中项时显示的按钮
      return Row(
        children: [
          TextButton(
            onPressed: onClearSelection,
            child: const Text(
              '取消选择',
              style: TextStyle(color: Colors.black87),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: onRefresh,
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.select_all, size: 20),
            onPressed: () {
              selectionManager.selectAll(allResourceIds);
            },
            tooltip: '全选',
          ),
          IconButton(
            icon: Icon(
              isGridView ? Icons.view_list : Icons.grid_view,
              size: 20,
            ),
            onPressed: onToggleView,
            tooltip: isGridView ? '列表视图' : '网格视图',
          ),
        ],
      );
    }

    // 没有选中项时显示的按钮
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: onRefresh,
          tooltip: '刷新',
        ),
        IconButton(
          icon: const Icon(Icons.select_all, size: 20),
          onPressed: () {
            selectionManager.selectAll(allResourceIds);
          },
          tooltip: '全选',
        ),
        IconButton(
          icon: Icon(
            isGridView ? Icons.view_list : Icons.grid_view,
            size: 20,
          ),
          onPressed: onToggleView,
          tooltip: isGridView ? '列表视图' : '网格视图',
        ),
      ],
    );
  }
}