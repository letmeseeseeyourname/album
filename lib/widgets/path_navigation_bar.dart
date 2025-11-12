import 'package:flutter/material.dart';

/// 路径导航栏组件 - 显示面包屑导航
class PathNavigationBar extends StatelessWidget {
  final List<String> pathSegments;
  final Function(int) onPathTap;
  final bool canNavigateBack;
  final VoidCallback? onNavigateBack;

  const PathNavigationBar({
    super.key,
    required this.pathSegments,
    required this.onPathTap,
    this.canNavigateBack = false,
    this.onNavigateBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // 返回按钮
          if (canNavigateBack && onNavigateBack != null) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onNavigateBack,
              tooltip: '返回上级目录',
            ),
            const SizedBox(width: 10),
          ],

          // 面包屑导航
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _buildBreadcrumbs(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBreadcrumbs() {
    final widgets = <Widget>[];

    for (int i = 0; i < pathSegments.length; i++) {
      final isLast = i == pathSegments.length - 1;

      widgets.add(
        InkWell(
          onTap: isLast ? null : () => onPathTap(i),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            child: Text(
              pathSegments[i],
              style: TextStyle(
                fontSize: 14,
                color: isLast ? Colors.black : Colors.blue,
                fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      );

      if (!isLast) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.chevron_right,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ),
        );
      }
    }

    return widgets;
  }
}