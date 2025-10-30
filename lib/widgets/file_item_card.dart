// widgets/file_item_card.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../models/file_item.dart';
import '../services/thumbnail_helper.dart';

///显示详情界面的文件列表item
/// 网格视图的文件卡片组件
class FileItemCard extends StatefulWidget {
  final FileItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onCheckboxToggle;
  final bool isSelected;
  final bool showCheckbox;
  final bool canSelect;

  const FileItemCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onLongPress,
    required this.onCheckboxToggle,
    required this.isSelected,
    required this.showCheckbox,
    required this.canSelect,
  });

  @override
  State<FileItemCard> createState() => _FileItemCardState();
}

class _FileItemCardState extends State<FileItemCard> with AutomaticKeepAliveClientMixin {
  bool isHovered = false;
  String? videoThumbnailPath;
  bool isLoadingThumbnail = false;
  bool _hasAttemptedLoad = false;

  @override
  bool get wantKeepAlive => videoThumbnailPath != null;

  @override
  void initState() {
    super.initState();
    // 延迟生成视频缩略图，等待 widget 构建完成后再加载
    if (widget.item.type == FileItemType.video) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasAttemptedLoad) {
          _generateVideoThumbnail();
        }
      });
    }
  }

  Future<void> _generateVideoThumbnail() async {
    if (isLoadingThumbnail || _hasAttemptedLoad) return;

    setState(() {
      isLoadingThumbnail = true;
      _hasAttemptedLoad = true;
    });

    try {
      print('Generating thumbnail for: ${widget.item.path}');

      final thumbnailPath = await ThumbnailHelper.generateThumbnail(
        widget.item.path,
      );

      print('Thumbnail generated at: $thumbnailPath');

      if (mounted && thumbnailPath != null) {
        // 验证文件是否存在
        final file = File(thumbnailPath);
        if (await file.exists()) {
          print('Thumbnail file exists, size: ${await file.length()} bytes');
          setState(() {
            videoThumbnailPath = thumbnailPath;
            isLoadingThumbnail = false;
          });
          // 更新 keepAlive 状态
          updateKeepAlive();
        } else {
          print('Thumbnail file does not exist');
          setState(() {
            isLoadingThumbnail = false;
          });
        }
      } else {
        if (kDebugMode) {
          print('Thumbnail path is null or widget disposed');
        }
        if (mounted) {
          setState(() {
            isLoadingThumbnail = false;
          });
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error generating video thumbnail: $e');
        print('Stack trace: $stackTrace');
      }
      if (mounted) {
        setState(() {
          isLoadingThumbnail = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // 清理缩略图缓存（可选）
    if (videoThumbnailPath != null) {
      try {
        File(videoThumbnailPath!).delete();
      } catch (e) {
        // 忽略删除错误
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用以支持 AutomaticKeepAliveClientMixin
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: widget.item.type == FileItemType.folder
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: SizedBox(
          // 设置固定宽度和高度，确保所有item尺寸一致
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? Colors.orange.shade50
                      : (isHovered ? Colors.grey.shade100 : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isSelected
                        ? Colors.orange
                        : (isHovered ? Colors.grey.shade300 : Colors.transparent),
                    width: widget.isSelected ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildIcon(),
                    const SizedBox(height: 8),
                    // 使用 Flexible 包裹文本，确保不会溢出
                    Flexible(
                      child: Text(
                        widget.item.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.item.type != FileItemType.folder &&
                        widget.item.formattedSize.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.item.formattedSize,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
              ),
              // 复选框 - 只在可选择时显示
              if (widget.canSelect && (widget.showCheckbox || isHovered || widget.isSelected))
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

  Widget _buildIcon() {
    switch (widget.item.type) {
      case FileItemType.folder:
        return SizedBox(
          width: 80,
          height: 80,  // 统一高度为80，与图片和视频保持一致
          child: Center(
            child: SvgPicture.asset(
              'assets/icons/folder_icon.svg',
              width: 80,
              height: 64,
              fit: BoxFit.contain,
            ),
          ),
        );
      case FileItemType.image:
      // 显示图片缩略图，使用 cacheWidth 和 cacheHeight 优化内存
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(
              File(widget.item.path),
              fit: BoxFit.cover,
              // 关键优化：限制图片解码尺寸，减少内存占用
              cacheWidth: 160, // 2倍显示尺寸用于高清屏
              cacheHeight: 160,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.image, size: 32, color: Colors.grey);
              },
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) {
                  return child;
                }
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: child,
                );
              },
            ),
          ),
        );
      case FileItemType.video:
      // 显示视频首帧缩略图
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (videoThumbnailPath != null)
                  Image.file(
                    File(videoThumbnailPath!),
                    fit: BoxFit.cover,
                    // 优化：限制缩略图解码尺寸
                    cacheWidth: 160,
                    cacheHeight: 160,
                  )
                else if (isLoadingThumbnail)
                  Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  )
                else
                  Icon(Icons.videocam, size: 32, color: Colors.grey.shade600),
                // 播放按钮叠加层
                Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}