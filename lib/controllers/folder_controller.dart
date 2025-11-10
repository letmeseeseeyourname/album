// controllers/folder_controller.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/file_item.dart';
import '../models/folder_info.dart';
import '../utils/file_util.dart';

/// 文件夹控制器 - 管理文件加载、导航和筛选
class FolderController extends ChangeNotifier {
  // 文件夹信息
  final FolderInfo folder;

  // 文件列表
  List<FileItem> _fileItems = [];
  List<FileItem> get fileItems => _fileItems;

  // 路径管理
  List<String> _pathSegments = [];
  List<String> get pathSegments => _pathSegments;

  List<String> _pathHistory = [];
  List<String> get pathHistory => _pathHistory;

  String _currentPath = '';
  String get currentPath => _currentPath;

  // 加载状态
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  // 筛选类型
  String _filterType = 'all'; // 'all', 'image', 'video'
  String get filterType => _filterType;

  // 视图模式
  bool _isGridView = true;
  bool get isGridView => _isGridView;

  FolderController(this.folder) {
    _currentPath = folder.path;
    _initPathSegments();
  }

  /// 初始化路径片段
  void _initPathSegments() {
    final parts = folder.path.split(Platform.pathSeparator);
    if (parts.isNotEmpty) {
      _pathSegments = [parts[0], folder.name];
      _pathHistory = [parts[0], folder.path];
    }
  }

  /// 加载文件列表
  Future<void> loadFiles(String path) async {
    _isLoading = true;
    _fileItems.clear();
    notifyListeners();

    try {
      final items = await compute(FileUtils.loadFiles, path);
      _fileItems = items;
    } catch (e) {
      debugPrint('Error loading files: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 导航到文件夹
  void navigateToFolder(String folderPath, String folderName) {
    _currentPath = folderPath;
    _pathSegments.add(folderName);
    _pathHistory.add(folderPath);
    notifyListeners();

    loadFiles(folderPath);
  }

  /// 导航到路径片段
  void navigateToPathSegment(int index) {
    final targetPath = _pathHistory[index];
    final targetSegments = _pathSegments.sublist(0, index + 1);
    final targetHistory = _pathHistory.sublist(0, index + 1);

    _pathSegments = targetSegments;
    _pathHistory = targetHistory;
    _currentPath = targetPath;
    notifyListeners();

    loadFiles(targetPath);
  }

  /// 设置筛选类型
  void setFilterType(String type) {
    if (_filterType != type) {
      _filterType = type;
      notifyListeners();
    }
  }

  /// 切换视图模式
  void toggleViewMode() {
    _isGridView = !_isGridView;
    notifyListeners();
  }

  /// 设置视图模式
  void setViewMode(bool isGrid) {
    if (_isGridView != isGrid) {
      _isGridView = isGrid;
      notifyListeners();
    }
  }

  /// 获取筛选后的文件列表
  List<FileItem> getFilteredFiles() {
    if (_filterType == 'all') {
      return _fileItems;
    } else if (_filterType == 'image') {
      return _fileItems.where((item) =>
      item.type == FileItemType.folder || item.type == FileItemType.image
      ).toList();
    } else if (_filterType == 'video') {
      return _fileItems.where((item) =>
      item.type == FileItemType.folder || item.type == FileItemType.video
      ).toList();
    }
    return _fileItems;
  }

  /// 获取所有媒体文件
  List<FileItem> getMediaItems() {
    return _fileItems.where((item) =>
    item.type == FileItemType.image || item.type == FileItemType.video
    ).toList();
  }

  /// 刷新当前文件夹
  Future<void> refresh() async {
    await loadFiles(_currentPath);
  }
}