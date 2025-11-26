// widgets/items/video_item.dart
import 'package:flutter/material.dart';
import '../../../../models/file_item.dart';
import '../common/media_item_wrapper.dart';
import '../common/video_thumbnail.dart';
import '../common/selection_checkbox.dart';

/// 视频项目组件
///
/// 用于网格视图和等高视图中显示视频
class VideoItem extends StatelessWidget {
  final FileItem item;
  final double? width;
  final double? height;
  final bool isSelected;
  final bool showCheckbox;
  final String? thumbnailPath;
  final bool isLoadingThumbnail;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onCheckboxToggle;
  final CheckboxPosition checkboxPosition;
  final BorderRadius borderRadius;

  const VideoItem({
    super.key,
    required this.item,
    this.width,
    this.height,
    required this.isSelected,
    this.showCheckbox = false,
    this.thumbnailPath,
    this.isLoadingThumbnail = false,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onCheckboxToggle,
    this.checkboxPosition = CheckboxPosition.topRight,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: MediaItemWrapper(
        isSelected: isSelected,
        showCheckbox: showCheckbox,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress,
        onCheckboxToggle: onCheckboxToggle,
        checkboxPosition: checkboxPosition,
        borderRadius: borderRadius,
        child: VideoThumbnail(
          thumbnailPath: thumbnailPath,
          isLoading: isLoadingThumbnail,
          width: width,
          height: height,
          showPlayButton: true,
          showVideoLabel: true,
          labelPosition: VideoLabelPosition.bottomLeft,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

/// 视频列表项组件
///
/// 用于列表视图中显示视频
class VideoListItem extends StatefulWidget {
  final FileItem item;
  final bool isSelected;
  final bool canSelect;
  final String? thumbnailPath;
  final bool isLoadingThumbnail;
  final VoidCallback? onTap;
  final VoidCallback? onCheckboxToggle;

  const VideoListItem({
    super.key,
    required this.item,
    required this.isSelected,
    this.canSelect = false,
    this.thumbnailPath,
    this.isLoadingThumbnail = false,
    this.onTap,
    this.onCheckboxToggle,
  });

  @override
  State<VideoListItem> createState() => _VideoListItemState();
}

class _VideoListItemState extends State<VideoListItem> {
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

              // 视频缩略图
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: _buildThumbnail(),
                ),
              ),

              const SizedBox(width: 16),

              // 文件信息
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
                      _getFileInfo(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 缩略图
        if (widget.thumbnailPath != null)
          ImageThumbnail(
            imagePath: widget.thumbnailPath!,
            width: 44,
            height: 44,
          )
        else if (widget.isLoadingThumbnail)
          Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          Container(
            color: Colors.grey.shade300,
            child: Icon(
              Icons.videocam,
              color: Colors.grey.shade500,
              size: 20,
            ),
          ),

        // 播放图标
        Center(
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 14,
            ),
          ),
        ),
      ],
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

  String _getFileInfo() {
    final ext = widget.item.path.split('.').last.toUpperCase();
    final sizeMB = widget.item.size / (1024 * 1024);
    return '$ext • ${sizeMB.toStringAsFixed(2)} MB';
  }
}