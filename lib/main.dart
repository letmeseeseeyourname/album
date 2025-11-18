// main.dart
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'user/my_instance.dart';
import 'package:media_kit/media_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  // 初始化窗口管理器
  await windowManager.ensureInitialized();

  // 设置窗口选项
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1200, 800),        // 初始窗口大小
    minimumSize: Size(800, 600),  // 最小窗口大小
    center: true,                 // 窗口居中
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // 隐藏默认标题栏
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '亲选相册',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
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

  /// 检查登录状态
  Future<void> _checkLoginStatus() async {
    // 从本地存储加载用户信息
    await MyInstance().get();

    // 获取登录状态
    final isLoggedIn = MyInstance().isLogin();

    // 根据登录状态跳转页面
    if (mounted) {
      if (isLoggedIn) {
        // 已登录，跳转到主页
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      } else {
        // 未登录，跳转到登录页
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 显示加载指示器
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