// pages/folder_detail/ui_components.dart
part of '../folder_detail_page_backup.dart';



/// 文件夹头部组件
class _FolderHeader extends StatelessWidget {
  final List<String> pathSegments;
  final String currentPath;
  final int selectedCount;
  final bool isSelectionMode;
  final bool isGridView;
  final String filterType;
  final bool isFilterMenuOpen;
  final Function(int) onNavigateToPath;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onToggleView;
  final Function(String) onFilterChanged;
  final VoidCallback onToggleFilterMenu;

  const _FolderHeader({
    required this.pathSegments,
    required this.currentPath,
    required this.selectedCount,
    required this.isSelectionMode,
    required this.isGridView,
    required this.filterType,
    required this.isFilterMenuOpen,
    required this.onNavigateToPath,
    required this.onToggleSelectAll,
    required this.onClearSelection,
    required this.onToggleView,
    required this.onFilterChanged,
    required this.onToggleFilterMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 面包屑导航
          _BreadcrumbNavigation(
            pathSegments: pathSegments,
            onNavigate: onNavigateToPath,
          ),

          const SizedBox(height: 20),

          // 工具栏
          _ToolBar(
            selectedCount: selectedCount,
            isSelectionMode: isSelectionMode,
            isGridView: isGridView,
            filterType: filterType,
            isFilterMenuOpen: isFilterMenuOpen,
            onToggleSelectAll: onToggleSelectAll,
            onClearSelection: onClearSelection,
            onToggleView: onToggleView,
            onFilterChanged: onFilterChanged,
            onToggleFilterMenu: onToggleFilterMenu,
          ),
        ],
      ),
    );
  }
}

/// 面包屑导航组件
class _BreadcrumbNavigation extends StatelessWidget {
  final List<String> pathSegments;
  final Function(int) onNavigate;

  const _BreadcrumbNavigation({
    required this.pathSegments,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        pathSegments.length,
            (index) {
          final isLast = index == pathSegments.length - 1;
          return Row(
            children: [
              InkWell(
                onTap: isLast ? null : () => onNavigate(index),
                child: Text(
                  pathSegments[index],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isLast ? Colors.black : Colors.grey.shade600,
                    decoration: isLast ? null : TextDecoration.underline,
                  ),
                ),
              ),
              if (!isLast) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
                const SizedBox(width: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 工具栏组件
class _ToolBar extends StatelessWidget {
  final int selectedCount;
  final bool isSelectionMode;
  final bool isGridView;
  final String filterType;
  final bool isFilterMenuOpen;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onToggleView;
  final Function(String) onFilterChanged;
  final VoidCallback onToggleFilterMenu;

  const _ToolBar({
    required this.selectedCount,
    required this.isSelectionMode,
    required this.isGridView,
    required this.filterType,
    required this.isFilterMenuOpen,
    required this.onToggleSelectAll,
    required this.onClearSelection,
    required this.onToggleView,
    required this.onFilterChanged,
    required this.onToggleFilterMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 选择操作按钮
        if (isSelectionMode) ...[
          _SelectionActions(
            selectedCount: selectedCount,
            onToggleSelectAll: onToggleSelectAll,
            onClearSelection: onClearSelection,
          ),
          const SizedBox(width: 20),
        ],

        const Spacer(),

        // 过滤和视图切换
        _FilterButton(
          filterType: filterType,
          isOpen: isFilterMenuOpen,
          onToggle: onToggleFilterMenu,
          onFilterChanged: onFilterChanged,
        ),

        const SizedBox(width: 10),

        _ViewToggleButton(
          isGridView: isGridView,
          onToggle: onToggleView,
        ),
      ],
    );
  }
}

/// 选择操作按钮组
class _SelectionActions extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onClearSelection;

  const _SelectionActions({
    required this.selectedCount,
    required this.onToggleSelectAll,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextButton.icon(
          onPressed: onToggleSelectAll,
          icon: const Icon(Icons.select_all, size: 18),
          label: const Text('全选'),
        ),
        const SizedBox(width: 10),
        TextButton.icon(
          onPressed: onClearSelection,
          icon: const Icon(Icons.clear, size: 18),
          label: const Text('清除选择'),
        ),
        const SizedBox(width: 10),
        Text(
          '已选择 $selectedCount 项',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

/// 过滤按钮组件
class _FilterButton extends StatelessWidget {
  final String filterType;
  final bool isOpen;
  final VoidCallback onToggle;
  final Function(String) onFilterChanged;

  const _FilterButton({
    required this.filterType,
    required this.isOpen,
    required this.onToggle,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list, size: 20, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text(
                        _getFilterLabel(filterType),
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        size: 20,
                        color: Colors.grey.shade700,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isOpen) _FilterDropdown(onFilterChanged: onFilterChanged),
      ],
    );
  }

  String _getFilterLabel(String type) {
    return FileFilterType.fromValue(type).label;
  }
}

/// 过滤下拉菜单
class _FilterDropdown extends StatelessWidget {
  final Function(String) onFilterChanged;

  const _FilterDropdown({required this.onFilterChanged});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 40,
      left: 0,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: FileFilterType.values.map((type) {
              return InkWell(
                onTap: () => onFilterChanged(type.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Text(type.label, style: const TextStyle(fontSize: 14)),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// 视图切换按钮
class _ViewToggleButton extends StatelessWidget {
  final bool isGridView;
  final VoidCallback onToggle;

  const _ViewToggleButton({
    required this.isGridView,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewButton(
            icon: Icons.grid_view,
            isSelected: isGridView,
            onTap: isGridView ? null : onToggle,
          ),
          Container(width: 1, height: 24, color: Colors.grey.shade300),
          _ViewButton(
            icon: Icons.view_list,
            isSelected: !isGridView,
            onTap: isGridView ? onToggle : null,
          ),
        ],
      ),
    );
  }
}

/// 单个视图按钮
class _ViewButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ViewButton({
    required this.icon,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.orange : Colors.grey.shade700,
        ),
      ),
    );
  }
}

/// 文件列表内容组件
class _FileListContent extends StatelessWidget {
  final List<FileItem> fileItems;
  final bool isGridView;
  final Set<int> selectedIndices;
  final bool isSelectionMode;
  final bool isUploading;
  final Function(int) onItemTap;
  final Function(int) onItemDoubleTap;
  final Function(int) onItemLongPress;
  final Function(int) onCheckboxToggle;

  const _FileListContent({
    required this.fileItems,
    required this.isGridView,
    required this.selectedIndices,
    required this.isSelectionMode,
    required this.isUploading,
    required this.onItemTap,
    required this.onItemDoubleTap,
    required this.onItemLongPress,
    required this.onCheckboxToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (fileItems.isEmpty) {
      return const _EmptyState();
    }

    return isGridView
        ? _GridView(
      fileItems: fileItems,
      selectedIndices: selectedIndices,
      isSelectionMode: isSelectionMode,
      isUploading: isUploading,
      onItemTap: onItemTap,
      onItemDoubleTap: onItemDoubleTap,
      onItemLongPress: onItemLongPress,
      onCheckboxToggle: onCheckboxToggle,
    )
        : _ListView(
      fileItems: fileItems,
      selectedIndices: selectedIndices,
      isSelectionMode: isSelectionMode,
      isUploading: isUploading,
      onItemTap: onItemTap,
      onItemDoubleTap: onItemDoubleTap,
      onCheckboxToggle: onCheckboxToggle,
    );
  }
}

/// 网格视图
class _GridView extends StatelessWidget {
  final List<FileItem> fileItems;
  final Set<int> selectedIndices;
  final bool isSelectionMode;
  final bool isUploading;
  final Function(int) onItemTap;
  final Function(int) onItemDoubleTap;
  final Function(int) onItemLongPress;
  final Function(int) onCheckboxToggle;

  const _GridView({
    required this.fileItems,
    required this.selectedIndices,
    required this.isSelectionMode,
    required this.isUploading,
    required this.onItemTap,
    required this.onItemDoubleTap,
    required this.onItemLongPress,
    required this.onCheckboxToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const itemWidth = 140.0;
          const spacing = 20.0;
          final crossAxisCount = ((constraints.maxWidth + spacing) / (itemWidth + spacing))
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
              return GestureDetector(
                onDoubleTap: isUploading ? null : () => onItemDoubleTap(index),
                child: FileItemCard(
                  item: fileItems[index],
                  isSelected: selectedIndices.contains(index),
                  showCheckbox: isSelectionMode || selectedIndices.contains(index),
                  canSelect: true,
                  onTap: isUploading ? () {} : () => onItemTap(index),
                  onLongPress: isUploading ? () {} : () => onItemLongPress(index),
                  onCheckboxToggle: isUploading ? () {} : () => onCheckboxToggle(index),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// 列表视图
class _ListView extends StatelessWidget {
  final List<FileItem> fileItems;
  final Set<int> selectedIndices;
  final bool isSelectionMode;
  final bool isUploading;
  final Function(int) onItemTap;
  final Function(int) onItemDoubleTap;
  final Function(int) onCheckboxToggle;

  const _ListView({
    required this.fileItems,
    required this.selectedIndices,
    required this.isSelectionMode,
    required this.isUploading,
    required this.onItemTap,
    required this.onItemDoubleTap,
    required this.onCheckboxToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      itemCount: fileItems.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onDoubleTap: isUploading ? null : () => onItemDoubleTap(index),
          child: FileListItem(
            item: fileItems[index],
            isSelected: selectedIndices.contains(index),
            canSelect: isSelectionMode || selectedIndices.contains(index),
            onTap: isUploading ? () {} : () => onItemTap(index),
            onCheckboxToggle: isUploading ? () {} : () => onCheckboxToggle(index),
          ),
        );
      },
    );
  }
}

/// 预览面板组件
class _PreviewPanel extends StatelessWidget {
  final bool showPreview;
  final int previewIndex;
  final List<FileItem> mediaItems;
  final List<FileItem> fileItems;
  final bool isPlaying;
  final Player? videoPlayer;
  final VideoController? videoController;
  final VoidCallback onClose;
  final Function(int) onOpenFullScreen;
  final VoidCallback onTogglePlay;
  final Function(double) onVideoSliderChanged;
  final Function(double) onVideoSliderChangeEnd;

  const _PreviewPanel({
    required this.showPreview,
    required this.previewIndex,
    required this.mediaItems,
    required this.fileItems,
    required this.isPlaying,
    this.videoPlayer,
    this.videoController,
    required this.onClose,
    required this.onOpenFullScreen,
    required this.onTogglePlay,
    required this.onVideoSliderChanged,
    required this.onVideoSliderChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    if (!showPreview || previewIndex < 0 || previewIndex >= fileItems.length) {
      return const SizedBox.shrink();
    }

    final currentItem = fileItems[previewIndex];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: showPreview ? 320 : 0,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 预览头部
          _PreviewHeader(
            itemName: currentItem.name,
            onClose: onClose,
            onOpenFullScreen: () => onOpenFullScreen(previewIndex),
          ),

          // 预览内容
          Expanded(
            child: _PreviewContent(
              item: currentItem,
              isPlaying: isPlaying,
              videoController: videoController,
              onTogglePlay: onTogglePlay,
            ),
          ),

          // 预览信息
          _PreviewInfo(item: currentItem),
        ],
      ),
    );
  }
}

/// 预览头部
class _PreviewHeader extends StatelessWidget {
  final String itemName;
  final VoidCallback onClose;
  final VoidCallback onOpenFullScreen;

  const _PreviewHeader({
    required this.itemName,
    required this.onClose,
    required this.onOpenFullScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              itemName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen, size: 20),
            onPressed: onOpenFullScreen,
            tooltip: '全屏',
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onClose,
            tooltip: '关闭预览',
          ),
        ],
      ),
    );
  }
}

/// 预览内容
class _PreviewContent extends StatelessWidget {
  final FileItem item;
  final bool isPlaying;
  final VideoController? videoController;
  final VoidCallback onTogglePlay;

  const _PreviewContent({
    required this.item,
    required this.isPlaying,
    this.videoController,
    required this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context) {
    if (item.type == FileItemType.image) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Image.file(
          File(item.path),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.error_outline, size: 48, color: Colors.red),
            );
          },
        ),
      );
    } else if (item.type == FileItemType.video && videoController != null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Video(controller: videoController!),
          if (!isPlaying)
            IconButton(
              icon: const Icon(Icons.play_circle_outline, size: 64),
              onPressed: onTogglePlay,
              color: Colors.white,
            ),
        ],
      );
    }

    return const Center(
      child: Text('无法预览此文件'),
    );
  }
}

/// 预览信息
class _PreviewInfo extends StatelessWidget {
  final FileItem item;

  const _PreviewInfo({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _InfoRow('类型', _getTypeLabel(item.type)),
          const SizedBox(height: 8),
          _InfoRow('大小', item.formattedSize),
          const SizedBox(height: 8),
          _InfoRow('路径', item.path, isPath: true),
        ],
      ),
    );
  }

  String _getTypeLabel(FileItemType type) {
    switch (type) {
      case FileItemType.image:
        return '图片';
      case FileItemType.video:
        return '视频';
      case FileItemType.folder:
        return '文件夹';
    }
  }
}

/// 信息行组件
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isPath;

  const _InfoRow(this.label, this.value, {this.isPath = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
            overflow: isPath ? TextOverflow.ellipsis : null,
            maxLines: isPath ? 2 : null,
          ),
        ),
      ],
    );
  }
}

/// 底部操作栏组件
class _BottomActionBar extends StatelessWidget {
  final Set<int> selectedIndices;
  final bool isUploading;
  final LocalUploadProgress? uploadProgress;
  final VoidCallback onSync;
  final Map<String, dynamic> Function() getSelectedStats;
  final String Function() getDeviceStorage;

  const _BottomActionBar({
    required this.selectedIndices,
    required this.isUploading,
    this.uploadProgress,
    required this.onSync,
    required this.getSelectedStats,
    required this.getDeviceStorage,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedIndices.isEmpty && !isUploading) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          // 选择信息
          if (selectedIndices.isNotEmpty)
            _SelectionInfo(stats: getSelectedStats()),

          // 上传进度
          if (isUploading && uploadProgress != null) ...[
            const SizedBox(width: 20),
            Expanded(
              child: _UploadProgress(progress: uploadProgress!),
            ),
          ],

          const Spacer(),

          // 设备存储信息和同步按钮
          _StorageAndSyncButton(
            deviceStorage: getDeviceStorage(),
            isUploading: isUploading,
            onSync: onSync,
          ),
        ],
      ),
    );
  }
}

/// 选择信息组件
class _SelectionInfo extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _SelectionInfo({required this.stats});

  @override
  Widget build(BuildContext context) {
    final totalSize = stats['totalSize'] as double;
    final imageCount = stats['imageCount'] as int;
    final videoCount = stats['videoCount'] as int;

    return Text(
      '已选：${totalSize.toStringAsFixed(2)}MB · $imageCount张照片/$videoCount条视频',
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey.shade600,
      ),
    );
  }
}

/// 上传进度组件
class _UploadProgress extends StatelessWidget {
  final LocalUploadProgress progress;

  const _UploadProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: progress.progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(progress.progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${progress.uploadedFiles}/${progress.totalFiles} · ${progress.currentFileName ?? ""}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// 存储信息和同步按钮组件
class _StorageAndSyncButton extends StatelessWidget {
  final String deviceStorage;
  final bool isUploading;
  final VoidCallback onSync;

  const _StorageAndSyncButton({
    required this.deviceStorage,
    required this.isUploading,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '设备剩余空间：${deviceStorage}G',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 30),
        ElevatedButton(
          onPressed: isUploading ? null : onSync,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2C2C2C),
            disabledBackgroundColor: Colors.grey,
            padding: const EdgeInsets.symmetric(
              horizontal: 40,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            isUploading ? '上传中...' : '同步',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// 加载指示器
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
      ),
    );
  }
}

/// 空状态组件
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '该文件夹为空',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}