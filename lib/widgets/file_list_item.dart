// widgets/file_list_item.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../models/file_item.dart';
/// 详情界面文件列表
/// 列表视图的文件项组件
class FileListItem extends StatefulWidget {
  final FileItem item;
  final bool isSelected;
  final bool canSelect;
  final VoidCallback onTap;
  final VoidCallback onCheckboxToggle;

  const FileListItem({
    super.key,
    required this.item,
    required this.isSelected,
    required this.canSelect,
    required this.onTap,
    required this.onCheckboxToggle,
  });

  @override
  State<FileListItem> createState() => _FileListItemState();
}

class _FileListItemState extends State<FileListItem> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.orange.shade50
                : (isHovered ? Colors.grey.shade50 : Colors.transparent),
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              // 复选框（只在可选择时显示）
              if (widget.canSelect)
                GestureDetector(
                  onTap: widget.onCheckboxToggle,
                  child: Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: widget.isSelected ? Colors.orange : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.isSelected ? Colors.orange : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: widget.isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                )
              else
                const SizedBox(width: 36),

              // 图标
              _buildIcon(),
              const SizedBox(width: 12),

              // 文件名
              Expanded(
                flex: 3,
                child: Text(
                  widget.item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 大小
              Expanded(
                flex: 1,
                child: Text(
                  widget.item.type == FileItemType.folder ? '-' : widget.item.formattedSize,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),

              const SizedBox(width: 20),

              // 类型
              Expanded(
                flex: 1,
                child: Text(
                  _getTypeText(),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    switch (widget.item.type) {
      case FileItemType.folder:
        return SizedBox(
          width: 32,
          height: 32,
          child: SvgPicture.asset(
            'assets/icons/folder_icon.svg',
            fit: BoxFit.contain,
          ),
        );
      case FileItemType.image:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(
              File(widget.item.path),
              fit: BoxFit.cover,
              cacheWidth: 64,
              cacheHeight: 64,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.image, size: 20, color: Colors.grey);
              },
            ),
          ),
        );
      case FileItemType.video:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(Icons.videocam, size: 20, color: Colors.grey.shade600),
        );
    }
  }

  String _getTypeText() {
    switch (widget.item.type) {
      case FileItemType.folder:
        return '文件夹';
      case FileItemType.image:
        return 'JPG';
      case FileItemType.video:
        return 'MP4';
    }
  }
}