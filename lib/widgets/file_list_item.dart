// widgets/file_list_item.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../models/file_item.dart';
import '../services/thumbnail_helper.dart';

/// 详情界面文件列表
/// 列表视图的文件项组件
///
/// ✅ 更新: 添加视频缩略图支持（使用 ThumbnailHelper）
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

class _FileListItemState extends State<FileListItem> with AutomaticKeepAliveClientMixin {
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
      if (kDebugMode) {
        print('FileListItem: Generating thumbnail for: ${widget.item.path}');
      }

      final thumbnailPath = await ThumbnailHelper.generateThumbnail(
        widget.item.path,
      );

      if (kDebugMode) {
        print('FileListItem: Thumbnail generated at: $thumbnailPath');
      }

      if (mounted && thumbnailPath != null) {
        // 验证文件是否存在
        final file = File(thumbnailPath);
        if (await file.exists()) {
          if (kDebugMode) {
            print('FileListItem: Thumbnail file exists, size: ${await file.length()} bytes');
          }
          setState(() {
            videoThumbnailPath = thumbnailPath;
            isLoadingThumbnail = false;
          });
          // 更新 keepAlive 状态
          updateKeepAlive();
        } else {
          if (kDebugMode) {
            print('FileListItem: Thumbnail file does not exist');
          }
          setState(() {
            isLoadingThumbnail = false;
          });
        }
      } else {
        if (kDebugMode) {
          print('FileListItem: Thumbnail path is null or widget disposed');
        }
        if (mounted) {
          setState(() {
            isLoadingThumbnail = false;
          });
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('FileListItem: Error generating video thumbnail: $e');
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
    // 注意：如果使用全局缓存策略，这里不需要删除
    // if (videoThumbnailPath != null) {
    //   try {
    //     File(videoThumbnailPath!).delete();
    //   } catch (e) {
    //     // 忽略删除错误
    //   }
    // }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用以支持 AutomaticKeepAliveClientMixin

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
              // 复选框 - 悬停、选中或选择模式时显示
              if (widget.canSelect || isHovered || widget.isSelected)
                GestureDetector(
                  onTap: widget.onCheckboxToggle,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
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
                        boxShadow: isHovered || widget.isSelected
                            ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                            : null,
                      ),
                      child: widget.isSelected
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 视频缩略图
                if (videoThumbnailPath != null)
                  Image.file(
                    File(videoThumbnailPath!),
                    fit: BoxFit.cover,
                    cacheWidth: 64,
                    cacheHeight: 64,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.videocam, size: 20, color: Colors.grey.shade600);
                    },
                  )
                else if (isLoadingThumbnail)
                  Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  )
                else
                  Icon(Icons.videocam, size: 20, color: Colors.grey.shade600),

                // 播放按钮叠加层（仅在有缩略图时显示）
                if (videoThumbnailPath != null)
                  Center(
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
    }
  }

  String _getTypeText() {
    switch (widget.item.type) {
      case FileItemType.folder:
        return '文件夹';
      case FileItemType.image:
      // 从文件扩展名获取类型
        final ext = widget.item.path.split('.').last.toUpperCase();
        return ext.isNotEmpty ? ext : 'IMAGE';
      case FileItemType.video:
      // 从文件扩展名获取类型
        final ext = widget.item.path.split('.').last.toUpperCase();
        return ext.isNotEmpty ? ext : 'VIDEO';
    }
  }
}