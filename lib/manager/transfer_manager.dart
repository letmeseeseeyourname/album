// managers/transfer_manager.dart
import 'package:flutter/foundation.dart';
import '../models/transfer_task_model.dart';

/// 传输管理器 - 管理所有传输任务
class TransferManager extends ChangeNotifier {
  static final TransferManager _instance = TransferManager._internal();
  factory TransferManager() => _instance;
  TransferManager._internal();

  final List<TransferTaskModel> _tasks = [];

  List<TransferTaskModel> get tasks => List.unmodifiable(_tasks);

  /// 获取正在进行的任务数量
  int get activeTaskCount => _tasks.where((t) => t.status == TransferTaskStatus.uploading).length;

  /// 添加新任务
  void addTask(TransferTaskModel task) {
    _tasks.insert(0, task); // 新任务添加到最前面
    notifyListeners();
  }

  /// 更新任务
  void updateTask(int taskId, TransferTaskModel updatedTask) {
    final index = _tasks.indexWhere((t) => t.taskId == taskId);
    if (index >= 0) {
      _tasks[index] = updatedTask;
      notifyListeners();
    }
  }

  /// 更新文件进度
  void updateFileProgress(int taskId, int fileIndex, double progress, int uploadedSize) {
    final task = _tasks.firstWhere((t) => t.taskId == taskId, orElse: () => throw Exception('Task not found'));
    task.updateFileProgress(fileIndex, progress, uploadedSize);
    notifyListeners();
  }

  /// 暂停任务
  void pauseTask(int taskId) {
    final task = _tasks.firstWhere((t) => t.taskId == taskId, orElse: () => throw Exception('Task not found'));
    task.pause();
    notifyListeners();
  }

  /// 恢复任务
  void resumeTask(int taskId) {
    final task = _tasks.firstWhere((t) => t.taskId == taskId, orElse: () => throw Exception('Task not found'));
    task.resume();
    notifyListeners();
  }

  /// 删除任务
  void deleteTask(int taskId) {
    _tasks.removeWhere((t) => t.taskId == taskId);
    notifyListeners();
  }

  /// 切换任务展开状态
  void toggleTaskExpanded(int taskId) {
    final task = _tasks.firstWhere((t) => t.taskId == taskId, orElse: () => throw Exception('Task not found'));
    task.toggleExpanded();
    notifyListeners();
  }

  /// 清空已完成的任务
  void clearCompletedTasks() {
    _tasks.removeWhere((t) => t.status == TransferTaskStatus.completed);
    notifyListeners();
  }

  /// 清空所有任务
  void clearAllTasks() {
    _tasks.clear();
    notifyListeners();
  }
}