// album/components/album_grid_view.dart
import 'package:flutter/material.dart';
import '../../../user/models/resource_list_model.dart';
import '../../../models/media_item.dart';
import '../../../widgets/media_viewer_page.dart';
import '../managers/selection_manager.dart';
import 'album_grid_item.dart';

/// 相册网格视图组件
/// 负责网格布局和交互
class AlbumGridView extends StatelessWidget {
  final Map<String, List<ResList>> groupedResources;
  final List<ResList> allResources;
  final SelectionManager selectionManager;
  final Function(int) onItemClick;
  final ScrollController? scrollController;

  const AlbumGridView({
    super.key,
    required this.groupedResources,
    required this.allResources,
    required this.selectionManager,
    required this.onItemClick,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (groupedResources.isEmpty) {
      return _buildEmptyState();
    }

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
                // 单击：打开右侧预览
                onItemClick(globalIndex);
              },
              onDoubleTap: () {
                // 双击：打开全屏查看器
                _openFullScreenViewer(context, globalIndex);
              },
              onCheckboxTap: () {
                // 复选框点击：切换选中状态
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
}