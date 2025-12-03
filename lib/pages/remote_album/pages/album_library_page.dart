// pages/album_library_page.dart (修复版 - 初始化时获取当前P2P状态)
import 'dart:async';

import 'package:flutter/material.dart';
import '../../../eventbus/event_bus.dart';
import '../../../eventbus/p2p_events.dart';
import '../../../user/models/group.dart';
import '../../../user/provider/mine_provider.dart';
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
  final Future<void> Function(Group)? onGroupSelected;
  final int? currentUserId;

  // 接收外部Tab状态
  final int currentTabIndex;
  final Function(int) onTabChanged;
  final bool isGroupsLoading;

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
    this.isGroupsLoading = false,
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

  // P2P 连接状态
  P2pConnectionStatus _p2pStatus = P2pConnectionStatus.disconnected;
  StreamSubscription? _p2pSubscription;
  String? _p2pErrorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // 🆕 首先获取当前 P2P 连接状态（解决初始状态问题）
    _p2pStatus = MyNetworkProvider().getCurrentP2pStatus();
    debugPrint('AlbumLibraryPage 初始化 P2P 状态: $_p2pStatus');

    // 监听 P2P 连接事件
    _p2pSubscription = MCEventBus.on<P2pConnectionEvent>().listen(_onP2pEvent);

    // 初始加载数据
    _loadInitialData();
  }

  @override
  void didUpdateWidget(AlbumLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 监听Tab变化
    if (oldWidget.currentTabIndex != widget.currentTabIndex) {
      _onTabSwitch();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _selectionManager.dispose();
    _dataManager.dispose();
    _p2pSubscription?.cancel();
    super.dispose();
  }

  // 处理 P2P 事件
  void _onP2pEvent(P2pConnectionEvent event) {
    if (!mounted) return;

    final previousStatus = _p2pStatus;

    setState(() {
      _p2pStatus = event.status;
      _p2pErrorMessage = event.errorMessage;
    });

    debugPrint('AlbumLibraryPage 收到 P2P 事件: $event');

    // 从断开/失败状态变为已连接时，自动重新加载数据
    if (event.status == P2pConnectionStatus.connected &&
        (previousStatus == P2pConnectionStatus.disconnected ||
            previousStatus == P2pConnectionStatus.failed)) {
      debugPrint('P2P 重连成功，重新加载相册数据');
      _loadInitialData();
    }
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
    // 只在 P2P 已连接时加载数据
    if (_p2pStatus == P2pConnectionStatus.connected) {
      _dataManager.resetAndLoad(isPrivate: _isPersonalTab);
    } else {
      debugPrint('P2P 未连接，跳过数据加载');
    }
  }

  void _onTabSwitch() {
    _selectionManager.clearSelection();
    _closePreview();

    _dataManager.switchTab(_isPersonalTab);

    if (!_dataManager.hasData && _p2pStatus == P2pConnectionStatus.connected) {
      _dataManager.resetAndLoad(isPrivate: _isPersonalTab);
    }
  }

  void _resetAndLoad() {
    _selectionManager.clearSelection();
    _closePreview();

    // 只在 P2P 已连接时刷新
    if (_p2pStatus == P2pConnectionStatus.connected) {
      _dataManager.forceRefresh(isPrivate: _isPersonalTab);
    }
  }

  void _loadMore() {
    if (_p2pStatus == P2pConnectionStatus.connected) {
      _dataManager.loadMore(isPrivate: _isPersonalTab);
    }
  }

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

        // 传递Tab相关参数
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
                  // 工具栏
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

                  // 底部栏 - 只在有选中项目时显示
                  _buildBottomBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建底部栏（根据选中状态显示/隐藏，带动画效果）
  Widget _buildBottomBar() {
    return AnimatedBuilder(
      animation: _selectionManager,
      builder: (context, child) {
        final hasSelection = _selectionManager.hasSelection;

        return AnimatedSlide(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          offset: hasSelection ? Offset.zero : const Offset(0, 1),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: hasSelection ? 1.0 : 0.0,
            child: hasSelection
                ? AlbumBottomBar(
              userId: widget.currentUserId,
              groupId: widget.selectedGroup?.groupId,
              selectionManager: _selectionManager,
              dataManager: _dataManager,
            )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  // 简化的工具栏（不包含Tab栏）
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
          if (_selectionManager.selectionCount ==
              _dataManager.getAllResourceIds().length &&
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
    // 优先检查 P2P 连接状态
    if (_p2pStatus == P2pConnectionStatus.disconnected ||
        _p2pStatus == P2pConnectionStatus.failed) {
      return _buildP2pDisconnectedView();
    }

    if (_p2pStatus == P2pConnectionStatus.connecting) {
      return _buildP2pConnectingView();
    }

    // P2P 已连接，显示正常内容
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
            // 根据视图模式显示不同布局
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

  // P2P 断开连接视图
  Widget _buildP2pDisconnectedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'P2P 连接已断开',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _p2pErrorMessage ?? '无法获取相册数据，请检查网络连接',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              MyNetworkProvider().reconnectP2p();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('重新连接'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5E8DC),
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // P2P 连接中视图
  Widget _buildP2pConnectingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '正在连接设备...',
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