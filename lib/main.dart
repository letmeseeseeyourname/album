// main.dart
import 'dart:io';
import 'package:ablumwin/utils/win_helper.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'user/my_instance.dart';
import 'package:media_kit/media_kit.dart';

// 1. 定义一个 GlobalKey，用于全局访问 ScaffoldMessenger
final GlobalKey<ScaffoldMessengerState> snackBarKey =
GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  // 初始化窗口管理器
  await windowManager.ensureInitialized();

  // 设置窗口选项
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1200, 800), // 初始窗口大小
    minimumSize: Size(800, 600), // 最小窗口大小
    center: true, // 窗口居中
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // 隐藏默认标题栏
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  String ip = await WinHelper.getLocalIpAddress();
  debugPrint("LocalIpAddress: $ip");
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with TrayListener, WindowListener {
  @override
  void initState() {
    super.initState();
    // 添加托盘监听
    trayManager.addListener(this);
    // 添加窗口监听
    windowManager.addListener(this);
    // 初始化系统托盘
    _initSystemTray();
    // 设置关闭前拦截
    windowManager.setPreventClose(true);
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  /// 获取托盘图标路径
  Future<String> _getTrayIconPath() async {
    if (!Platform.isWindows) {
      return 'assets/logo.png';
    }

    // 获取可执行文件路径
    final exePath = Platform.resolvedExecutable;
    final exeDir = File(exePath).parent.path;

    // 生产环境：图标在 exe 同级目录
    final prodIconPath = '$exeDir\\app_icon.ico';
    if (await File(prodIconPath).exists()) {
      debugPrint('使用生产环境图标: $prodIconPath');
      return prodIconPath;
    }

    // 开发环境：从项目目录查找
    // Platform.resolvedExecutable 在开发时指向 build 目录
    // 需要向上查找到项目根目录
    var currentDir = Directory(exeDir);

    // 向上查找，直到找到 pubspec.yaml（项目根目录）
    for (var i = 0; i < 10; i++) {
      final pubspecFile = File('${currentDir.path}\\pubspec.yaml');
      if (await pubspecFile.exists()) {
        // 找到项目根目录
        final devIconPath = '${currentDir.path}\\windows\\runner\\resources\\app_icon.ico';
        if (await File(devIconPath).exists()) {
          debugPrint('使用开发环境图标: $devIconPath');
          return devIconPath;
        }
        break;
      }
      currentDir = currentDir.parent;
    }

    // 尝试使用当前工作目录
    final cwdIconPath = '${Directory.current.path}\\windows\\runner\\resources\\app_icon.ico';
    if (await File(cwdIconPath).exists()) {
      debugPrint('使用工作目录图标: $cwdIconPath');
      return cwdIconPath;
    }

    debugPrint('警告: 未找到托盘图标文件');
    debugPrint('  尝试的路径:');
    debugPrint('    - $prodIconPath');
    debugPrint('    - $cwdIconPath');

    // 返回一个路径（即使不存在）
    return prodIconPath;
  }

  /// 初始化系统托盘
  Future<void> _initSystemTray() async {
    try {
      // 获取正确的图标路径
      final iconPath = await _getTrayIconPath();
      debugPrint('设置托盘图标: $iconPath');

      // 设置托盘图标
      await trayManager.setIcon(iconPath);

      // 设置托盘提示文字
      await trayManager.setToolTip('AI相册管家');

      // 设置右键菜单
      Menu menu = Menu(
        items: [
          MenuItem(
            key: 'show_window',
            label: '显示窗口',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: '退出',
          ),
        ],
      );
      await trayManager.setContextMenu(menu);
      debugPrint('系统托盘初始化成功');
    } catch (e) {
      debugPrint('系统托盘初始化失败: $e');
    }
  }

  /// 托盘图标左键点击 - 显示窗口
  @override
  void onTrayIconMouseDown() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// 托盘图标右键点击 - 显示菜单
  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  /// 托盘菜单点击事件
  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show_window':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'exit_app':
        await _exitApp();
        break;
    }
  }

  /// 真正退出应用
  Future<void> _exitApp() async {
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.close();
    exit(0);
  }

  /// 窗口关闭事件 - 根据设置决定最小化还是退出
  @override
  void onWindowClose() async {
    final minimizeOnClose = await MyInstance().getMinimizeOnClose();

    if (minimizeOnClose) {
      await windowManager.hide();
    } else {
      await _exitApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '亲选相册',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontFamily: 'Microsoft YaHei',
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'Microsoft YaHei',
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Microsoft YaHei',
          ),
          labelLarge: TextStyle(
            fontFamily: 'Microsoft YaHei',
          ),
        ),
      ),
      home: const AppInitializer(),
    );
  }
}

/// 应用初始化页面 - 检查登录状态并跳转到相应页面
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await MyInstance().get();
    final isLoggedIn = MyInstance().isLogin();

    if (mounted) {
      if (isLoggedIn) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
      ),
    );
  }
}