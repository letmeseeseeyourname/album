// album/components/album_grid_view.dart (优化版 - 支持预览模式动态调整列数)
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

/// 相册网格视图组件
/// 负责网格布局和列表布局
class AlbumGridView extends StatelessWidget {
  final Map<String, List<ResList>> groupedResources;
  final List<ResList> allResources;
  final SelectionManager selectionManager;
  final Function(int) onItemClick;
  final ScrollController? scrollController;
  final bool isGridView;
  final bool showPreview; // 🆕 是否显示预览面板

  const AlbumGridView({
    super.key,
    required this.groupedResources,
    required this.allResources,
    required this.selectionManager,
    required this.onItemClick,
    this.scrollController,
    this.isGridView = true,
    this.showPreview = false, // 🆕 默认不显示预览
  });

  /// 🆕 根据预览状态获取网格列数
  int get _crossAxisCount {
    // 显示预览时减少列数，仿照 FolderDetailPage 的效果
    return showPreview ? 4 : 8;
  }

  @override
  Widget build(BuildContext context) {
    if (groupedResources.isEmpty) {
      return _buildEmptyState();
    }

    // 根据视图模式显示不同布局
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

  // 网格视图
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
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _crossAxisCount, // 🆕 使用动态列数
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

  // 列表视图
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

  // 列表项
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
                    ),
                  // 缩略图
                  _buildListThumbnail(resource),
                  const SizedBox(width: 16),
                  // 文件信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resource.fileName ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatFileSize(resource.fileSize ?? 0)} · ${_getFileExtension(resource)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 日期
                  Text(
                    _formatDate(resource.photoDate ?? resource.createDate),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
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

  /// 列表缩略图
  Widget _buildListThumbnail(ResList resource) {
    final isVideo = resource.fileType == 'V';

    if (resource.thumbnailPath == null || resource.thumbnailPath!.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 48,
          height: 48,
          child: _buildDefaultListThumbnail(isVideo),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 48,
        height: 48,
        child: _ListThumbnailWithTimeout(
          imageUrl: '${_getMinioUrl()}/${resource.thumbnailPath!}',
          isVideo: isVideo,
        ),
      ),
    );
  }

  /// 列表默认缩略图
  Widget _buildDefaultListThumbnail(bool isVideo) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isVideo
              ? [const Color(0xFF3A3A5C), const Color(0xFF2A2A4C)]
              : [const Color(0xFF4A5568), const Color(0xFF2D3748)],
        ),
      ),
      child: Center(
        child: Icon(
          isVideo ? Icons.videocam_rounded : Icons.image_rounded,
          color: Colors.white.withOpacity(0.7),
          size: 20,
        ),
      ),
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

  // 辅助方法
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
    // 尝试从文件名获取扩展名
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
}

/// 带超时处理的列表缩略图组件
class _ListThumbnailWithTimeout extends StatefulWidget {
  final String imageUrl;
  final bool isVideo;

  const _ListThumbnailWithTimeout({
    required this.imageUrl,
    required this.isVideo,
  });

  @override
  State<_ListThumbnailWithTimeout> createState() => _ListThumbnailWithTimeoutState();
}

class _ListThumbnailWithTimeoutState extends State<_ListThumbnailWithTimeout> {
  static const int _loadTimeoutSeconds = 5;

  bool _isLoading = true;
  bool _loadFailed = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _startTimeoutTimer();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ListThumbnailWithTimeout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resetLoadingState();
    }
  }

  void _resetLoadingState() {
    _timeoutTimer?.cancel();
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    _startTimeoutTimer();
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: _loadTimeoutSeconds), () {
      if (mounted && _isLoading) {
        setState(() {
          _loadFailed = true;
          _isLoading = false;
        });
      }
    });
  }

  void _onImageLoaded() {
    _timeoutTimer?.cancel();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _loadFailed = false;
      });
    }
  }

  void _onImageError() {
    _timeoutTimer?.cancel();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return _buildDefaultThumbnail();
    }

    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: BoxFit.cover,
      width: 48,
      height: 48,
      memCacheWidth: 96,
      memCacheHeight: 96,
      placeholder: (context, url) => _buildLoadingPlaceholder(),
      errorWidget: (context, url, error) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onImageError();
        });
        return _buildDefaultThumbnail();
      },
      imageBuilder: (context, imageProvider) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onImageLoaded();
        });
        return Image(
          image: imageProvider,
          fit: BoxFit.cover,
          width: 48,
          height: 48,
        );
      },
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isVideo
              ? [const Color(0xFF3A3A5C), const Color(0xFF2A2A4C)]
              : [Colors.grey.shade600, Colors.grey.shade700],
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultThumbnail() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isVideo
              ? [const Color(0xFF3A3A5C), const Color(0xFF2A2A4C)]
              : [const Color(0xFF4A5568), const Color(0xFF2D3748)],
        ),
      ),
      child: Center(
        child: Icon(
          widget.isVideo ? Icons.videocam_rounded : Icons.image_rounded,
          color: Colors.white.withOpacity(0.7),
          size: 20,
        ),
      ),
    );
  }
}