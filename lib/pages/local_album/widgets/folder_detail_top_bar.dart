// widgets/folder_detail_top_bar.dart
import 'package:flutter/material.dart';
import 'views/file_view_factory.dart';

/// 文件夹详情页顶部工具栏
///
/// 功能：
/// - 路径导航
/// - 取消选择（橙色文字）
/// - 全选切换
/// - 筛选菜单
/// - 视图模式切换
class FolderDetailTopBar extends StatelessWidget {
  final List<String> pathSegments;
  final Function(int) onPathSegmentTap;
  final bool isSelectAllChecked;
  final VoidCallback onSelectAllToggle;
  final String filterType;
  final Function(String) onFilterChange;
  final ViewMode viewMode;
  final Function(ViewMode) onViewModeChange;
  final bool isUploading;
  final int selectedCount;
  final VoidCallback? onCancelSelection;

  const FolderDetailTopBar({
    super.key,
    required this.pathSegments,
    required this.onPathSegmentTap,
    required this.isSelectAllChecked,
    required this.onSelectAllToggle,
    required this.filterType,
    required this.onFilterChange,
    required this.viewMode,
    required this.onViewModeChange,
    required this.isUploading,
    this.selectedCount = 0,
    this.onCancelSelection,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: Row(
        children: [
          // 路径导航
          Expanded(child: _PathNavigation(
            pathSegments: pathSegments,
            onPathSegmentTap: onPathSegmentTap,
          )),

          // "取消选择" 文字
          if (selectedCount > 0 && onCancelSelection != null) ...[
            _CancelSelectionText(onTap: onCancelSelection!),
            const SizedBox(width: 16),
          ],

          // 全选按钮
          _SelectAllButton(
            isChecked: isSelectAllChecked,
            onToggle: onSelectAllToggle,
          ),

          // 筛选菜单
          _FilterMenu(
            filterType: filterType,
            onFilterChange: onFilterChange,
            enabled: !isUploading,
          ),

          const SizedBox(width: 8),

          // 视图模式切换菜单
          _ViewModeMenu(
            viewMode: viewMode,
            onViewModeChange: onViewModeChange,
          ),
        ],
      ),
    );
  }
}

/// 路径导航组件
class _PathNavigation extends StatelessWidget {
  final List<String> pathSegments;
  final Function(int) onPathSegmentTap;

  const _PathNavigation({
    required this.pathSegments,
    required this.onPathSegmentTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (int i = 0; i < pathSegments.length; i++) ...[
          _PathSegment(
            text: i == 0 ? '此电脑' : pathSegments[i],
            isLast: i == pathSegments.length - 1,
            onTap: () => onPathSegmentTap(i),
          ),
          if (i < pathSegments.length - 1)
            const Text(' / ', style: TextStyle(fontSize: 16)),
        ],
      ],
    );
  }
}

/// 路径段
class _PathSegment extends StatelessWidget {
  final String text;
  final bool isLast;
  final VoidCallback onTap;

  const _PathSegment({
    required this.text,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isLast ? Colors.black : Colors.blue,
            decoration: isLast ? null : TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

/// 取消选择文字按钮
class _CancelSelectionText extends StatelessWidget {
  final VoidCallback onTap;

  const _CancelSelectionText({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: const Text(
          '取消选择',
          style: TextStyle(
            fontSize: 14,
            color: Colors.orange,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 全选按钮
class _SelectAllButton extends StatelessWidget {
  final bool isChecked;
  final VoidCallback onToggle;

  const _SelectAllButton({
    required this.isChecked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isChecked ? Icons.check_box : Icons.check_box_outline_blank,
      ),
      onPressed: onToggle,
      tooltip: isChecked ? '取消全选' : '全选',
    );
  }
}

/// 筛选菜单
class _FilterMenu extends StatelessWidget {
  final String filterType;
  final Function(String) onFilterChange;
  final bool enabled;

  const _FilterMenu({
    required this.filterType,
    required this.onFilterChange,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.filter_list),
      tooltip: '筛选',
      offset: const Offset(0, 45),
      enabled: enabled,
      onSelected: onFilterChange,
      itemBuilder: (context) => [
        _buildFilterItem('all', '全部'),
        _buildFilterItem('image', '照片'),
        _buildFilterItem('video', '视频'),
      ],
    );
  }

  PopupMenuItem<String> _buildFilterItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (filterType == value)
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

/// 视图模式菜单
class _ViewModeMenu extends StatelessWidget {
  final ViewMode viewMode;
  final Function(ViewMode) onViewModeChange;

  const _ViewModeMenu({
    required this.viewMode,
    required this.onViewModeChange,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ViewMode>(
      icon: Icon(_getViewModeIcon()),
      tooltip: '视图模式',
      offset: const Offset(0, 45),
      onSelected: onViewModeChange,
      itemBuilder: (context) => [
        _buildViewModeItem(ViewMode.equalHeight, '等高', Icons.view_column_outlined),
        _buildViewModeItem(ViewMode.grid, '方形', Icons.grid_view),
        const PopupMenuDivider(),
        _buildViewModeItem(ViewMode.list, '列表', Icons.list),
      ],
    );
  }

  IconData _getViewModeIcon() {
    switch (viewMode) {
      case ViewMode.equalHeight:
        return Icons.view_column_outlined;
      case ViewMode.grid:
        return Icons.grid_view;
      case ViewMode.list:
        return Icons.list;
    }
  }

  PopupMenuItem<ViewMode> _buildViewModeItem(
      ViewMode value,
      String label,
      IconData icon,
      ) {
    final isSelected = viewMode == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (isSelected)
            const Icon(Icons.check, size: 20, color: Colors.orange)
          else
            const SizedBox(width: 20),
          const SizedBox(width: 12),
          Icon(icon, size: 20, color: isSelected ? Colors.orange : Colors.grey),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.orange : Colors.black,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}