// pages/folder_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'dart:io';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/side_navigation.dart';
import '../widgets/custom_title_bar.dart';
import '../models/folder_info.dart';
import '../models/file_item.dart';
import '../services/thumbnail_helper.dart';

class FolderDetailPage extends StatefulWidget {
  final FolderInfo folder;

  const FolderDetailPage({super.key, required this.folder});

  @override
  State<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends State<FolderDetailPage> {
  final ThumbnailHelper _helper = ThumbnailHelper();
  List<FileItem> fileItems = [];
  List<String> pathSegments = [];
  String currentPath = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    currentPath = widget.folder.path;
    _initPathSegments();
    _initializeHelper();
    _loadFiles(currentPath);
  }

  void _initPathSegments() {
    // 初始化路径段：[磁盘, 文件夹名]
    final parts = widget.folder.path.split(Platform.pathSeparator);
    if (parts.isNotEmpty) {
      pathSegments = [parts[0], widget.folder.name];
    }
  }
  /// 初始化 C# 辅助程序并处理可能出现的错误。
  Future<void> _initializeHelper() async {
    try {
      await _helper.initializeHelper();
    } catch (e) {
      // 捕获并显示错误信息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('缩略图功能不可用：请确保 ThumbnailGenerator.exe 在 assets 目录'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadFiles(String path) async {
    setState(() {
      isLoading = true;
      fileItems.clear();
    });

    try {
      final directory = Directory(path);
      final entities = await directory.list().toList();

      final items = <FileItem>[];

      for (var entity in entities) {
        if (entity is Directory) {
          // 添加文件夹
          items.add(
            FileItem(
              name: entity.path.split(Platform.pathSeparator).last,
              path: entity.path,
              type: FileItemType.folder,
            ),
          );
        } else if (entity is File) {
          final ext = entity.path.split('.').last.toLowerCase();
          FileItemType? type;

          // 判断文件类型
          if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) {
            type = FileItemType.image;
          } else if (['mp4', 'avi', 'mov', 'mkv', 'flv', 'wmv'].contains(ext)) {
            type = FileItemType.video;
          }

          // 只添加文件夹、图片和视频
          if (type != null) {
            final stat = await entity.stat();
            items.add(
              FileItem(
                name: entity.path.split(Platform.pathSeparator).last,
                path: entity.path,
                type: type,
                size: stat.size,
              ),
            );
          }
        }
      }

      // 排序：文件夹在前，然后按名称排序
      items.sort((a, b) {
        if (a.type == FileItemType.folder && b.type != FileItemType.folder) {
          return -1;
        }
        if (a.type != FileItemType.folder && b.type == FileItemType.folder) {
          return 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      setState(() {
        fileItems = items;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading files: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _navigateToFolder(String folderPath, String folderName) {
    setState(() {
      currentPath = folderPath;
      pathSegments.add(folderName);
    });
    _loadFiles(folderPath);
  }

  void _navigateToPathSegment(int index) {
    if (index == 0) {
      // 返回主页
      Navigator.pop(context);
      return;
    }

    // 返回到指定路径段
    final targetSegments = pathSegments.sublist(0, index + 1);
    final targetPath = _buildPathFromSegments(targetSegments);

    setState(() {
      pathSegments = targetSegments;
      currentPath = targetPath;
    });
    _loadFiles(targetPath);
  }

  String _buildPathFromSegments(List<String> segments) {
    if (segments.length <= 1) return widget.folder.path;

    // 重建路径
    final parts = widget.folder.path.split(Platform.pathSeparator);
    final basePath = parts
        .sublist(0, parts.length - 1)
        .join(Platform.pathSeparator);
    final additionalPath = segments.sublist(2).join(Platform.pathSeparator);

    if (additionalPath.isEmpty) {
      return widget.folder.path;
    }
    return '$basePath${Platform.pathSeparator}$additionalPath';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomTitleBar(
        showToolbar: true,
        child: Row(
          children: [
            const SideNavigation(),
            Expanded(
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildFileGrid(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: Row(
        children: [
          // 面包屑导航
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                for (int i = 0; i < pathSegments.length; i++) ...[
                  GestureDetector(
                    onTap: () => _navigateToPathSegment(i),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Text(
                        i == 0 ? '此电脑' : pathSegments[i],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: i == pathSegments.length - 1
                              ? Colors.black
                              : Colors.blue,
                          decoration: i == pathSegments.length - 1
                              ? null
                              : TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  if (i < pathSegments.length - 1)
                    const Text(' / ', style: TextStyle(fontSize: 16)),
                ],
              ],
            ),
          ),
          // 操作按钮
          IconButton(icon: const Icon(Icons.copy), onPressed: () {}),
          IconButton(icon: const Icon(Icons.sort), onPressed: () {}),
          IconButton(icon: const Icon(Icons.grid_view), onPressed: () {}),
          IconButton(icon: const Icon(Icons.list), onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildFileGrid() {
    if (fileItems.isEmpty) {
      return const Center(
        child: Text(
          '此文件夹为空',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const itemWidth = 140.0;
          const spacing = 20.0;
          final crossAxisCount =
              ((constraints.maxWidth + spacing) / (itemWidth + spacing))
                  .floor()
                  .clamp(1, 10);

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.85,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: fileItems.length,
            itemBuilder: (context, index) {
              return _FileItemCard(
                item: fileItems[index],
                onTap: () {
                  if (fileItems[index].type == FileItemType.folder) {
                    _navigateToFolder(
                      fileItems[index].path,
                      fileItems[index].name,
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _FileItemCard extends StatefulWidget {
  final FileItem item;
  final VoidCallback onTap;

  const _FileItemCard({required this.item, required this.onTap});

  @override
  State<_FileItemCard> createState() => _FileItemCardState();
}

class _FileItemCardState extends State<_FileItemCard> {
  bool isHovered = false;
  String? videoThumbnailPath;
  bool isLoadingThumbnail = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.type == FileItemType.video) {
      _generateVideoThumbnail();
    }
  }

  Future<void> _generateVideoThumbnail() async {
    if (isLoadingThumbnail) return;

    setState(() {
      isLoadingThumbnail = true;
    });

    try {
      print('Generating thumbnail for: ${widget.item.path}');

      // final thumbnailPath = await VideoThumbnail.thumbnailFile(
      //   video: widget.item.path,
      //   thumbnailPath: (await getTemporaryDirectory()).path,
      //   imageFormat: ImageFormat.PNG,
      //   maxHeight: 160,
      //   maxWidth: 160,
      //   quality: 75,
      //   timeMs: 0, // 获取第0毫秒的帧
      // );

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
        } else {
          print('Thumbnail file does not exist');
          setState(() {
            isLoadingThumbnail = false;
          });
        }
      } else {
        print('Thumbnail path is null or widget disposed');
        if (mounted) {
          setState(() {
            isLoadingThumbnail = false;
          });
        }
      }
    } catch (e, stackTrace) {
      print('Error generating video thumbnail: $e');
      print('Stack trace: $stackTrace');
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
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: widget.item.type == FileItemType.folder
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isHovered ? Colors.grey.shade100 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isHovered ? Colors.grey.shade300 : Colors.transparent,
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIcon(),
              const SizedBox(height: 8),
              Text(
                widget.item.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  Widget _buildIcon() {
    switch (widget.item.type) {
      case FileItemType.folder:
        return SizedBox(
          width: 80,
          height: 64,
          child: SvgPicture.asset(
            'assets/icons/folder_icon.svg',
            fit: BoxFit.contain,
          ),
        );
      case FileItemType.image:
        // 显示图片缩略图
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
                  Image.file(File(videoThumbnailPath!), fit: BoxFit.cover)
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
