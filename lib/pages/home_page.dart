// pages/home_page.dart (优化版 - Groups 快速显示)
import 'dart:async';

import 'package:flutter/material.dart';
import '../eventbus/event_bus.dart';
import '../minio/minio_service.dart';
import '../user/models/p6device_info_model.dart';
import '../user/models/group.dart';
import '../user/my_instance.dart';
import '../user/provider/mine_provider.dart';
import '../pages/remote_album/pages/album_library_page.dart';
import 'main_folder_page.dart';

class P6loginEvent {
  P6loginEvent();
}

class HomePageReloadEvent {
  HomePageReloadEvent();
}

class GroupChangedEvent {
  GroupChangedEvent();
}

class HomePage extends StatefulWidget {
  HomePage({super.key});

  var mineProvider = MyNetworkProvider();

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; // 0: 本地图库, 1: 相册图库
  int _albumTabIndex = 0; // 相册图库的Tab索引 (0: 个人, 1: 家庭)

  final minioService = MinioService.instance;
  List<Group> _groups = [];
  Group? _selectedGroup;
  int? _currentUserId;

  // Groups 加载状态
  bool _isGroupsLoading = true;

  // EventBus 订阅引用
  StreamSubscription? _p6loginSubscription;
  StreamSubscription? _groupChangedSubscription;

  @override
  void initState() {
    super.initState();

    _p6loginSubscription = MCEventBus.on<P6loginEvent>().listen((event) {
      if (mounted) {
        _p6loginAction();
      }
    });

    _groupChangedSubscription = MCEventBus.on<GroupChangedEvent>().listen((event) {
      if (mounted) {
        // 🆕 GroupChangedEvent 表示 P2P 连接完成，刷新存储信息
        _onGroupConnectionComplete();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await _initializeConnection();
      }
    });
  }

  @override
  void dispose() {
    _p6loginSubscription?.cancel();
    _groupChangedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeConnection() async {
    if (!mounted) return;
    await MyInstance().getGroup();
    debugPrint('恢复上次选中的 group: ${MyInstance().group?.groupName}');

    debugPrint('开始初始化...');
    await _reloadData();

    // 🆕 不再在这里等待 P2P 连接，P2P 连接会异步进行
    // 连接完成后会通过 GroupChangedEvent 通知
    debugPrint('Groups 列表加载完成，P2P 连接正在后台进行...');
  }

  /// 🆕 当 Group 连接完成时调用（P2P + P6Login 都完成）
  void _onGroupConnectionComplete() {
    if (!mounted) return;

    debugPrint('Group 连接完成，刷新数据');
    _loadGroups();
    _refreshDeviceStorage();
  }

  void _onPeriodicCallback() {
    if (!mounted) return;
    print('Periodic callback triggered - ${DateTime.now()}');
    _refreshDeviceStorage();
  }

  _p6loginAction() async {
    if (!mounted) return;
    await widget.mineProvider.doP6login();
  }

  _refreshDeviceStorage() async {
    if (!mounted) return;

    debugPrint('开始刷新设备存储信息...');
    var deviceRsp = await widget.mineProvider.getStorageInfo();

    if (!mounted) return;

    if (deviceRsp.isSuccess) {
      P6DeviceInfoModel? storageInfo = deviceRsp.model;
      debugPrint("✅ 设备存储信息刷新成功: $storageInfo");
      MyInstance().p6deviceInfoModel = storageInfo;
    } else {
      debugPrint("❌ 设备存储信息刷新失败: ${deviceRsp.message}");
    }
  }

  void _loadGroups() {
    if (!mounted) return;
    setState(() {
      _groups = MyInstance().groups ?? [];
      _selectedGroup = MyInstance().group;
      _currentUserId = MyInstance().user?.user?.id;
    });
  }

  _reloadData() async {
    if (!mounted) return;

    debugPrint('开始加载设备组数据...');

    // 开始加载，设置 loading 状态
    setState(() {
      _isGroupsLoading = true;
    });

    // 🆕 优化后的 getAllGroups() 会快速返回（P2P 连接异步进行）
    var response = await widget.mineProvider.getAllGroups();

    if (!mounted) return;

    // 加载完成，取消 loading 状态
    setState(() {
      _isGroupsLoading = false;
    });

    if (response.isSuccess) {
      _loadGroups();
      debugPrint('✅ 设备组数据加载成功，共 ${_groups.length} 个设备组');
      if (_selectedGroup != null) {
        debugPrint('当前选中设备组: ${_selectedGroup?.groupName} (${_selectedGroup?.deviceCode})');
      }
    } else {
      debugPrint('❌ 设备组数据加载失败: ${response.message}');
    }
  }

  Future<void> _onGroupSelected(Group group) async {
    if (!mounted) return;

    if (_selectedGroup?.groupId == group.groupId) {
      debugPrint('设备组未变化，无需切换');
      return;
    }

    debugPrint('用户切换设备组: ${group.groupName} (${group.deviceCode})');

    setState(() {
      _selectedGroup = group;
    });

    // 更新本地保存的group
    await MyInstance().setGroup(group);

    debugPrint('开始切换设备组并建立 P2P 连接...');

    // 🆕 changeGroup 会异步建立连接，完成后发送 GroupChangedEvent
    await widget.mineProvider.changeGroup(group.deviceCode ?? "");

    if (!mounted) return;

    // 刷新groups列表以更新UI
    _loadGroups();
  }

  void _onNavigationChanged(int index) {
    if (!mounted) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onAlbumTabChanged(int index) {
    if (!mounted) return;
    setState(() {
      _albumTabIndex = index;
    });
  }

  Widget _getCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return MainFolderPage(
          selectedNavIndex: _selectedIndex,
          onNavigationChanged: _onNavigationChanged,
          groups: _groups,
          selectedGroup: _selectedGroup,
          onGroupSelected: _onGroupSelected,
          currentUserId: _currentUserId,
          isGroupsLoading: _isGroupsLoading,
        );
      case 1:
        return AlbumLibraryPage(
          selectedNavIndex: _selectedIndex,
          onNavigationChanged: _onNavigationChanged,
          groups: _groups,
          selectedGroup: _selectedGroup,
          onGroupSelected: _onGroupSelected,
          currentUserId: _currentUserId,
          currentTabIndex: _albumTabIndex,
          onTabChanged: _onAlbumTabChanged,
          isGroupsLoading: _isGroupsLoading,
        );
      default:
        return MainFolderPage(
          selectedNavIndex: _selectedIndex,
          onNavigationChanged: _onNavigationChanged,
          groups: _groups,
          selectedGroup: _selectedGroup,
          onGroupSelected: _onGroupSelected,
          currentUserId: _currentUserId,
          isGroupsLoading: _isGroupsLoading,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _getCurrentPage();
  }
}