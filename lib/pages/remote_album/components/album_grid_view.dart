// album/components/album_grid_view.dart (优化版 v9)
//
// 改进点：
// 1. 移除 ImageLoadManager 依赖，使用 CachedNetworkImage
// 2. 简化滚动处理逻辑
// 3. 增加 cacheExtent 预加载

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../user/models/resource_list_model.dart';
import '../../../models/media_item.dart';
import '../../../widgets/media_viewer_page.dart';
import '../../../network/constant_sign.dart';
import '../managers/selection_manager.dart';
import 'album_grid_item.dart';
import 'package:intl/intl.dart';

/// 相册网格视图组件（优化版 v9）
class AlbumGridView extends StatelessWidget {
  final Map<String, List<ResList>> groupedResources;
  final List<ResList> allResources;
  final SelectionManager selectionManager;
  final Function(int) onItemClick;
  final ScrollController? scrollController;
  final bool isGridView;
  final bool showPreview;

  const AlbumGridView({
    super.key,
    required this.groupedResources,
    required this.allResources,
    required this.selectionManager,
    required this.onItemClick,
    this.scrollController,
    this.isGridView = true,
    this.showPreview = false,
  });

  int get _crossAxisCount => showPreview ? 4 : 8;

  @override
  Widget build(BuildContext context) {
    if (groupedResources.isEmpty) {
      return _buildEmptyState();
    }
    return isGridView ? _buildGridView(context) : _buildListView(context);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('暂无相册内容',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildGridView(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      // 增加预加载范围
      cacheExtent: 1000,
      itemCount: groupedResources.length,
      itemBuilder: (context, index) {
        final dateKey = groupedResources.keys.elementAt(index);
        final resources = groupedResources[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(dateKey,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
            ),
            _buildGrid(context, resources),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context, List<ResList> resources) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: resources.length,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        final resource = resources[index];
        final globalIndex = allResources.indexOf(resource);
        final resId = resource.resId;

        return AnimatedBuilder(
          animation: selectionManager,
          builder: (context, child) {
            return AlbumGridItem(
              key: ValueKey('${resource.resId ?? resource.thumbnailPath ?? index}'),
              resource: resource,
              globalIndex: globalIndex,
              isSelected: selectionManager.isSelected(resId),
              isHovered: selectionManager.hoveredResId == resId,
              shouldShowCheckbox: selectionManager.shouldShowCheckbox(resId),
              onHover: () => selectionManager.setHoveredItem(resId),
              onHoverExit: () {
                if (selectionManager.hoveredResId == resId) {
                  selectionManager.clearHovered();
                }
              },
              onTap: () => onItemClick(globalIndex),
              onDoubleTap: () => _openFullScreenViewer(context, globalIndex),
              onCheckboxTap: () {
                if (resId != null) {
                  selectionManager.toggleSelection(resId);
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildListView(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      cacheExtent: 500,
      itemCount: groupedResources.length,
      itemBuilder: (context, sectionIndex) {
        final dateKey = groupedResources.keys.elementAt(sectionIndex);
        final resources = groupedResources[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
              EdgeInsets.only(bottom: 12, top: sectionIndex == 0 ? 0 : 20),
              child: Text(dateKey,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
            ),
            ...resources.map((resource) => _buildListItem(context, resource)),
          ],
        );
      },
    );
  }

  Widget _buildListItem(BuildContext context, ResList resource) {
    final globalIndex = allResources.indexOf(resource);
    final resId = resource.resId;

    return AnimatedBuilder(
      animation: selectionManager,
      builder: (context, child) {
        final isSelected = selectionManager.isSelected(resId);
        final isHovered = selectionManager.hoveredResId == resId;

        return MouseRegion(
          onEnter: (_) => selectionManager.setHoveredItem(resId),
          onExit: (_) {
            if (selectionManager.hoveredResId == resId) {
              selectionManager.clearHovered();
            }
          },
          child: GestureDetector(
            onTap: () {
              if (selectionManager.hasSelection) {
                if (resId != null) {
                  selectionManager.toggleSelection(resId);
                }
              } else {
                onItemClick(globalIndex);
              }
            },
            onDoubleTap: () => _openFullScreenViewer(context, globalIndex),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.orange.withOpacity(0.1)
                    : (isHovered ? Colors.grey.shade100 : Colors.white),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isSelected ? Colors.orange : Colors.grey.shade200,
                    width: isSelected ? 2 : 1),
              ),
              child: Row(
                children: [
                  if (selectionManager.hasSelection || isHovered)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () {
                          if (resId != null) {
                            selectionManager.toggleSelection(resId);
                          }
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.orange : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: isSelected
                                    ? Colors.orange
                                    : Colors.grey.shade400,
                                width: 2),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                              color: Colors.white, size: 16)
                              : null,
                        ),
                      ),
                    ),
                  _ListThumbnail(resource: resource),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(resource.fileName ?? 'Unknown',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(
                            '${_formatFileSize(resource.fileSize ?? 0)} · ${_getFileExtension(resource)} · ${_formatDate(resource.photoDate ?? resource.createDate)}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  if (resource.fileType == 'V')
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow,
                                size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(_formatDuration(resource.duration ?? 0),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ),
                  IconButton(
                      icon: Icon(Icons.more_vert, color: Colors.grey.shade500),
                      onPressed: () {},
                      splashRadius: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openFullScreenViewer(BuildContext context, int index) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => MediaViewerPage(
              mediaItems: allResources
                  .map((res) => MediaItem.fromResList(res))
                  .toList(),
              initialIndex: index,
            )));
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  String _getFileExtension(ResList resource) {
    if (resource.fileType == 'V') return 'MP4';
    if (resource.fileName != null) {
      final dotIndex = resource.fileName!.lastIndexOf('.');
      if (dotIndex > 0 && dotIndex < resource.fileName!.length - 1) {
        return resource.fileName!.substring(dotIndex + 1).toUpperCase();
      }
    }
    return 'JPG';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('yyyy.M.d HH:mm:ss').format(date);
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

/// 列表缩略图组件
class _ListThumbnail extends StatelessWidget {
  final ResList resource;

  const _ListThumbnail({required this.resource});

  String? get _imageUrl {
    final path = resource.thumbnailPath;
    if (path == null || path.isEmpty) return null;
    return "${AppConfig.minio()}/$path";
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = resource.fileType == 'V';
    final url = _imageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 48,
        height: 48,
        child: url != null
            ? CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          width: 48,
          height: 48,
          memCacheWidth: 96,
          memCacheHeight: 96,
          placeholder: (context, url) => _buildPlaceholder(isVideo),
          errorWidget: (context, url, error) => _buildPlaceholder(isVideo),
        )
            : _buildPlaceholder(isVideo),
      ),
    );
  }

  Widget _buildPlaceholder(bool isVideo) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isVideo
              ? [const Color(0xFF3A3A5C), const Color(0xFF2A2A4C)]
              : [Colors.grey.shade200, Colors.grey.shade300],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 20,
          child: Image.asset(
            'assets/images/image_placeholder.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                color: Colors.grey.shade400,
                size: 20,
              );
            },
          ),
        ),
      ),
    );
  }
}