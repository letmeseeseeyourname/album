// controllers/path_navigation_controller.dart
import 'dart:io';

/// 路径导航控制器 - 负责管理文件夹导航和路径历史
class PathNavigationController {
  List<String> _pathSegments = [];  // 显示用的文件夹名称列表
  List<String> _pathHistory = [];   // 完整路径历史记录
  String _currentPath = '';

  List<String> get pathSegments => List.unmodifiable(_pathSegments);
  List<String> get pathHistory => List.unmodifiable(_pathHistory);
  String get currentPath => _currentPath;

  /// 初始化路径段
  void initializePath(String rootPath, String folderName) {
    final parts = rootPath.split(Platform.pathSeparator);
    if (parts.isNotEmpty) {
      _pathSegments = [parts[0], folderName];
      _pathHistory = [parts[0], rootPath];
      _currentPath = rootPath;
    }
  }

  /// 导航到子文件夹
  void navigateToFolder(String folderPath, String folderName) {
    _currentPath = folderPath;
    _pathSegments.add(folderName);
    _pathHistory.add(folderPath);
  }

  /// 导航到指定路径段
  NavigationResult navigateToSegment(int index) {
    if (index == 0) {
      return NavigationResult(shouldPopPage: true);
    }

    final targetPath = _pathHistory[index];
    _pathSegments = _pathSegments.sublist(0, index + 1);
    _pathHistory = _pathHistory.sublist(0, index + 1);
    _currentPath = targetPath;

    return NavigationResult(
      shouldPopPage: false,
      newPath: targetPath,
    );
  }

  /// 重置状态
  void reset() {
    _pathSegments.clear();
    _pathHistory.clear();
    _currentPath = '';
  }
}

/// 导航结果
class NavigationResult {
  final bool shouldPopPage;
  final String? newPath;

  NavigationResult({
    required this.shouldPopPage,
    this.newPath,
  });
}