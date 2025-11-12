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
      await _reloadData();
      _onPeriodicCallback();
    });
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
    var deviceRsp = await widget.mineProvider.getStorageInfo();
    if (deviceRsp.isSuccess) {
      P6DeviceInfoModel? storageInfo = deviceRsp.model;
      debugPrint("storageInfo $storageInfo");
      MyInstance().p6deviceInfoModel = storageInfo;
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
    var response = await widget.mineProvider.getAllGroups();
    if (response.isSuccess) {
      _loadGroups();
    }
  }

  // 处理Group选择
  void _onGroupSelected(Group group) async {
    if (_selectedGroup?.groupId == group.groupId) {
      return; // 已经是当前选中的group
    }

    setState(() {
      _selectedGroup = group;
    });

    // 切换group
    await widget.mineProvider.changeGroup(group.deviceCode ?? "");

    // 刷新设备存储信息
    _refreshDeviceStorage();
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