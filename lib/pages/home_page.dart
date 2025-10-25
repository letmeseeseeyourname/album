// pages/home_page.dart
import 'package:flutter/material.dart';
import 'main_folder_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 使用 MainFolderPage 替代原来的简单主页
    return const MainFolderPage();
  }
}