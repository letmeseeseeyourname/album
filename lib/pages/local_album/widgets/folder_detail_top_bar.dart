// widgets/folder_detail_top_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
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
          Expanded(
            child: _PathNavigation(
              pathSegments: pathSegments,
              onPathSegmentTap: onPathSegmentTap,
            ),
          ),

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
          _ViewModeMenu(viewMode: viewMode, onViewModeChange: onViewModeChange),
        ],
      ),
    );
  }
}

/// 路径导航组件
///
/// 优化：
/// - 当路径层级超过 maxVisibleSegments 时，中间显示 "..."
/// - 点击 "..." 弹出隐藏层级菜单
/// - 目录名超过 maxNameLength 个字符时截断显示
class _PathNavigation extends StatelessWidget {
  final List<String> pathSegments;
  final Function(int) onPathSegmentTap;

  /// 最大可见层级数（包括第一个和最后显示的几个）
  static const int maxVisibleSegments = 4;

  /// 目录名最大显示长度
  static const int maxNameLength = 20;

  const _PathNavigation({
    required this.pathSegments,
    required this.onPathSegmentTap,
  });

  /// 截断过长的目录名
  String _truncateName(String name, {int maxLength = maxNameLength}) {
    if (name.length <= maxLength) return name;
    return '${name.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    final totalSegments = pathSegments.length;

    // 如果层级数不超过最大可见数，直接显示所有层级
    if (totalSegments <= maxVisibleSegments) {
      return _buildFullPath();
    }

    // 层级过多时，显示：第一个 + ... + 最后几个
    return _buildCollapsedPath(context);
  }

  /// 构建完整路径（不折叠）
  Widget _buildFullPath() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < pathSegments.length; i++) ...[
            _PathSegment(
              text: i == 0 ? '此电脑' : _truncateName(pathSegments[i]),
              isLast: i == pathSegments.length - 1,
              onTap: () => onPathSegmentTap(i),
            ),
            if (i < pathSegments.length - 1)
              const Text(' / ', style: TextStyle(fontSize: 16)),
          ],
        ],
      ),
    );
  }

  /// 构建折叠路径（显示 ... 按钮）
  Widget _buildCollapsedPath(BuildContext context) {
    // 计算要显示的最后几个层级数量（保留3个可见位置给后面的层级）
    const int tailCount = 3;

    // 隐藏的层级：从索引1开始，到 totalSegments - tailCount
    final int hiddenStart = 1;
    final int hiddenEnd = pathSegments.length - tailCount;
    final List<int> hiddenIndices = List.generate(
      hiddenEnd - hiddenStart,
      (i) => hiddenStart + i,
    );

    // 要显示的最后几个层级的起始索引
    final int tailStart = pathSegments.length - tailCount;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 第一个层级（此电脑）
          _PathSegment(
            text: '此电脑',
            isLast: false,
            onTap: () => onPathSegmentTap(0),
          ),
          const Text(' / ', style: TextStyle(fontSize: 16)),

          // 2. "..." 下拉菜单（显示隐藏的层级）
          _CollapsedMenuButton(
            hiddenSegments: hiddenIndices.map((i) => pathSegments[i]).toList(),
            hiddenIndices: hiddenIndices,
            onItemTap: onPathSegmentTap,
            maxNameLength: maxNameLength,
          ),
          const Text(' / ', style: TextStyle(fontSize: 16)),

          // 3. 最后几个层级
          for (int i = tailStart; i < pathSegments.length; i++) ...[
            _PathSegment(
              text: _truncateName(pathSegments[i]),
              isLast: i == pathSegments.length - 1,
              onTap: () => onPathSegmentTap(i),
            ),
            if (i < pathSegments.length - 1)
              const Text(' / ', style: TextStyle(fontSize: 16)),
          ],
        ],
      ),
    );
  }
}

/// 折叠菜单按钮（"..." 按钮）
class _CollapsedMenuButton extends StatelessWidget {
  final List<String> hiddenSegments;
  final List<int> hiddenIndices;
  final Function(int) onItemTap;
  final int maxNameLength;

  const _CollapsedMenuButton({
    required this.hiddenSegments,
    required this.hiddenIndices,
    required this.onItemTap,
    required this.maxNameLength,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: '显示更多路径',
      offset: const Offset(0, 30),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
          child: const Text(
            '...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.blue,
            ),
          ),
        ),
      ),
      onSelected: onItemTap,
      itemBuilder: (context) => [
        for (int i = 0; i < hiddenSegments.length; i++)
          PopupMenuItem<int>(
            value: hiddenIndices[i],
            child: Row(
              children: [
                const Icon(Icons.folder_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _truncateName(hiddenSegments[i]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _truncateName(String name) {
    if (name.length <= maxNameLength) return name;
    return '${name.substring(0, maxNameLength)}...';
  }
}

/// 路径段
class _PathSegment extends StatefulWidget {
  final String text;
  final bool isLast;
  final VoidCallback onTap;

  const _PathSegment({
    required this.text,
    required this.isLast,
    required this.onTap,
  });

  @override
  State<_PathSegment> createState() => _PathSegmentState();
}

class _PathSegmentState extends State<_PathSegment> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Text(
          widget.text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: widget.isLast ? Colors.black : Colors.blue,
            decoration: (!widget.isLast && _isHovered)
                ? TextDecoration.underline
                : null,
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

  const _SelectAllButton({required this.isChecked, required this.onToggle});

  // 定义 SVG 文件的路径
  static const String _selectedIconPath = 'assets/icons/selected_all_icon.svg';
  static const String _unselectedIconPath =
      'assets/icons/unselect_all_icon.svg';

  @override
  Widget build(BuildContext context) {
    final String iconPath = isChecked ? _selectedIconPath : _unselectedIconPath;
    return IconButton(
      icon: SvgPicture.asset(
        iconPath,
        width: 20, // 设置 SVG 宽度，与默认 Icon 大小相似
        height: 20, // 设置 SVG 高度
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
      icon: SvgPicture.asset(
        'assets/icons/screening .svg',
        width: 20,
        height: 20,
      ),
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

  const _ViewModeMenu({required this.viewMode, required this.onViewModeChange});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ViewMode>(
      icon: Icon(_getViewModeIcon()),
      tooltip: '视图模式',
      offset: const Offset(0, 45),
      onSelected: onViewModeChange,
      itemBuilder: (context) => [
        _buildViewModeItem(
          ViewMode.equalHeight,
          '等高',
          Icons.view_column_outlined,
        ),
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
