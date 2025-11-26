// widgets/common/media_item_wrapper.dart
import 'package:flutter/material.dart';
import 'selection_checkbox.dart';

/// 媒体项目包装器
///
/// 统一处理：
/// - 悬停效果
/// - 选中边框
/// - 复选框显示
/// - 点击事件
class MediaItemWrapper extends StatefulWidget {
  /// 子组件（实际内容）
  final Widget child;

  /// 是否选中
  final bool isSelected;

  /// 是否显示复选框
  final bool showCheckbox;

  /// 是否显示悬停效果
  final bool showHoverEffect;

  /// 点击回调
  final VoidCallback? onTap;

  /// 双击回调
  final VoidCallback? onDoubleTap;

  /// 长按回调
  final VoidCallback? onLongPress;

  /// 复选框点击回调
  final VoidCallback? onCheckboxToggle;

  /// 圆角
  final BorderRadius borderRadius;

  /// 选中边框宽度
  final double selectedBorderWidth;

  /// 选中边框颜色
  final Color selectedBorderColor;

  /// 悬停遮罩颜色
  final Color hoverOverlayColor;

  /// 复选框位置
  final CheckboxPosition checkboxPosition;

  const MediaItemWrapper({
    super.key,
    required this.child,
    required this.isSelected,
    this.showCheckbox = false,
    this.showHoverEffect = true,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onCheckboxToggle,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.selectedBorderWidth = 3.0,
    this.selectedBorderColor = Colors.orange,
    this.hoverOverlayColor = const Color(0x1A000000), // Colors.black.withOpacity(0.1)
    this.checkboxPosition = CheckboxPosition.topRight,
  });

  @override
  State<MediaItemWrapper> createState() => _MediaItemWrapperState();
}

class _MediaItemWrapperState extends State<MediaItemWrapper> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 主内容
            ClipRRect(
              borderRadius: widget.borderRadius,
              child: widget.child,
            ),

            // 悬停遮罩
            if (widget.showHoverEffect && _isHovered && !widget.isSelected)
              Container(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  color: widget.hoverOverlayColor,
                ),
              ),

            // 选中边框
            if (widget.isSelected)
              Container(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  border: Border.all(
                    color: widget.selectedBorderColor,
                    width: widget.selectedBorderWidth,
                  ),
                ),
              ),

            // 复选框
            if (widget.onCheckboxToggle != null)
              SelectionCheckbox(
                isSelected: widget.isSelected,
                isVisible: widget.showCheckbox || _isHovered,
                onToggle: widget.onCheckboxToggle!,
                position: widget.checkboxPosition,
              ),
          ],
        ),
      ),
    );
  }
}

/// 文件夹项目包装器（带背景色变化）
class FolderItemWrapper extends StatefulWidget {
  final Widget child;
  final bool isSelected;
  final bool showCheckbox;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onCheckboxToggle;
  final BorderRadius borderRadius;
  final CheckboxPosition checkboxPosition;

  const FolderItemWrapper({
    super.key,
    required this.child,
    required this.isSelected,
    this.showCheckbox = false,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onCheckboxToggle,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.checkboxPosition = CheckboxPosition.topRight,
  });

  @override
  State<FolderItemWrapper> createState() => _FolderItemWrapperState();
}

class _FolderItemWrapperState extends State<FolderItemWrapper> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        child: Stack(
          children: [
            // 背景容器
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? Colors.orange.shade50
                    : (_isHovered ? Colors.grey.shade100 : Colors.transparent),
                borderRadius: widget.borderRadius,
                border: Border.all(
                  color: widget.isSelected
                      ? Colors.orange
                      : (_isHovered ? Colors.grey.shade300 : Colors.grey.shade200),
                  width: widget.isSelected ? 2 : 1,
                ),
              ),
              child: widget.child,
            ),

            // 复选框
            if (widget.onCheckboxToggle != null)
              SelectionCheckbox(
                isSelected: widget.isSelected,
                isVisible: widget.showCheckbox || _isHovered,
                onToggle: widget.onCheckboxToggle!,
                position: widget.checkboxPosition,
              ),
          ],
        ),
      ),
    );
  }
}