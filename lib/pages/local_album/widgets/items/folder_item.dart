// widgets/items/folder_item.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../../../models/file_item.dart';
import '../common/media_item_wrapper.dart';
import '../common/selection_checkbox.dart';

/// 文件夹项目组件
///
/// 用于网格视图和等高视图中显示文件夹
class FolderItem extends StatelessWidget {
  final FileItem item;
  final double? width;
  final double? height;
  final bool isSelected;
  final bool showCheckbox;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onCheckboxToggle;
  final CheckboxPosition checkboxPosition;

  const FolderItem({
    super.key,
    required this.item,
    this.width,
    this.height,
    required this.isSelected,
    this.showCheckbox = false,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onCheckboxToggle,
    this.checkboxPosition = CheckboxPosition.topRight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: FolderItemWrapper(
        isSelected: isSelected,
        showCheckbox: showCheckbox,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress,
        onCheckboxToggle: onCheckboxToggle,
        checkboxPosition: checkboxPosition,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 文件夹图标
              Expanded(
                flex: 3,
                child: Center(
                  child: _buildFolderIcon(),
                ),
              ),
              const SizedBox(height: 8),
              // 文件夹名称
              Expanded(
                flex: 1,
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderIcon() {
    // final iconWidth = (width ?? 140) * 0.5;
    final iconWidth = 105.0;
    // final iconHeight = (height ?? 140) * 0.4;
    final iconHeight = 84.0;

    return SvgPicture.asset(
      'assets/icons/folder_icon.svg',
      width: iconWidth,
      height: iconHeight,
      fit: BoxFit.contain,
    );
  }
}

/// 文件夹列表项组件
///
/// 用于列表视图中显示文件夹
class FolderListItem extends StatefulWidget {
  final FileItem item;
  final bool isSelected;
  final bool canSelect;
  final VoidCallback? onTap;
  final VoidCallback? onCheckboxToggle;

  const FolderListItem({
    super.key,
    required this.item,
    required this.isSelected,
    this.canSelect = false,
    this.onTap,
    this.onCheckboxToggle,
  });

  @override
  State<FolderListItem> createState() => _FolderListItemState();
}

class _FolderListItemState extends State<FolderListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 60,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.orange.shade50
                : (_isHovered ? Colors.grey.shade50 : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.orange
                  : (_isHovered ? Colors.grey.shade300 : Colors.grey.shade200),
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // 复选框
              if (widget.canSelect || _isHovered || widget.isSelected)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: widget.onCheckboxToggle,
                    child: _buildCheckbox(),
                  ),
                ),

              // 文件夹图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.folder,
                  color: Colors.amber,
                  size: 24,
                ),
              ),

              const SizedBox(width: 16),

              // 文件夹信息
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '文件夹',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // 箭头图标
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: widget.isSelected ? Colors.orange : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.isSelected ? Colors.orange : Colors.grey.shade400,
          width: 2,
        ),
      ),
      child: widget.isSelected
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}