// widgets/common/selection_checkbox.dart
import 'package:flutter/material.dart';

/// 选择框位置
enum CheckboxPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// 通用选择框组件
///
/// 统一的圆形复选框样式，支持动画效果
class SelectionCheckbox extends StatelessWidget {
  /// 是否选中
  final bool isSelected;

  /// 是否可见
  final bool isVisible;

  /// 点击回调
  final VoidCallback onToggle;

  /// 位置
  final CheckboxPosition position;

  /// 尺寸
  final double size;

  /// 边距
  final double margin;

  /// 选中时的颜色
  final Color selectedColor;

  /// 未选中时的背景色
  final Color unselectedColor;

  /// 未选中时的边框色
  final Color borderColor;

  const SelectionCheckbox({
    super.key,
    required this.isSelected,
    required this.isVisible,
    required this.onToggle,
    this.position = CheckboxPosition.topRight,
    this.size = 24.0,
    this.margin = 8.0,
    this.selectedColor = Colors.orange,
    this.unselectedColor = Colors.white,
    this.borderColor = const Color(0xFF9E9E9E), // Colors.grey.shade400
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      top: _isTop ? margin : null,
      bottom: _isBottom ? margin : null,
      left: _isLeft ? margin : null,
      right: _isRight ? margin : null,
      child: GestureDetector(
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: _CheckboxCircle(
            isSelected: isSelected,
            size: size,
            selectedColor: selectedColor,
            unselectedColor: unselectedColor,
            borderColor: borderColor,
          ),
        ),
      ),
    );
  }

  bool get _isTop =>
      position == CheckboxPosition.topLeft || position == CheckboxPosition.topRight;

  bool get _isBottom =>
      position == CheckboxPosition.bottomLeft || position == CheckboxPosition.bottomRight;

  bool get _isLeft =>
      position == CheckboxPosition.topLeft || position == CheckboxPosition.bottomLeft;

  bool get _isRight =>
      position == CheckboxPosition.topRight || position == CheckboxPosition.bottomRight;
}

/// 复选框圆形样式
class _CheckboxCircle extends StatelessWidget {
  final bool isSelected;
  final double size;
  final Color selectedColor;
  final Color unselectedColor;
  final Color borderColor;

  const _CheckboxCircle({
    required this.isSelected,
    required this.size,
    required this.selectedColor,
    required this.unselectedColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isSelected ? selectedColor : unselectedColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? selectedColor : borderColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isSelected ? 1.0 : 0.0,
        child: Icon(
          Icons.check,
          size: size * 0.65,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 独立使用的复选框（非定位）
class SelectionCheckboxStandalone extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onToggle;
  final double size;
  final Color selectedColor;
  final Color unselectedColor;
  final Color borderColor;

  const SelectionCheckboxStandalone({
    super.key,
    required this.isSelected,
    required this.onToggle,
    this.size = 24.0,
    this.selectedColor = Colors.orange,
    this.unselectedColor = Colors.white,
    this.borderColor = const Color(0xFF9E9E9E),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: _CheckboxCircle(
          isSelected: isSelected,
          size: size,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          borderColor: borderColor,
        ),
      ),
    );
  }
}