// widgets/side_navigation.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SideNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onNavigationChanged;

  const SideNavigation({
    super.key,
    required this.selectedIndex,
    required this.onNavigationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      color: const Color(0xFFF5E8DC),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // 导航按钮 - 使用 SVG 图标
          NavButton(
            svgPath: 'assets/icons/local_icon.svg',  // 本地图库 SVG 图标
            label: '本地图库',
            isSelected: selectedIndex == 0,
            onTap: () => onNavigationChanged(0),
          ),

          NavButton(
            svgPath: 'assets/icons/grid_icon.svg',  // 相册图库 SVG 图标
            label: '相册图库',
            isSelected: selectedIndex == 1,
            onTap: () => onNavigationChanged(1),
          ),
        ],
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