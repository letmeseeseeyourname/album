// album/managers/selection_manager.dart
import 'package:flutter/material.dart';

/// 相册选择管理器
/// 管理选中状态、悬浮状态等
class SelectionManager extends ChangeNotifier {
  final Set<String> _selectedResIds = {};
  String? _hoveredResId;

  // 获取选中的资源ID集合
  Set<String> get selectedResIds => Set.unmodifiable(_selectedResIds);

  // 获取当前悬浮的资源ID
  String? get hoveredResId => _hoveredResId;

  // 是否有选中项
  bool get hasSelection => _selectedResIds.isNotEmpty;

  // 选中数量
  int get selectionCount => _selectedResIds.length;

  // 切换选中状态
  void toggleSelection(String resId) {
    if (_selectedResIds.contains(resId)) {
      _selectedResIds.remove(resId);
    } else {
      _selectedResIds.add(resId);
    }
    notifyListeners();
  }

  // 设置悬浮项
  void setHoveredItem(String? resId) {
    if (_hoveredResId != resId) {
      _hoveredResId = resId;
      notifyListeners();
    }
  }

  // 清除悬浮状态
  void clearHovered() {
    if (_hoveredResId != null) {
      _hoveredResId = null;
      notifyListeners();
    }
  }

  // 全选
  void selectAll(List<String> resIds) {
    _selectedResIds.clear();
    _selectedResIds.addAll(resIds.where((id) => id.isNotEmpty));
    notifyListeners();
  }

  // 清除所有选择
  void clearSelection() {
    _selectedResIds.clear();
    notifyListeners();
  }

  // 检查是否选中
  bool isSelected(String? resId) {
    return resId != null && _selectedResIds.contains(resId);
  }

  // 检查是否应该显示复选框
  bool shouldShowCheckbox(String? resId) {
    return _hoveredResId == resId || _selectedResIds.isNotEmpty;
  }
}