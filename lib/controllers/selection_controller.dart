// controllers/selection_controller.dart
import 'package:flutter/foundation.dart';
import '../models/file_item.dart';

/// 选择控制器 - 管理文件选择状态
class SelectionController extends ChangeNotifier {
  // 选中的索引集合
  Set<int> _selectedIndices = {};
  Set<int> get selectedIndices => _selectedIndices;

  // 是否处于选择模式
  bool _isSelectionMode = false;
  bool get isSelectionMode => _isSelectionMode;

  // 文件列表引用（用于统计）
  List<FileItem> _fileItems = [];

  /// 更新文件列表引用
  void updateFileItems(List<FileItem> items) {
    _fileItems = items;
    // 清理无效的选择索引
    _selectedIndices.removeWhere((index) => index >= items.length);
    if (_selectedIndices.isEmpty) {
      _isSelectionMode = false;
    }
    notifyListeners();
  }

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
    notifyListeners();
  }

  /// 全选/取消全选
  void toggleSelectAll(int itemCount) {
    if (_selectedIndices.length == itemCount) {
      _selectedIndices.clear();
      _isSelectionMode = false;
    } else {
      _selectedIndices.clear();
      for (int i = 0; i < itemCount; i++) {
        _selectedIndices.add(i);
      }
      _isSelectionMode = true;
    }
    notifyListeners();
  }

  /// 取消选择
  void cancelSelection() {
    _selectedIndices.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  /// 清空选择
  void clearSelection() {
    _selectedIndices.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  /// 获取选中的文件项
  List<FileItem> getSelectedItems() {
    return _selectedIndices
        .where((index) => index < _fileItems.length)
        .map((index) => _fileItems[index])
        .toList();
  }

  /// 获取选中的图片数量
  int getSelectedImageCount() {
    return _selectedIndices
        .where((index) =>
    index < _fileItems.length &&
        _fileItems[index].type == FileItemType.image)
        .length;
  }

  /// 获取选中的视频数量
  int getSelectedVideoCount() {
    return _selectedIndices
        .where((index) =>
    index < _fileItems.length &&
        _fileItems[index].type == FileItemType.video)
        .length;
  }

  /// 获取选中的文件夹数量
  int getSelectedFolderCount() {
    return _selectedIndices
        .where((index) =>
    index < _fileItems.length &&
        _fileItems[index].type == FileItemType.folder)
        .length;
  }

  /// 获取选中文件的总大小（字节）
  int getSelectedTotalSize() {
    return _selectedIndices
        .where((index) => index < _fileItems.length)
        .map((index) => _fileItems[index])
        .where((item) => item.type != FileItemType.folder)
        .fold(0, (sum, item) => sum + item.size);
  }

  /// 获取选中文件的总大小（MB）
  double getSelectedTotalSizeMB() {
    return getSelectedTotalSize() / (1024 * 1024);
  }

  /// 是否选中了指定索引
  bool isSelected(int index) {
    return _selectedIndices.contains(index);
  }

  /// 获取可选择的数量
  int getSelectableCount() {
    return _fileItems.length;
  }
}