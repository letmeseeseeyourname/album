// pages/home_page.dart
import 'package:flutter/material.dart';
import '../eventbus/event_bus.dart';
import '../user/models/p6device_info_model.dart';
import '../user/my_instance.dart';
import '../user/provider/mine_provider.dart';
import 'album_library_page.dart';
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


  @override
  void initState() {
    super.initState();

    MCEventBus.on<P6loginEvent>().listen((event) {
      _p6loginAction();
    });

    _onPeriodicCallback();
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
        );
      case 1:
        return AlbumLibraryPage(
          selectedNavIndex: _selectedIndex,
          onNavigationChanged: _onNavigationChanged,
        );
      default:
        return MainFolderPage(
          selectedNavIndex: _selectedIndex,
          onNavigationChanged: _onNavigationChanged,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _getCurrentPage();

  }
}