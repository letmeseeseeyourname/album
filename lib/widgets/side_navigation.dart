// widgets/side_navigation.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../user/models/group.dart';

class SideNavigation extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onNavigationChanged;
  final List<Group>? groups;
  final Group? selectedGroup;
  final Function(Group)? onGroupSelected;
  final int? currentUserId;

  const SideNavigation({
    super.key,
    required this.selectedIndex,
    required this.onNavigationChanged,
    this.groups,
    this.selectedGroup,
    this.onGroupSelected,
    this.currentUserId,
  });

  @override
  State<SideNavigation> createState() => _SideNavigationState();
}

class _SideNavigationState extends State<SideNavigation> {
  int? _hoveredGroupIndex;

  // 获取排序后的groups（当前用户所属的group排在第一位）
  List<Group> _getSortedGroups() {
    if (widget.groups == null || widget.currentUserId == null) {
      return widget.groups ?? [];
    }

    List<Group> sortedGroups = List.from(widget.groups!);

    // 找到当前用户所属的group
    int userGroupIndex = sortedGroups.indexWhere((group) {
      if (group.users == null) return false;
      return group.users!.any((user) => user.userId == widget.currentUserId);
    });

    // 如果找到，将其移到第一位
    if (userGroupIndex > 0) {
      Group userGroup = sortedGroups.removeAt(userGroupIndex);
      sortedGroups.insert(0, userGroup);
    }

    return sortedGroups;
  }

  // 获取group名字的第一个字
  String _getGroupInitial(Group group) {
    String name = group.groupName ?? '';
    if (name.isEmpty) return '?';
    return name.substring(0, 1);
  }

  // 检查当前用户是否属于这个group
  bool _isUserInGroup(Group group) {
    if (widget.currentUserId == null || group.users == null) {
      return false;
    }
    return group.users!.any((user) => user.userId == widget.currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      color: const Color(0xFFF5E8DC),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // 导航按钮
          NavButton(
            svgPath: 'assets/icons/local_icon.svg',
            label: '此电脑',
            isSelected: widget.selectedIndex == 0,
            onTap: () => widget.onNavigationChanged(0),
          ),
          NavButton(
            svgPath: 'assets/icons/cloud_icon.svg',
            label: '相册图库',
            isSelected: widget.selectedIndex == 1,
            onTap: () => widget.onNavigationChanged(1),
          ),

          const Spacer(),

          // Group列表 - 底部
          if (widget.groups != null &&
              widget.groups!.isNotEmpty &&
              widget.onGroupSelected != null)
            _buildGroupsList(),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // 构建Group列表
  Widget _buildGroupsList() {
    final sortedGroups = _getSortedGroups();

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sortedGroups.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final group = sortedGroups[index];
          final isSelected = widget.selectedGroup?.groupId == group.groupId;
          final isUserGroup = _isUserInGroup(group);
          final initial = _getGroupInitial(group);

          return MouseRegion(
            onEnter: (_) => setState(() => _hoveredGroupIndex = index),
            onExit: (_) => setState(() => _hoveredGroupIndex = null),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Group按钮 - 圆角矩形
                GestureDetector(
                  onTap: () {
                    if (!isSelected) {
                      widget.onGroupSelected!(group);
                    }
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected || isUserGroup
                          ? Colors.black
                          : Colors.white,
                      border: Border.all(
                        color: Colors.black,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(6), // 圆角矩形
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: isSelected || isUserGroup
                              ? Colors.white
                              : Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                // 悬浮提示框 - 智能定位，避免超出边界
                if (_hoveredGroupIndex == index)
                  Positioned(
                    bottom: 40,
                    left: index == 0 ? 0 : -20, // 第一个按钮左对齐，其他按钮居中
                    child: _buildTooltip(group),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 构建悬浮提示框
  Widget _buildTooltip(Group group) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 100,
          maxWidth: 180,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              group.groupName ?? '未命名组',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (group.users != null && group.users!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                '${group.users!.length} 位成员',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NavButton extends StatelessWidget {
  final String svgPath;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const NavButton({
    super.key,
    required this.svgPath,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2C2C2C) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: SizedBox(
          width: 15,
          height: 15,
          child: SvgPicture.asset(
            svgPath,
            colorFilter: ColorFilter.mode(
              isSelected ? Colors.white : Colors.black,
              BlendMode.srcIn,
            ),
            width: 15,
            height: 15,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}