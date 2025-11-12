import 'package:flutter/material.dart';
import '../manager/file_manager.dart';

/// 顶部工具栏组件 - 包含过滤、视图切换和选择操作
class FileToolBar extends StatelessWidget {
  final FileFilterType filterType;
  final bool isGridView;
  final bool isSelectionMode;
  final bool isAllSelected;
  final int selectedCount;
  final VoidCallback onFilterChanged;
  final VoidCallback onViewToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;

  const FileToolBar({
    super.key,
    required this.filterType,
    required this.isGridView,
    required this.isSelectionMode,
    required this.isAllSelected,
    required this.selectedCount,
    required this.onFilterChanged,
    required this.onViewToggle,
    required this.onSelectAll,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // 过滤器
          _buildFilterSection(context),

          const Spacer(),

          // 选择操作
          if (isSelectionMode) ...[
            _buildSelectionActions(),
            const SizedBox(width: 20),
          ],

          // 视图切换
          _buildViewToggle(),
        ],
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context) {
    return Row(
      children: [
        const Text(
          '筛选：',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<FileFilterType>(
          offset: const Offset(0, 40),
          itemBuilder: (context) => [
            _buildFilterMenuItem(
              FileFilterType.all,
              '全部',
              Icons.filter_none,
            ),
            _buildFilterMenuItem(
              FileFilterType.image,
              '图片',
              Icons.image,
            ),
            _buildFilterMenuItem(
              FileFilterType.video,
              '视频',
              Icons.videocam,
            ),
          ],
          onSelected: (type) {
            if (type != filterType) {
              onFilterChanged();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getFilterIcon(filterType),
                  size: 16,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  _getFilterText(filterType),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: Colors.grey.shade700,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  PopupMenuItem<FileFilterType> _buildFilterMenuItem(
      FileFilterType type,
      String text,
      IconData icon,
      ) {
    final isSelected = type == filterType;
    return PopupMenuItem(
      value: type,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.blue : Colors.grey.shade700,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isSelected ? Colors.blue : Colors.black,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const Spacer(),
          if (isSelected)
            const Icon(
              Icons.check,
              size: 16,
              color: Colors.blue,
            ),
        ],
      ),
    );
  }

  Widget _buildSelectionActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '已选 $selectedCount 项',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 16),
        TextButton.icon(
          onPressed: onSelectAll,
          icon: Icon(
            isAllSelected ? Icons.check_box : Icons.check_box_outline_blank,
            size: 18,
          ),
          label: Text(isAllSelected ? '取消全选' : '全选'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue,
            textStyle: const TextStyle(fontSize: 14),
          ),
        ),
        if (selectedCount > 0) ...[
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onClearSelection,
            icon: const Icon(Icons.clear, size: 18),
            label: const Text('清空'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              textStyle: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildViewToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewButton(
            icon: Icons.grid_view,
            isSelected: isGridView,
            onTap: isGridView ? null : onViewToggle,
            tooltip: '网格视图',
          ),
          Container(
            width: 1,
            height: 24,
            color: Colors.grey.shade300,
          ),
          _buildViewButton(
            icon: Icons.view_list,
            isSelected: !isGridView,
            onTap: !isGridView ? null : onViewToggle,
            tooltip: '列表视图',
          ),
        ],
      ),
    );
  }

  Widget _buildViewButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback? onTap,
    required String tooltip,
  }) {
    return InkWell(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.all(8),
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          child: Icon(
            icon,
            size: 20,
            color: isSelected ? Colors.blue : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  IconData _getFilterIcon(FileFilterType type) {
    switch (type) {
      case FileFilterType.all:
        return Icons.filter_none;
      case FileFilterType.image:
        return Icons.image;
      case FileFilterType.video:
        return Icons.videocam;
    }
  }

  String _getFilterText(FileFilterType type) {
    switch (type) {
      case FileFilterType.all:
        return '全部';
      case FileFilterType.image:
        return '图片';
      case FileFilterType.video:
        return '视频';
    }
  }
}