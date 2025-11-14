// controllers/selection_controller.dart
import '../../../models/file_item.dart';

/// 选择控制器 - 负责文件选择和筛选逻辑
class SelectionController {
  final Set<int> _selectedIndices = {};
  bool _isSelectionMode = false;
  String _filterType = 'all'; // 'all', 'image', 'video'

  Set<int> get selectedIndices => Set.unmodifiable(_selectedIndices);
  bool get isSelectionMode => _isSelectionMode;
  String get filterType => _filterType;
  int get selectedCount => _selectedIndices.length;

  /// 切换选择状态
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
  }

  /// 全选/取消全选
  void toggleSelectAll(int totalCount) {
    if (_selectedIndices.length == totalCount && totalCount > 0) {
      _selectedIndices.clear();
      _isSelectionMode = false;
    } else {
      _selectedIndices.clear();
      for (int i = 0; i < totalCount; i++) {
        _selectedIndices.add(i);
      }
      _isSelectionMode = true;
    }
  }

  /// 取消选择
  void cancelSelection() {
    _selectedIndices.clear();
    _isSelectionMode = false;
  }

  /// 设置筛选类型
  void setFilterType(String type) {
    _filterType = type;
    _selectedIndices.clear();
    _isSelectionMode = false;
  }

  /// 获取筛选后的文件列表
  List<FileItem> getFilteredFiles(List<FileItem> allFiles) {
    if (_filterType == 'all') {
      return allFiles;
    } else if (_filterType == 'image') {
      return allFiles.where((item) =>
      item.type == FileItemType.folder || item.type == FileItemType.image
      ).toList();
    } else if (_filterType == 'video') {
      return allFiles.where((item) =>
      item.type == FileItemType.folder || item.type == FileItemType.video
      ).toList();
    }
    return allFiles;
  }

  /// 获取选中的项目
  List<FileItem> getSelectedItems(List<FileItem> allFiles) {
    return _selectedIndices
        .where((index) => index < allFiles.length)
        .map((index) => allFiles[index])
        .toList();
  }

  /// 获取选中的图片数量
  int getSelectedImageCount(List<FileItem> allFiles) {
    return _selectedIndices
        .where((index) => index < allFiles.length && allFiles[index].type == FileItemType.image)
        .length;
  }

  /// 获取选中的视频数量
  int getSelectedVideoCount(List<FileItem> allFiles) {
    return _selectedIndices
        .where((index) => index < allFiles.length && allFiles[index].type == FileItemType.video)
        .length;
  }

  /// 获取选中的总大小(MB)
  double getSelectedTotalSize(List<FileItem> allFiles) {
    int totalBytes = _selectedIndices
        .where((index) => index < allFiles.length)
        .map((index) => allFiles[index])
        .where((item) => item.type != FileItemType.folder)
        .fold(0, (sum, item) => sum + item.size);
    return totalBytes / (1024 * 1024);
  }

  /// 重置状态
  void reset() {
    _selectedIndices.clear();
    _isSelectionMode = false;
    _filterType = 'all';
  }
}