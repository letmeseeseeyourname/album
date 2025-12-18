// pages/home_page.dart (添加升级检查功能)
import 'dart:async';

import 'package:flutter/material.dart';
import '../eventbus/event_bus.dart';
import '../eventbus/upgrade_events.dart'; // 🆕 新增
import '../manager/upgrade_manager.dart'; // 🆕 新增
import '../minio/mc_service.dart';
import '../minio/minio_config.dart';
import '../minio/minio_service.dart';
import '../pages/remote_album/pages/album_library_page.dart';
import '../user/models/group.dart';
import '../user/models/p6device_info_model.dart';
import '../user/my_instance.dart';
import '../user/provider/mine_provider.dart';
import 'local_album/controllers/upload_coordinator.dart';
import 'local_album/services/file_service.dart';
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
  int _selectedIndex = 0;
  int _albumTabIndex = 0;

  final minioService = MinioService.instance;
  List<Group> _groups = [];
  Group? _selectedGroup;
  int? _currentUserId;

  bool _isGroupsLoading = true;

  // 🆕 升级状态
  bool _hasUpdate = false;

  StreamSubscription? _p6loginSubscription;
  StreamSubscription? _groupChangedSubscription;
  StreamSubscription? _upgradeCheckSubscription; // 🆕 新增

  @override
  void initState() {
    super.initState();
    UploadCoordinator.initialize(FileService());
    _initMC();
    _p6loginSubscription = MCEventBus.on<P6loginEvent>().listen((event) {//
      if (mounted) {
        _p6loginAction();
      }
    });

    _groupChangedSubscription = MCEventBus.on<GroupChangedEvent>().listen((event) {
      if (mounted) {
        _onGroupConnectionComplete();
      }
    });

    // 🆕 监听升级检查事件
    _upgradeCheckSubscription = MCEventBus.on<UpgradeCheckEvent>().listen((event) {
      if (mounted) {
        setState(() {
          _hasUpdate = event.hasUpdate;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await _initializeConnection();
        // 🆕 启动时静默检查更新
        _checkUpgrade();
      }
    });
  }

  _initMC() async {
    final minioMC =McConfig.configure(
      alias: 'myminio',
      endpoint: 'http://127.0.0.1:9000',
      accessKey: MinioConfig.accessKey,
      secretKey:MinioConfig.secretKey,
    );
    // 2️⃣ 初始化
    await McService.instance.initialize();
  }

  @override
  void dispose() {
    _p6loginSubscription?.cancel();
    _groupChangedSubscription?.cancel();
    _upgradeCheckSubscription?.cancel(); // 🆕 新增
    super.dispose();
  }

  // 🆕 静默检查更新
  Future<void> _checkUpgrade() async {
    try {
      final hasUpdate = await UpgradeManager().checkUpgradeSilently();
      if (mounted) {
        setState(() {
          _hasUpdate = hasUpdate;
        });
      }
    } catch (e) {
      debugPrint('检查更新失败: $e');
    }
  }

  Future<void> _initializeConnection() async {
    if (!mounted) return;
    await MyInstance().getGroup();
    debugPrint('恢复上次选中的 group: ${MyInstance().group?.groupName}');

    debugPrint('开始初始化...');
    await _reloadData();

    debugPrint('Groups 列表加载完成，P2P 连接正在后台进行...');
  }

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

    setState(() {
      _isGroupsLoading = true;
    });

    var response = await widget.mineProvider.getAllGroups();

    if (!mounted) return;

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

    await MyInstance().setGroup(group);

    debugPrint('开始切换设备组并建立 P2P 连接...');

    await widget.mineProvider.changeGroup(group.deviceCode ?? "");

    if (!mounted) return;

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
          hasUpdate: _hasUpdate, // 🆕 传递升级状态
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
          hasUpdate: _hasUpdate, // 🆕 传递升级状态
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
          hasUpdate: _hasUpdate, // 🆕 传递升级状态
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _getCurrentPage();
  }
}