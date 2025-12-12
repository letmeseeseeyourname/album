// album/components/album_toolbar.dart (修改版)
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../managers/selection_manager.dart';

/// 相册工具栏组件
/// 负责显示工具栏按钮和选择状态
class AlbumToolbar extends StatelessWidget {
  final SelectionManager selectionManager;
  final bool isGridView;
  final VoidCallback onRefresh;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onToggleView;
  final List<String> allResourceIds;

  const AlbumToolbar({
    super.key,
    required this.selectionManager,
    required this.isGridView,
    required this.onRefresh,
    required this.onToggleSelectAll,
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
        final isAllSelected = selectionManager.selectionCount == allResourceIds.length && allResourceIds.isNotEmpty;

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 左侧标题或选中信息
              _buildLeftSection(hasSelection),
              // 右侧工具按钮
              _buildRightSection(context, hasSelection, isAllSelected),
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
      '亲选相册',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildRightSection(BuildContext context, bool hasSelection, bool isAllSelected) {
    if (hasSelection) {
      // 有选中项时显示的按钮
      return Row(
        children: [
          TextButton(
            onPressed: onClearSelection,
            child: const Text(
              '取消选择',
              style: TextStyle(color: Colors.orange),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: onRefresh,
            tooltip: '刷新',
          ),
          // 🆕 全选/取消全选按钮（使用SVG图标）
          IconButton(
            icon: SvgPicture.asset(
              isAllSelected
                  ? 'assets/icons/selected_all_icon.svg'
                  : 'assets/icons/unselect_all_icon.svg',
              width: 20,
              height: 20,
            ),
            onPressed: onToggleSelectAll,
            tooltip: isAllSelected ? '取消全选' : '全选',
          ),
          const SizedBox(width: 8),
          // 🆕 视图切换按钮（新样式）
          _buildViewSwitcher(),
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
        // 🆕 全选按钮（使用SVG图标）
        IconButton(
          icon: SvgPicture.asset(
            'assets/icons/unselect_all_icon.svg',
            width: 20,
            height: 20,
          ),
          onPressed: onToggleSelectAll,
          tooltip: '全选',
        ),
        const SizedBox(width: 8),
        // 🆕 视图切换按钮（新样式）
        _buildViewSwitcher(),
      ],
    );
  }

  // 🆕 构建视图切换器（新样式）
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
            onTap: () {
              if (!isGridView) {
                onToggleView();
              }
            },
            isLeft: true,
          ),
          // 列表视图按钮
          _buildViewButton(
            isSelected: !isGridView,
            iconPath: 'assets/icons/list_view.svg',
            onTap: () {
              if (isGridView) {
                onToggleView();
              }
            },
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
}