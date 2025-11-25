// widgets/folder_detail_top_bar.dart
import 'package:flutter/material.dart';

/// 视图模式枚举
enum ViewMode {
  grid,       // 网格视图
  list,       // 列表视图
  equalHeight // 等高视图
}

/// 文件夹详情页顶部工具栏
///
/// ✅ 更新:
/// - 新增"等高"视图模式按钮
/// - 新增"取消选择"功能（仅显示橙色文字）
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

  // 选中数量和取消选择回调
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
          Expanded(
            child: _buildPathNavigation(),
          ),

          // "取消选择" 文字（当有选中项时显示）
          if (selectedCount > 0 && onCancelSelection != null) ...[
            _buildCancelSelectionText(),
            const SizedBox(width: 16),
          ],

          // 全选按钮
          IconButton(
            icon: Icon(
              isSelectAllChecked ? Icons.check_box : Icons.check_box_outline_blank,
            ),
            onPressed: onSelectAllToggle,
            tooltip: isSelectAllChecked ? '取消全选' : '全选',
          ),

          // 筛选菜单
          _buildFilterMenu(),

          const SizedBox(width: 8),

          // 视图模式切换菜单
          _buildViewModeMenu(),
        ],
      ),
    );
  }

  /// 构建"取消选择"文字按钮（仅橙色文字）
  Widget _buildCancelSelectionText() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onCancelSelection,
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

  Widget _buildPathNavigation() {
    return Wrap(
      spacing: 8,
      children: [
        for (int i = 0; i < pathSegments.length; i++) ...[
          GestureDetector(
            onTap: () => onPathSegmentTap(i),
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

  Widget _buildFilterMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.filter_list),
      tooltip: '筛选',
      offset: const Offset(0, 45),
      enabled: !isUploading,
      onSelected: onFilterChange,
      itemBuilder: (context) => [
        _buildFilterMenuItem('all', '全部'),
        _buildFilterMenuItem('image', '照片'),
        _buildFilterMenuItem('video', '视频'),
      ],
    );
  }

  PopupMenuItem<String> _buildFilterMenuItem(String value, String label) {
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

  /// 视图模式切换菜单
  Widget _buildViewModeMenu() {
    return PopupMenuButton<ViewMode>(
      icon: Icon(_getViewModeIcon()),
      tooltip: '视图模式',
      offset: const Offset(0, 45),
      onSelected: onViewModeChange,
      itemBuilder: (context) => [
        _buildViewModeMenuItem(
          ViewMode.equalHeight,
          '等高',
          Icons.view_column_outlined,
        ),
        _buildViewModeMenuItem(
          ViewMode.grid,
          '方形',
          Icons.grid_view,
        ),
        const PopupMenuDivider(),
        _buildViewModeMenuItem(
          ViewMode.list,
          '列表',
          Icons.list,
        ),
      ],
    );
  }

  /// 获取当前视图模式的图标
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

  PopupMenuItem<ViewMode> _buildViewModeMenuItem(
      ViewMode value,
      String label,
      IconData icon
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

// ============ 向后兼容的旧版 TopBar ============

/// 向后兼容的文件夹详情页顶部工具栏
/// 保持原有的 isGridView/onViewModeChange(bool) 接口
class FolderDetailTopBarLegacy extends StatelessWidget {
  final List<String> pathSegments;
  final Function(int) onPathSegmentTap;
  final bool isSelectAllChecked;
  final VoidCallback onSelectAllToggle;
  final String filterType;
  final Function(String) onFilterChange;
  final bool isGridView;
  final Function(bool) onViewModeChange;
  final bool isUploading;
  final int selectedCount;
  final VoidCallback? onCancelSelection;

  const FolderDetailTopBarLegacy({
    super.key,
    required this.pathSegments,
    required this.onPathSegmentTap,
    required this.isSelectAllChecked,
    required this.onSelectAllToggle,
    required this.filterType,
    required this.onFilterChange,
    required this.isGridView,
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
          Expanded(
            child: _buildPathNavigation(),
          ),

          // "取消选择" 文字
          if (selectedCount > 0 && onCancelSelection != null) ...[
            _buildCancelSelectionText(),
            const SizedBox(width: 16),
          ],

          // 全选按钮
          IconButton(
            icon: Icon(
              isSelectAllChecked ? Icons.check_box : Icons.check_box_outline_blank,
            ),
            onPressed: onSelectAllToggle,
            tooltip: isSelectAllChecked ? '取消全选' : '全选',
          ),

          // 筛选菜单
          _buildFilterMenu(),

          // 视图切换按钮
          IconButton(
            icon: Icon(
              Icons.grid_view,
              color: isGridView ? const Color(0xFF2C2C2C) : Colors.grey,
            ),
            onPressed: () => onViewModeChange(true),
            tooltip: '网格视图',
          ),
          IconButton(
            icon: Icon(
              Icons.list,
              color: !isGridView ? const Color(0xFF2C2C2C) : Colors.grey,
            ),
            onPressed: () => onViewModeChange(false),
            tooltip: '列表视图',
          ),
        ],
      ),
    );
  }

  Widget _buildCancelSelectionText() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onCancelSelection,
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

  Widget _buildPathNavigation() {
    return Wrap(
      spacing: 8,
      children: [
        for (int i = 0; i < pathSegments.length; i++) ...[
          GestureDetector(
            onTap: () => onPathSegmentTap(i),
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

  Widget _buildFilterMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.filter_list),
      tooltip: '筛选',
      offset: const Offset(0, 45),
      enabled: !isUploading,
      onSelected: onFilterChange,
      itemBuilder: (context) => [
        _buildFilterMenuItem('all', '全部'),
        _buildFilterMenuItem('image', '照片'),
        _buildFilterMenuItem('video', '视频'),
      ],
    );
  }

  PopupMenuItem<String> _buildFilterMenuItem(String value, String label) {
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