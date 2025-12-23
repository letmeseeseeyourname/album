// pages/album_library_page.dart (添加 hasUpdate 参数)
import 'dart:async';

import 'package:flutter/material.dart';
import '../../../album/database/download_task_db_helper.dart';
import '../../../album/manager/download_queue_manager.dart';
import '../../../eventbus/event_bus.dart';
import '../../../eventbus/p2p_events.dart';
import '../../../eventbus/download_events.dart'; // 新增：导入下载事件
import '../../../pages/home_page.dart'; // 导入 GroupChangedEvent
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

  // 🆕 升级状态参数
  final bool hasUpdate;

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
    this.hasUpdate = false, // 🆕 默认值
  });

  @override
  State<AlbumLibraryPage> createState() => _AlbumLibraryPageState();
}

class _AlbumLibraryPageState extends State<AlbumLibraryPage> {
  // 管理器
  final SelectionManager _selectionManager = SelectionManager();
  final AlbumDataManager _dataManager = AlbumDataManager();
  // ✅ 新增：下载管理器引用
  final DownloadQueueManager _downloadManager = DownloadQueueManager.instance;
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
  StreamSubscription? _groupChangedSubscription;
  StreamSubscription? _downloadCompleteSubscription; // 新增：下载完成事件订阅
  String? _p2pErrorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // 获取当前 P2P 连接状态
    _p2pStatus = MyNetworkProvider().getCurrentP2pStatus();
    debugPrint('AlbumLibraryPage 初始化 P2P 状态: $_p2pStatus');

    // 监听 P2P 连接事件（仅用于更新 UI 状态，不触发数据加载）
    _p2pSubscription = MCEventBus.on<P2pConnectionEvent>().listen(_onP2pEvent);

    // 监听 Group 切换事件（在此事件中触发数据加载）
    _groupChangedSubscription = MCEventBus.on<GroupChangedEvent>().listen(_onGroupChanged);

    // 监听下载完成事件
    _downloadCompleteSubscription = MCEventBus.on<DownloadCompleteEvent>().listen(_onDownloadComplete);

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
    _groupChangedSubscription?.cancel();
    _downloadCompleteSubscription?.cancel(); // 新增：取消下载完成事件订阅
    super.dispose();
  }

  // 处理下载完成事件
  void _onDownloadComplete(DownloadCompleteEvent event) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${event.fileName} 下载完成'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 处理 Group 切换事件
  void _onGroupChanged(GroupChangedEvent event) async {
    if (!mounted) return;

    debugPrint('AlbumLibraryPage 收到 GroupChangedEvent，开始刷新数据');

    // 清除选中状态和预览
    _selectionManager.clearSelection();
    _closePreview();

    // 先清空所有 Tab 的缓存（个人和家庭）
    await _dataManager.clearAllCache();

    // 再加载当前 Tab 的数据
    _dataManager.forceRefresh(isPrivate: _isPersonalTab);
  }

  // 处理 P2P 事件（仅更新 UI 状态）
  void _onP2pEvent(P2pConnectionEvent event) {
    if (!mounted) return;

    setState(() {
      _p2pStatus = event.status;
      _p2pErrorMessage = event.errorMessage;
    });

    debugPrint('AlbumLibraryPage 收到 P2P 事件: $event');
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

    // 如果切换后的 Tab 没有数据，则加载数据
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

  // ============ 预览相关 ============

  // 处理item点击 - 选择状态下切换选中，否则打开预览
  void _handleItemClick(int index) {
    // 如果处于选择状态，则切换选中状态
    if (_selectionManager.hasSelection) {
      final resources = _dataManager.allResources;
      if (index >= 0 && index < resources.length) {
        final resId = resources[index].resId;
        if (resId != null && resId.isNotEmpty) {
          _selectionManager.toggleSelection(resId);
        }
      }
    } else {
      // 否则打开预览
      _openPreview(index);
    }
  }

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

  // ============ UI 构建 ============

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

        // 🆕 传递升级状态
        hasUpdate: widget.hasUpdate,

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

            // 主内容区 - 使用 Flex 布局
            Expanded(
              child: Row(
                children: [
                  // 相册列表区域 - 动态 flex
                  Expanded(
                    flex: _showPreview ? 3 : 1,
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          // 工具栏
                          _buildToolbar(),

                          // 内容区域
                          Expanded(child: _buildMainContent()),

                          // 底部栏
                          _buildBottomBar(),
                        ],
                      ),
                    ),
                  ),

                  // 预览区域 - 固定 flex:2
                  if (_showPreview)
                    Expanded(
                      flex: 2,
                      child: _buildPreviewPanel(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建预览面板
  Widget _buildPreviewPanel() {
    if (_previewIndex < 0 || _previewIndex >= _dataManager.allResources.length) {
      return Container(color: Colors.white);
    }

    return AlbumPreviewPanel(
      mediaItems: _dataManager.allResources,
      previewIndex: _previewIndex,
      onClose: _closePreview,
      onPrevious: _previousMedia,
      onNext: _nextMedia,
      canGoPrevious: _previewIndex > 0,
      canGoNext: _previewIndex < _dataManager.allResources.length - 1,
    );
  }

  // 构建底部栏（根据选中状态显示/隐藏，带动画效果）
  // ✅ 修改：构建底部栏（根据选中状态或下载状态显示/隐藏）
  Widget _buildBottomBar() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _selectionManager,
        _downloadManager,  // ✅ 同时监听下载管理器
      ]),
      builder: (context, child) {
        final hasSelection = _selectionManager.hasSelection;

        // ✅ 检查是否有未完成的下载任务
        final hasActiveDownloads = _downloadManager.downloadTasks.any(
              (t) => t.status == DownloadTaskStatus.downloading ||
              t.status == DownloadTaskStatus.pending ||
              t.status == DownloadTaskStatus.paused,
        );

        // ✅ 显示条件：有选中项 OR 有未完成的下载任务
        final shouldShow = hasSelection || hasActiveDownloads;

        return AnimatedSlide(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          offset: shouldShow ? Offset.zero : const Offset(0, 1),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: shouldShow ? 1.0 : 0.0,
            child: shouldShow
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

  // 工具栏
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
                  '加载失败:${_dataManager.errorMessage}',
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
              onItemClick: _handleItemClick,
              scrollController: _scrollController,
              isGridView: true,
              showPreview: _showPreview,
            )
                : AlbumGridView(
              groupedResources: _dataManager.groupedResources,
              allResources: _dataManager.allResources,
              selectionManager: _selectionManager,
              onItemClick: _handleItemClick,
              scrollController: _scrollController,
              isGridView: false,
              showPreview: _showPreview,
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