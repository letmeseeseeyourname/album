// widgets/folder_detail_top_bar.dart
import 'package:flutter/material.dart';

/// 文件夹详情页顶部工具栏
class FolderDetailTopBar extends StatelessWidget {
  final List<String> pathSegments;
  final Function(int) onPathSegmentTap;
  final bool isSelectAllChecked;
  final VoidCallback onSelectAllToggle;
  final String filterType;
  final Function(String) onFilterChange;
  final bool isGridView;
  final Function(bool) onViewModeChange;
  final bool isUploading;

  const FolderDetailTopBar({
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

          // 全选按钮
          IconButton(
            icon: Icon(
              isSelectAllChecked ? Icons.check_box : Icons.check_box_outline_blank,
            ),
            onPressed: onSelectAllToggle,  // ← 始终可用
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
            onPressed: () => onViewModeChange(true),  // ← 始终可用
            tooltip: '网格视图',
          ),
          IconButton(
            icon: Icon(
              Icons.list,
              color: !isGridView ? const Color(0xFF2C2C2C) : Colors.grey,
            ),
            onPressed: () => onViewModeChange(false),  // ← 始终可用
            tooltip: '列表视图',
          ),
        ],
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