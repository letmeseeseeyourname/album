// widgets/folder_grid_component.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/folder_info.dart';

class FolderGridComponent extends StatelessWidget {
  final List<FolderInfo> folders;
  final Set<int> selectedIndices;
  final bool isSelectionMode;
  final Function(int) onFolderTap;
  final Function(int) onFolderLongPress;
  final Function(int) onCheckboxToggle;
  final int? hoveredIndex;
  final Function(int?) onHoverChanged;

  const FolderGridComponent({
    super.key,
    required this.folders,
    required this.selectedIndices,
    required this.isSelectionMode,
    required this.onFolderTap,
    required this.onFolderLongPress,
    required this.onCheckboxToggle,
    required this.hoveredIndex,
    required this.onHoverChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 固定的 items 尺寸
          const itemWidth = 135.0;
          const itemHeight = 120.0;
          const spacing = 10.0;

          // 计算可用宽度
          final availableWidth = constraints.maxWidth;

          // 计算每行可以显示多少个 items
          final crossAxisCount = ((availableWidth + spacing) / (itemWidth + spacing)).floor().clamp(1, 10);

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: itemWidth / itemHeight,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: folders.length,
            itemBuilder: (context, index) {
              return FolderCardWidget(
                folder: folders[index],
                isSelected: selectedIndices.contains(index),
                isSelectionMode: isSelectionMode,
                showCheckbox: isSelectionMode || hoveredIndex == index,
                onTap: () => onFolderTap(index),
                onLongPress: () => onFolderLongPress(index),
                onCheckboxToggle: () => onCheckboxToggle(index),
                onHoverChanged: (isHovered) {
                  onHoverChanged(isHovered ? index : null);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class FolderCardWidget extends StatefulWidget {
  final FolderInfo folder;
  final bool isSelected;
  final bool isSelectionMode;
  final bool showCheckbox;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onCheckboxToggle;
  final Function(bool) onHoverChanged;

  const FolderCardWidget({
    super.key,
    required this.folder,
    required this.isSelected,
    required this.isSelectionMode,
    required this.showCheckbox,
    required this.onTap,
    required this.onLongPress,
    required this.onCheckboxToggle,
    required this.onHoverChanged,
  });

  @override
  State<FolderCardWidget> createState() => _FolderCardWidgetState();
}

class _FolderCardWidgetState extends State<FolderCardWidget> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => isHovered = true);
        widget.onHoverChanged(true);
      },
      onExit: (_) {
        setState(() => isHovered = false);
        widget.onHoverChanged(false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.orange.shade50
                : (isHovered ? Colors.grey.shade50 : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.orange
                  : (isHovered ? Colors.grey.shade300 : Colors.transparent),
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(7.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 文件夹图标 - 固定尺寸
                    SizedBox(
                      width: 80,
                      height: 64,
                      child: SvgPicture.asset(
                        'assets/icons/folder_icon.svg',
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 5),

                    // 文件夹名称 - 固定高度
                    SizedBox(
                      height: 30,
                      child: Center(
                        child: Text(
                          widget.folder.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 复选框 - 根据条件显示
              if (widget.showCheckbox)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: widget.onCheckboxToggle,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: widget.isSelected ? Colors.orange : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.isSelected ? Colors.orange : Colors.grey.shade400,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: widget.isSelected
                            ? const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.white,
                        )
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}