// pages/album_library_page.dart (修改版 - 移除Tab栏)
import 'package:flutter/material.dart';
import '../../../user/models/group.dart';
import '../../../widgets/custom_title_bar.dart';
import '../../../widgets/side_navigation.dart';
import '../managers/album_data_manager.dart';
import '../components/album_grid_view.dart';
import '../components/album_toolbar.dart';
import '../components/album_bottom_bar.dart';
import '../components/album_preview_panel.dart';
import '../managers/selection_manager.dart';

class AlbumLibraryPage extends StatefulWidget {
  final int selectedNavIndex;
  final Function(int) onNavigationChanged;
  final List<Group>? groups;
  final Group? selectedGroup;
  final Function(Group)? onGroupSelected;
  final int? currentUserId;

  // 🆕 接收外部Tab状态
  final int currentTabIndex;
  final Function(int) onTabChanged;

  const AlbumLibraryPage({
    super.key,
    required this.selectedNavIndex,
    required this.onNavigationChanged,
    this.groups,
    this.selectedGroup,
    this.onGroupSelected,
    this.currentUserId,
    required this.currentTabIndex,
    required this.onTabChanged,
  });

  @override
  State<AlbumLibraryPage> createState() => _AlbumLibraryPageState();
}

class _AlbumLibraryPageState extends State<AlbumLibraryPage> {
  // 管理器
  final SelectionManager _selectionManager = SelectionManager();
  final AlbumDataManager _dataManager = AlbumDataManager();

  // 滚动控制
  final ScrollController _scrollController = ScrollController();

  // UI状态
  bool _isGridView = true;

  // 预览相关状态
  bool _showPreview = false;
  int _previewIndex = -1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // 初始加载数据
    _loadInitialData();
  }

  @override
  void didUpdateWidget(AlbumLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 🆕 监听Tab变化
    if (oldWidget.currentTabIndex != widget.currentTabIndex) {
      _onTabSwitch();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _selectionManager.dispose();
    _dataManager.dispose();
    super.dispose();
  }

  void _onScroll() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = maxScroll * 0.8;
    final minThreshold = maxScroll - 500;

    if (currentScroll >= threshold || currentScroll >= minThreshold) {
      if (!_dataManager.isLoading && _dataManager.hasMore) {
        _loadMore();
      }
    }
  }

  void _loadInitialData() {
    _dataManager.resetAndLoad(isPrivate: _isPersonalTab);
  }

  void _onTabSwitch() {
    _selectionManager.clearSelection();
    _closePreview();

    _dataManager.switchTab(_isPersonalTab);

    if (!_dataManager.hasData) {
      _dataManager.resetAndLoad(isPrivate: _isPersonalTab);
    }
  }

  void _resetAndLoad() {
    _selectionManager.clearSelection();
    _closePreview();
    _dataManager.forceRefresh(isPrivate: _isPersonalTab);
  }

  void _loadMore() {
    _dataManager.loadMore(isPrivate: _isPersonalTab);
  }

  // 🆕 使用外部传入的Tab索引
  bool get _isPersonalTab => widget.currentTabIndex == 0;

  void _openPreview(int index) {
    setState(() {
      _showPreview = true;
      _previewIndex = index;
    });
  }

  void _closePreview() {
    setState(() {
      _showPreview = false;
      _previewIndex = -1;
    });
  }

  void _previousMedia() {
    if (_previewIndex > 0) {
      setState(() {
        _previewIndex--;
      });
    }
  }

  void _nextMedia() {
    if (_previewIndex < _dataManager.allResources.length - 1) {
      setState(() {
        _previewIndex++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomTitleBar(
        showToolbar: true,
        backgroundColor: const Color(0xFFF5E8DC),
        rightTitleBgColor: Colors.white,

        // 🆕 传递Tab相关参数
        showTabs: true,
        currentTabIndex: widget.currentTabIndex,
        onTabChanged: widget.onTabChanged,

        child: Row(
          children: [
            // 侧边导航栏
            SideNavigation(
              selectedIndex: widget.selectedNavIndex,
              onNavigationChanged: widget.onNavigationChanged,
              groups: widget.groups,
              selectedGroup: widget.selectedGroup,
              onGroupSelected: widget.onGroupSelected,
              currentUserId: widget.currentUserId,
            ),

            // 主内容区
            Expanded(
              child: Column(
                children: [
                  // 🆕 只保留工具栏，Tab栏已移至CustomTitleBar
                  _buildToolbar(),

                  // 内容区域
                  Expanded(
                    child: Stack(
                      children: [
                        // 主内容区（相册列表）
                        _buildMainContent(),

                        // 右侧预览面板（覆盖在上方）
                        if (_showPreview)
                          Positioned(
                            top: 0,
                            right: 0,
                            bottom: 0,
                            child: AlbumPreviewPanel(
                              mediaItems: _dataManager.allResources,
                              previewIndex: _previewIndex,
                              onClose: _closePreview,
                              onPrevious: _previousMedia,
                              onNext: _nextMedia,
                              canGoPrevious: _previewIndex > 0,
                              canGoNext: _previewIndex < _dataManager.allResources.length - 1,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // 底部栏
                  AlbumBottomBar(
                    userId: widget.currentUserId,
                    groupId: widget.selectedGroup?.groupId,
                    selectionManager: _selectionManager,
                    dataManager: _dataManager,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🆕 简化的工具栏（不包含Tab栏）
  Widget _buildToolbar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: AlbumToolbar(
        selectionManager: _selectionManager,
        isGridView: _isGridView,
        onRefresh: _resetAndLoad,
        onToggleSelectAll: () {
          // 🆕 切换全选/取消全选
          if (_selectionManager.selectionCount == _dataManager.getAllResourceIds().length &&
              _dataManager.getAllResourceIds().isNotEmpty) {
            _selectionManager.clearSelection();
          } else {
            _selectionManager.selectAll(_dataManager.getAllResourceIds());
          }
        },
        onClearSelection: () {
          _selectionManager.clearSelection();
        },
        onToggleView: () {
          setState(() {
            _isGridView = !_isGridView;
          });
        },
        allResourceIds: _dataManager.getAllResourceIds(),
      ),
    );
  }

  Widget _buildMainContent() {
    return AnimatedBuilder(
      animation: _dataManager,
      builder: (context, child) {
        if (_dataManager.isLoading && !_dataManager.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (_dataManager.errorMessage != null && !_dataManager.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  _dataManager.errorMessage!,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _resetAndLoad,
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        if (!_dataManager.hasData) {
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

        return Stack(
          children: [
            // 🆕 根据视图模式显示不同布局
            _isGridView
                ? AlbumGridView(
              groupedResources: _dataManager.groupedResources,
              allResources: _dataManager.allResources,
              selectionManager: _selectionManager,
              onItemClick: _openPreview,
              scrollController: _scrollController,
              isGridView: true,
            )
                : AlbumGridView(
              groupedResources: _dataManager.groupedResources,
              allResources: _dataManager.allResources,
              selectionManager: _selectionManager,
              onItemClick: _openPreview,
              scrollController: _scrollController,
              isGridView: false,
            ),

            if (_dataManager.isLoading && _dataManager.hasData)
              const Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        );
      },
    );
  }
}