// widgets/side_navigation.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../user/models/group.dart';
import '../user/my_instance.dart';
import '../user/provider/mine_provider.dart';

class SideNavigation extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onNavigationChanged;
  final List<Group>? groups;
  final Group? selectedGroup;
  final Future<void> Function(Group)? onGroupSelected;
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
  bool _isLoading = false;
  int? _loadingGroupIndex;

  // 🆕 拖拽滑动相关
  final ScrollController _groupScrollController = ScrollController();
  bool _isDragging = false;
  double _dragStartX = 0;
  double _scrollStartOffset = 0;

  // 🆕 Overlay提示框相关
  OverlayEntry? _tooltipOverlay;
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void dispose() {
    _removeTooltip();
    _groupScrollController.dispose();
    super.dispose();
  }

  // 🆕 显示提示框（智能定位，避免超出屏幕边缘）
  void _showTooltip(int index, Group group) {
    _removeTooltip();

    final key = _itemKeys[index];
    if (key?.currentContext == null) return;

    final RenderBox renderBox = key!.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // 计算提示框文本宽度（估算）
    final tooltipText = '${group.groupName ?? '未命名'}的家庭圈';
    final estimatedWidth = tooltipText.length * 12.0 + 24; // 字体12 + padding

    // 按钮中心位置
    final buttonCenterX = position.dx + size.width / 2;

    // 计算提示框左边缘位置，使小三角对准按钮中心
    double tooltipLeft = buttonCenterX - estimatedWidth / 2;

    // 🆕 确保提示框不超出左边界（留8px边距）
    if (tooltipLeft < 8) {
      tooltipLeft = 8;
    }

    // 计算小三角相对于提示框的偏移量
    final triangleOffset = buttonCenterX - tooltipLeft - 6; // 6是三角形宽度的一半

    _tooltipOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: tooltipLeft,
        top: position.dy - 50, // 提示框在按钮上方，增加间距
        child: _buildTooltipContent(group, triangleOffset),
      ),
    );

    Overlay.of(context).insert(_tooltipOverlay!);
  }

  // 🆕 移除提示框
  void _removeTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
  }

  // 获取排序后的groups（当前deviceCode对应的group排在第一位）
  List<Group> _getSortedGroups() {
    if (widget.groups == null || widget.groups!.isEmpty) {
      return widget.groups ?? [];
    }

    List<Group> sortedGroups = List.from(widget.groups!);
    String currentDeviceCode = MyInstance().deviceCode;

    int currentGroupIndex = sortedGroups.indexWhere((group) {
      return group.deviceCode == currentDeviceCode;
    });

    if (currentGroupIndex > 0) {
      Group currentGroup = sortedGroups.removeAt(currentGroupIndex);
      sortedGroups.insert(0, currentGroup);
    }

    return sortedGroups;
  }

  // 检查group是否是当前连接的（deviceCode匹配）
  bool _isCurrentGroup(Group group) {
    return group.deviceCode == MyInstance().deviceCode;
  }

  // 获取group名字的第一个字
  String _getGroupInitial(Group group) {
    String name = group.groupName ?? '';
    if (name.isEmpty) return '?';
    return name.substring(0, 1);
  }

  // 处理group点击事件（带loading）
  Future<void> _onGroupTap(Group group, int index) async {
    if (_isCurrentGroup(group) || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingGroupIndex = index;
    });

    try {
      if (widget.onGroupSelected != null) {
        await widget.onGroupSelected!(group);
      }
    } catch (e) {
      debugPrint("切换group失败: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingGroupIndex = null;
        });
      }
    }
  }

  // 🆕 处理拖拽开始
  void _onDragStart(DragStartDetails details) {
    _isDragging = true;
    _dragStartX = details.globalPosition.dx;
    _scrollStartOffset = _groupScrollController.offset;
  }

  // 🆕 处理拖拽更新
  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    final delta = _dragStartX - details.globalPosition.dx;
    final newOffset = (_scrollStartOffset + delta).clamp(
      0.0,
      _groupScrollController.position.maxScrollExtent,
    );
    _groupScrollController.jumpTo(newOffset);
  }

  // 🆕 处理拖拽结束
  void _onDragEnd(DragEndDetails details) {
    _isDragging = false;
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
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      // 🆕 使用GestureDetector支持拖拽滑动
      child: GestureDetector(
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: ScrollConfiguration(
          // 🆕 支持鼠标滚轮和拖拽
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
            },
          ),
          child: ListView.separated(
            controller: _groupScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: sortedGroups.length,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final group = sortedGroups[index];
              final isCurrentGroup = _isCurrentGroup(group);
              final initial = _getGroupInitial(group);
              final isLoadingThis = _isLoading && _loadingGroupIndex == index;
              final isHovered = _hoveredGroupIndex == index;

              // 🆕 为每个item创建GlobalKey
              _itemKeys[index] ??= GlobalKey();

              return MouseRegion(
                onEnter: (_) {
                  setState(() => _hoveredGroupIndex = index);
                  if (!_isLoading) {
                    _showTooltip(index, group);
                  }
                },
                onExit: (_) {
                  setState(() => _hoveredGroupIndex = null);
                  _removeTooltip();
                },
                cursor: isCurrentGroup ? SystemMouseCursors.basic : SystemMouseCursors.click,
                child: GestureDetector(
                  key: _itemKeys[index],
                  onTap: _isLoading ? null : () => _onGroupTap(group, index),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isCurrentGroup ? Colors.black : Colors.white,
                      // 🔄 始终有边框，悬浮时显示黑色，否则透明（保持尺寸一致）
                      border: Border.all(
                        color: (isHovered && !isCurrentGroup)
                            ? Colors.black
                            : Colors.transparent,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: isLoadingThis
                          ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isCurrentGroup ? Colors.white : Colors.black,
                          ),
                        ),
                      )
                          : Text(
                        initial,
                        style: TextStyle(
                          color: isCurrentGroup ? Colors.white : Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // 🔄 构建悬浮提示框内容（使用Overlay显示，带小三角，支持动态位置）
  Widget _buildTooltipContent(Group group, double triangleOffset) {
    final tooltipText = '${group.groupName ?? '未命名'}的家庭圈';

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 提示框主体
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF333333),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              tooltipText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // 小三角指向按钮（动态偏移）
          Padding(
            padding: EdgeInsets.only(left: triangleOffset.clamp(8.0, 200.0)),
            child: CustomPaint(
              size: const Size(12, 6),
              painter: _TrianglePainter(color: const Color(0xFF333333)),
            ),
          ),
        ],
      ),
    );
  }
}

// 🆕 绘制小三角的Painter
class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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