// pages/home_page.dart
import 'package:flutter/material.dart';
import '../p2p/p2p_tunnel_service.dart';
import 'main_folder_page.dart';
import 'album_library_page.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; // 0: 本地图库, 1: 相册图库

  // ========== P2P相关代码开始 ==========
  // final P2PTunnelService _p2pService = P2PTunnelService();
  bool _isP2PConnected = false;

  @override
  void initState() {
    super.initState();
    // _checkP2PStatus();  // 检查P2P状态
  }

  // 检查P2P连接状态
  // void _checkP2PStatus() {
  //   setState(() {
  //     _isP2PConnected = _p2pService.isLoggedIn;
  //   });
  // }
  // ========== P2P相关代码结束 ==========

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
    // ========== 原始版本（不显示P2P状态）==========
    return _getCurrentPage();

    // ========== 新版本（显示P2P状态指示器）==========
    // return Stack(
    //   children: [
    //     _getCurrentPage(),
    //
    //     // P2P状态指示器（右上角小图标）
    //     Positioned(
    //       top: 8,
    //       right: 8,
    //       child: Icon(
    //         _isP2PConnected ? Icons.cloud_done : Icons.cloud_off,
    //         size: 18,
    //         color: _isP2PConnected ? Colors.green : Colors.grey,
    //       ),
    //     ),
    //   ],
    // );
  }
}