import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/file_item.dart';
import '../utils/file_util.dart';

/// 文件过滤类型
enum FileFilterType {
  all('all'),
  image('image'),
  video('video');

  final String value;
  const FileFilterType(this.value);

  static FileFilterType fromValue(String value) {
    return FileFilterType.values.firstWhere(
          (type) => type.value == value,
      orElse: () => FileFilterType.all,
    );
  }
}

/// 文件管理器 - 负责文件的加载、过滤、选择等操作
class FileManager extends ChangeNotifier {
  // 文件列表
  List<FileItem> _fileItems = [];
  List<FileItem> get fileItems => _fileItems;

  // 路径管理
  String _currentPath = '';
  String get currentPath => _currentPath;

  List<String> _pathSegments = [];
  List<String> get pathSegments => _pathSegments;

  List<String> _pathHistory = [];
  List<String> get pathHistory => _pathHistory;

  // 选择管理
  final Set<int> _selectedIndices = {};
  Set<int> get selectedIndices => _selectedIndices;

  bool _isSelectionMode = false;
  bool get isSelectionMode => _isSelectionMode;

  // 过滤管理
  FileFilterType _filterType = FileFilterType.all;
  FileFilterType get filterType => _filterType;

  // 加载状态
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// 初始化文件管理器
  void initialize(String folderPath, String folderName) {
    _currentPath = folderPath;
    _initPathSegments(folderPath, folderName);
  }

  /// 初始化路径片段
  void _initPathSegments(String folderPath, String folderName) {
    final parts = folderPath.split(Platform.pathSeparator);
    if (parts.isNotEmpty) {
      _pathSegments = [parts[0], folderName];
      _pathHistory = [parts[0], folderPath];
    }
  }

  /// 加载文件列表
  Future<void> loadFiles(String path) async {
    _isLoading = true;
    _currentPath = path;
    _fileItems.clear();
    clearSelection();
    notifyListeners();

    try {
      final items = await compute(FileUtils.loadFilesInBackground, path);
      _fileItems = items;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// 导航到文件夹
  Future<void> navigateToFolder(String folderPath, String folderName) async {
    _pathSegments.add(folderName);
    _pathHistory.add(folderPath);
    await loadFiles(folderPath);
  }

  /// 导航到指定路径索引
  Future<void> navigateToPathIndex(int index) async {
    if (index >= 0 && index < _pathHistory.length) {
      _pathSegments = _pathSegments.sublist(0, index + 1);
      _pathHistory = _pathHistory.sublist(0, index + 1);
      await loadFiles(_pathHistory[index]);
    }
  }

  /// 返回上一级目录
  Future<void> navigateBack() async {
    if (_pathHistory.length > 1) {
      await navigateToPathIndex(_pathHistory.length - 2);
    }
  }

  /// 获取过滤后的文件列表
  List<FileItem> getFilteredFiles() {
    switch (_filterType) {
      case FileFilterType.all:
        return _fileItems;
      case FileFilterType.image:
        return _fileItems.where((item) =>
        item.type == FileItemType.image ||
            item.type == FileItemType.folder
        ).toList();
      case FileFilterType.video:
        return _fileItems.where((item) =>
        item.type == FileItemType.video ||
            item.type == FileItemType.folder
        ).toList();
    }
  }

  /// 获取媒体文件列表（不包含文件夹）
  List<FileItem> getMediaItems() {
    return _fileItems.where((item) =>
    item.type == FileItemType.image ||
        item.type == FileItemType.video
    ).toList();
  }

  /// 设置过滤类型
  void setFilterType(FileFilterType type) {
    _filterType = type;
    notifyListeners();
  }

  /// 切换选择模式
  void toggleSelectionMode() {
    _isSelectionMode = !_isSelectionMode;
    if (!_isSelectionMode) {
      clearSelection();
    }
    notifyListeners();
  }

  /// 切换单个项目的选择状态
  void toggleSelection(int index) {
    if (_selectedIndices.contains(index)) {
      _selectedIndices.remove(index);
      if (_selectedIndices.isEmpty) {
        _isSelectionMode = false;
      }
    } else {
      _selectedIndices.add(index);
      _isSelectionMode = true;
    }
    notifyListeners();
  }

  /// 全选
  void selectAll() {
    _selectedIndices.clear();
    for (int i = 0; i < _fileItems.length; i++) {
      _selectedIndices.add(i);
    }
    _isSelectionMode = true;
    notifyListeners();
  }

  /// 清空选择
  void clearSelection() {
    _selectedIndices.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  /// 获取选中的文件列表
  List<FileItem> getSelectedFiles() {
    return _selectedIndices
        .map((index) => _fileItems[index])
        .toList();
  }

  /// 获取选中文件的总大小（MB）
  double getSelectedTotalSize() {
    double totalSize = 0;
    for (int index in _selectedIndices) {
      totalSize += (_fileItems[index].size ?? 0) / (1024 * 1024);
    }
    return totalSize;
  }

  /// 获取选中的图片数量
  int getSelectedImageCount() {
    return _selectedIndices
        .where((index) => _fileItems[index].type == FileItemType.image)
        .length;
  }

  /// 获取选中的视频数量
  int getSelectedVideoCount() {
    return _selectedIndices
        .where((index) => _fileItems[index].type == FileItemType.video)
        .length;
  }

  /// 获取选中的文件夹数量
  int getSelectedFolderCount() {
    return _selectedIndices
        .where((index) => _fileItems[index].type == FileItemType.folder)
        .length;
  }

  /// 检查是否所有项都被选中
  bool get isAllSelected {
    return _selectedIndices.length == _fileItems.length &&
        _fileItems.isNotEmpty;
  }

  /// 递归获取选中文件夹中的所有媒体文件
  Future<List<String>> getSelectedMediaPaths() async {
    final selectedPaths = <String>[];

    for (int index in _selectedIndices) {
      final item = _fileItems[index];

      if (item.type == FileItemType.folder) {
        // 递归获取文件夹中的媒体文件
        final mediaPaths = await FileUtils.getAllMediaFilesRecursive(item.path);
        selectedPaths.addAll(mediaPaths);
      } else if (item.type == FileItemType.image ||
          item.type == FileItemType.video) {
        // 直接添加媒体文件
        selectedPaths.add(item.path);
      }
    }

    return selectedPaths;
  }
}