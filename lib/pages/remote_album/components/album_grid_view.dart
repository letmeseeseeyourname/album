// album/components/album_grid_view.dart (支持列表视图)
import 'package:flutter/material.dart';
import '../../../user/models/resource_list_model.dart';
import '../../../models/media_item.dart';
import '../../../widgets/media_viewer_page.dart';
import '../../../network/constant_sign.dart';
import '../managers/selection_manager.dart';
import 'album_grid_item.dart';
import 'package:intl/intl.dart';

/// 相册网格视图组件
/// 负责网格布局和列表布局
class AlbumGridView extends StatelessWidget {
  final Map<String, List<ResList>> groupedResources;
  final List<ResList> allResources;
  final SelectionManager selectionManager;
  final Function(int) onItemClick;
  final ScrollController? scrollController;
  final bool isGridView; // 🆕 是否为网格视图

  const AlbumGridView({
    super.key,
    required this.groupedResources,
    required this.allResources,
    required this.selectionManager,
    required this.onItemClick,
    this.scrollController,
    this.isGridView = true, // 默认为网格视图
  });

  @override
  Widget build(BuildContext context) {
    if (groupedResources.isEmpty) {
      return _buildEmptyState();
    }

    // 🆕 根据视图模式显示不同布局
    return isGridView ? _buildGridView() : _buildListView();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无相册内容',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 网格视图
  Widget _buildGridView() {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      itemCount: groupedResources.length,
      itemBuilder: (context, index) {
        final dateKey = groupedResources.keys.elementAt(index);
        final resources = groupedResources[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期标题
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                dateKey,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            // 网格
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: resources.length,
      itemBuilder: (context, index) {
        final resource = resources[index];
        final globalIndex = allResources.indexOf(resource);
        final resId = resource.resId;

        return AnimatedBuilder(
          animation: selectionManager,
          builder: (context, child) {
            final isSelected = selectionManager.isSelected(resId);
            final isHovered = selectionManager.hoveredResId == resId;
            final shouldShowCheckbox = selectionManager.shouldShowCheckbox(resId);

            return AlbumGridItem(
              resource: resource,
              globalIndex: globalIndex,
              isSelected: isSelected,
              isHovered: isHovered,
              shouldShowCheckbox: shouldShowCheckbox,
              onHover: () {
                selectionManager.setHoveredItem(resId);
              },
              onHoverExit: () {
                if (selectionManager.hoveredResId == resId) {
                  selectionManager.clearHovered();
                }
              },
              onTap: () {
                onItemClick(globalIndex);
              },
              onDoubleTap: () {
                _openFullScreenViewer(context, globalIndex);
              },
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

  // 🆕 列表视图
  Widget _buildListView() {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      itemCount: groupedResources.length,
      itemBuilder: (context, sectionIndex) {
        final dateKey = groupedResources.keys.elementAt(sectionIndex);
        final resources = groupedResources[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期标题
            Padding(
              padding: EdgeInsets.only(bottom: 12, top: sectionIndex == 0 ? 0 : 20),
              child: Text(
                dateKey,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            // 列表项
            ...resources.asMap().entries.map((entry) {
              final index = entry.key;
              final resource = entry.value;
              return _buildListItem(context, resource, index);
            }).toList(),
          ],
        );
      },
    );
  }

  // 🆕 列表项
  Widget _buildListItem(BuildContext context, ResList resource, int index) {
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
            onDoubleTap: () {
              _openFullScreenViewer(context, globalIndex);
            },
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
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // 复选框
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
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.orange : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.orange : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 14,
                          )
                              : null,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 32),

                  // 缩略图
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: Colors.grey.shade300,
                      child: resource.thumbnailPath != null
                          ? Image.network(
                        '${_getMinioUrl()}/${resource.thumbnailPath!}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            resource.fileType == 'V' ? Icons.videocam : Icons.image,
                            color: Colors.grey.shade600,
                          );
                        },
                      )
                          : Icon(
                        resource.fileType == 'V' ? Icons.videocam : Icons.image,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // 文件名
                  Expanded(
                    child: Text(
                      resource.fileName ?? 'Nature Photo.jpg',
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // 大小
                  SizedBox(
                    width: 100,
                    child: Text(
                      _formatFileSize(resource.fileSize ?? 0),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // 类型
                  SizedBox(
                    width: 80,
                    child: Text(
                      _getFileExtension(resource),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // 共享人
                  SizedBox(
                    width: 100,
                    child: Text(
                      resource.shareUserName ?? '小悦悦',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // 人物信息
                  SizedBox(
                    width: 100,
                    child: Text(
                      '张小小',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // 日期
                  SizedBox(
                    width: 160,
                    child: Text(
                      _formatDate(resource.photoDate ?? resource.createDate),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openFullScreenViewer(BuildContext context, int index) {
    final mediaItems = allResources
        .map((res) => MediaItem.fromResList(res))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaViewerPage(
          mediaItems: mediaItems,
          initialIndex: index,
        ),
      ),
    );
  }

  // 🆕 辅助方法
  String _getMinioUrl() {
    return AppConfig.minio();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  String _getFileExtension(ResList resource) {
    if (resource.fileType == 'V') return 'MP4';
    return 'JPG';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('yyyy.M.d HH:mm:ss').format(date);
  }
}