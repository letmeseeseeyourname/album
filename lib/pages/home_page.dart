// pages/home_page.dart
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
  final minioService = MinioService.instance;
  List<Group> _groups = [];
  Group? _selectedGroup;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();

    MCEventBus.on<P6loginEvent>().listen((event) {
      _p6loginAction();
    });

    // 监听Group变化事件
    MCEventBus.on<GroupChangedEvent>().listen((event) {
      _loadGroups();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async{
      await _initializeConnection();
    });
  }

  /// 初始化 P2P 连接
  /// 流程：获取设备组 -> P2P连接建立 -> 刷新存储信息
  Future<void> _initializeConnection() async {
    debugPrint('开始初始化 P2P 连接...');

    // 1. 先加载设备组数据，这会触发 P2P 连接建立
    await _reloadData();

    // 2. 如果有选中的设备组，说明 P2P 连接已经建立
    if (_selectedGroup != null) {
      debugPrint('设备组已选择: ${_selectedGroup?.groupName}, 开始刷新数据');

      // 3. P2P 连接成功后，刷新设备存储信息
      await _refreshDeviceStorage();

      // 4. 启动定期回调
      _onPeriodicCallback();

      debugPrint('P2P 连接初始化完成');
    } else {
      debugPrint('未找到可用的设备组');
    }
  }

  void _onPeriodicCallback() {
    // This method will be called every 5 minutes
    print('Periodic callback triggered - ${DateTime.now()}');
    // widget.mineProvider.refreshToken();
    _refreshDeviceStorage();
  }

  _p6loginAction() async {
    await widget.mineProvider.doP6login();
  }

  _refreshDeviceStorage() async {
    debugPrint('开始刷新设备存储信息...');
    var deviceRsp = await widget.mineProvider.getStorageInfo();
    if (deviceRsp.isSuccess) {
      P6DeviceInfoModel? storageInfo = deviceRsp.model;
      debugPrint("✅ 设备存储信息刷新成功: $storageInfo");
      MyInstance().p6deviceInfoModel = storageInfo;
    } else {
      debugPrint("❌ 设备存储信息刷新失败: ${deviceRsp.message}");
    }
  }

  // 从MyInstance加载groups
  void _loadGroups() {
    setState(() {
      _groups = MyInstance().groups ?? [];
      _selectedGroup = MyInstance().group;
      _currentUserId = MyInstance().user?.user?.id;
    });
  }

  // 重新加载数据
  _reloadData() async {
    debugPrint('开始加载设备组数据...');
    var response = await widget.mineProvider.getAllGroups();
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

  // 处理Group选择
  void _onGroupSelected(Group group) async {
    if (_selectedGroup?.groupId == group.groupId) {
      debugPrint('设备组未变化，无需切换');
      return; // 已经是当前选中的group
    }

    debugPrint('用户切换设备组: ${group.groupName} (${group.deviceCode})');

    setState(() {
      _selectedGroup = group;
    });

    // 切换group（这会自动建立 P2P 连接）
    debugPrint('开始切换设备组并建立 P2P 连接...');
    await widget.mineProvider.changeGroup(group.deviceCode ?? "");

    // P2P 连接成功后，刷新设备存储信息
    debugPrint('设备组切换完成，刷新存储信息');
    await _refreshDeviceStorage();
  }

  void _onNavigationChanged(int index) {
    setState(() {
      _selectedIndex = index;
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
        );
      case 1:
        return AlbumLibraryPage(
          selectedNavIndex: _selectedIndex,
          onNavigationChanged: _onNavigationChanged,
          groups: _groups,
          selectedGroup: _selectedGroup,
          onGroupSelected: _onGroupSelected,
          currentUserId: _currentUserId,
        );
      default:
        return MainFolderPage(
          selectedNavIndex: _selectedIndex,
          onNavigationChanged: _onNavigationChanged,
          groups: _groups,
          selectedGroup: _selectedGroup,
          onGroupSelected: _onGroupSelected,
          currentUserId: _currentUserId,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _getCurrentPage();

  }
}