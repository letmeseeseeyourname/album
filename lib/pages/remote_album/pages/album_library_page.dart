// pages/album_library_page.dart (优化版)
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


/// 优化后的相册图库页面
/// 主要职责：页面框架和组件回调
class AlbumLibraryPage extends StatefulWidget {
  final int selectedNavIndex;
  final Function(int) onNavigationChanged;
  final List<Group>? groups;
  final Group? selectedGroup;
  final Function(Group)? onGroupSelected;
  final int? currentUserId;

  const AlbumLibraryPage({
    super.key,
    required this.selectedNavIndex,
    required this.onNavigationChanged,
    this.groups,
    this.selectedGroup,
    this.onGroupSelected,
    this.currentUserId,
  });

  @override
  State<AlbumLibraryPage> createState() => _AlbumLibraryPageState();
}

class _AlbumLibraryPageState extends State<AlbumLibraryPage>
    with SingleTickerProviderStateMixin {
  // Tab控制器
  late TabController _tabController;

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
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);

    // 初始加载数据
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _selectionManager.dispose();
    _dataManager.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _onTabSwitch();
    }
  }

  void _onScroll() {
    // 预加载优化：提前加载（距离底部 20% 或 500px 时开始）
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = maxScroll * 0.8; // 80% 位置
    final minThreshold = maxScroll - 500; // 或距离底部 500px

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
    // 优化：切换 Tab 时使用缓存，不重新加载
    _selectionManager.clearSelection();
    _closePreview();

    // 切换到对应的缓存数据
    _dataManager.switchTab(_isPersonalTab);

    // 如果该 Tab 没有数据，则加载
    if (!_dataManager.hasData) {
      _dataManager.resetAndLoad(isPrivate: _isPersonalTab);
    }
  }

  void _resetAndLoad() {
    // 强制刷新（清空缓存）
    _selectionManager.clearSelection();
    _closePreview();
    _dataManager.forceRefresh(isPrivate: _isPersonalTab);
  }

  void _loadMore() {
    _dataManager.loadMore(isPrivate: _isPersonalTab);
  }

  bool get _isPersonalTab => _tabController.index == 0;

  // 预览相关方法
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
                  // Tab栏
                  _buildTabBar(),

                  // 内容区域
                  Expanded(
                    child: Row(
                      children: [
                        // 左侧相册列表
                        Expanded(
                          child: _buildMainContent(),
                        ),

                        // 右侧预览面板
                        if (_showPreview)
                          AlbumPreviewPanel(
                            mediaItems: _dataManager.allResources,
                            previewIndex: _previewIndex,
                            onClose: _closePreview,
                            onPrevious: _previousMedia,
                            onNext: _nextMedia,
                            canGoPrevious: _previewIndex > 0,
                            canGoNext: _previewIndex < _dataManager.allResources.length - 1,
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

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        children: [
          // Tab栏
          Container(
            color: Colors.white,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.black87,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.orange,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
              tabs: const [
                Tab(text: '个人'),
                Tab(text: '家庭'),
              ],
            ),
          ),

          // 工具栏
          AlbumToolbar(
            selectionManager: _selectionManager,
            isGridView: _isGridView,
            onRefresh: _resetAndLoad,
            onSelectAll: () {
              _selectionManager.selectAll(_dataManager.getAllResourceIds());
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
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return AnimatedBuilder(
      animation: _dataManager,
      builder: (context, child) {
        if (_dataManager.isLoading && !_dataManager.hasData) {
          // 首次加载时显示加载指示器
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (_dataManager.errorMessage != null && !_dataManager.hasData) {
          // 显示错误信息
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
          // 空状态
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
            // 相册网格视图
            AlbumGridView(
              groupedResources: _dataManager.groupedResources,
              allResources: _dataManager.allResources,
              selectionManager: _selectionManager,
              onItemClick: _openPreview,
              scrollController: _scrollController,
            ),

            // 加载更多指示器
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