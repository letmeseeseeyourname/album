// ============================================
// 修复方案: 整合上传任务与传输记录显示
// ============================================

// 1. 修改 LocalFolderUploadManager,在上传时同步到 TransferManager
// 2. 在 TransferRecordPage 启动时从数据库加载历史任务
// 3. 提供任务状态同步机制

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../../models/transfer_task_model.dart';
import '../../manager/transfer_manager.dart';
import '../database/upload_task_db_helper.dart';

/// 传输任务集成服务
/// 负责将上传任务与UI显示层连接
class TransferTaskIntegration {
  static final TransferTaskIntegration _instance = TransferTaskIntegration._internal();
  factory TransferTaskIntegration() => _instance;
  TransferTaskIntegration._internal();

  final TransferManager _transferManager = TransferManager();
  final UploadFileTaskManager _taskDbManager = UploadFileTaskManager.instance;

  /// 创建新的传输任务并添加到管理器
  ///
  /// [taskId] 任务ID (从数据库获取)
  /// [filePaths] 文件路径列表
  /// [userId] 用户ID
  /// [groupId] 群组ID
  Future<TransferTaskModel> createTransferTask({
    required int taskId,
    required List<String> filePaths,
    required int userId,
    required int groupId,
  }) async {
    // 计算总大小
    int totalSize = 0;
    final fileItems = <TransferFileItem>[];

    for (var filePath in filePaths) {
      try {
        final file = File(filePath);
        final fileName = path.basename(filePath);
        final fileSize = await file.length();
        totalSize += fileSize;

        fileItems.add(TransferFileItem(
          fileName: fileName,
          filePath: filePath,
          fileSize: fileSize,
          progress: 0.0,
          status: TransferTaskStatus.uploading,
          uploadedSize: 0,
        ));
      } catch (e) {
        debugPrint('Error processing file $filePath: $e');
      }
    }

    // 创建任务模型
    final task = TransferTaskModel(
      taskId: taskId,
      createTime: DateTime.now(),
      totalCount: fileItems.length,
      totalSize: totalSize,
      completedCount: 0,
      uploadedSize: 0,
      status: TransferTaskStatus.uploading,
      fileItems: fileItems,
      isExpanded: false,
    );

    // 添加到传输管理器
    _transferManager.addTask(task);

    // 记录到数据库
    await _taskDbManager.upsertTask(
      taskId: taskId,
      userId: userId,
      groupId: groupId,
      status: UploadTaskStatus.uploading,
    );

    return task;
  }

  /// 更新文件上传进度
  ///
  /// [taskId] 任务ID
  /// [fileIndex] 文件索引
  /// [progress] 进度 (0.0-1.0)
  /// [uploadedSize] 已上传字节数
  void updateFileProgress({
    required int taskId,
    required int fileIndex,
    required double progress,
    required int uploadedSize,
  }) {
    _transferManager.updateFileProgress(taskId, fileIndex, progress, uploadedSize);
  }

  /// 标记任务完成
  ///
  /// [taskId] 任务ID
  /// [userId] 用户ID
  /// [groupId] 群组ID
  Future<void> completeTask({
    required int taskId,
    required int userId,
    required int groupId,
  }) async {
    // 更新数据库状态
    await _taskDbManager.updateStatusForKey(
      taskId: taskId,
      userId: userId,
      groupId: groupId,
      status: UploadTaskStatus.success,
    );

    // 更新UI状态 (通过 TransferManager 会自动触发)
    // 任务状态会在所有文件完成时自动变为 completed
  }

  /// 标记任务失败
  ///
  /// [taskId] 任务ID
  /// [userId] 用户ID
  /// [groupId] 群组ID
  Future<void> failTask({
    required int taskId,
    required int userId,
    required int groupId,
  }) async {
    await _taskDbManager.updateStatusForKey(
      taskId: taskId,
      userId: userId,
      groupId: groupId,
      status: UploadTaskStatus.failed,
    );

    // 更新UI中的任务状态
    final tasks = _transferManager.tasks;
    final taskIndex = tasks.indexWhere((t) => t.taskId == taskId);
    if (taskIndex >= 0) {
      final task = tasks[taskIndex];
      _transferManager.updateTask(
        taskId,
        task.copyWith(status: TransferTaskStatus.failed),
      );
    }
  }

  /// 取消任务
  ///
  /// [taskId] 任务ID
  /// [userId] 用户ID
  /// [groupId] 群组ID
  Future<void> cancelTask({
    required int taskId,
    required int userId,
    required int groupId,
  }) async {
    await _taskDbManager.updateStatusForKey(
      taskId: taskId,
      userId: userId,
      groupId: groupId,
      status: UploadTaskStatus.canceled,
    );

    _transferManager.pauseTask(taskId);
  }

  /// 从数据库加载历史任务
  ///
  /// [userId] 用户ID
  /// [groupId] 群组ID
  /// [limit] 加载数量限制
  Future<void> loadHistoryTasks({
    required int userId,
    required int groupId,
    int? limit,
  }) async {
    try {
      // 从数据库查询任务记录
      final taskRecords = await _taskDbManager.listTasks(
        userId: userId,
        groupId: groupId,
        limit: limit,
      );

      debugPrint('Loaded ${taskRecords.length} history tasks from database');

      // 转换为 TransferTaskModel 并添加到管理器
      for (var record in taskRecords) {
        // 将数据库状态映射到UI状态
        TransferTaskStatus uiStatus;
        switch (record.status) {
          case UploadTaskStatus.uploading:
            uiStatus = TransferTaskStatus.uploading;
            break;
          case UploadTaskStatus.success:
            uiStatus = TransferTaskStatus.completed;
            break;
          case UploadTaskStatus.failed:
            uiStatus = TransferTaskStatus.failed;
            break;
          case UploadTaskStatus.canceled:
            uiStatus = TransferTaskStatus.paused;
            break;
          default:
            uiStatus = TransferTaskStatus.paused;
        }

        // 注意: 从数据库恢复时,我们没有文件详细信息
        // 这里创建一个占位任务,实际项目中可能需要额外的文件记录表
        final task = TransferTaskModel(
          taskId: record.taskId,
          createTime: DateTime.fromMillisecondsSinceEpoch(record.createdAt),
          totalCount: 0, // 从数据库无法获取,需要额外存储
          totalSize: 0,  // 从数据库无法获取,需要额外存储
          completedCount: uiStatus == TransferTaskStatus.completed ? 0 : 0,
          uploadedSize: 0,
          status: uiStatus,
          fileItems: [], // 文件列表需要从其他地方获取
          isExpanded: false,
        );

        _transferManager.addTask(task);
      }
    } catch (e) {
      debugPrint('Error loading history tasks: $e');
    }
  }

  /// 清理已完成的任务 (同时清理数据库和内存)
  ///
  /// [userId] 用户ID
  /// [groupId] 群组ID
  Future<void> clearCompletedTasks({
    required int userId,
    required int groupId,
  }) async {
    // 获取已完成的任务
    final completedTasks = _transferManager.tasks
        .where((t) => t.status == TransferTaskStatus.completed)
        .toList();

    // 从数据库删除
    for (var task in completedTasks) {
      await _taskDbManager.deleteTaskForKey(
        taskId: task.taskId,
        userId: userId,
        groupId: groupId,
      );
    }

    // 从内存清除
    _transferManager.clearCompletedTasks();
  }

  /// 获取传输管理器实例 (供UI使用)
  TransferManager get transferManager => _transferManager;
}

// ============================================
// 需要添加到 upload_task_db_helper.dart 的扩展
// ============================================

/// 任务详情表 - 存储文件列表信息
///
/// 建议在 UploadFileTaskManager 中添加以下表和方法:
///
/// CREATE TABLE upload_task_files (
///   task_id INTEGER NOT NULL,
///   user_id INTEGER NOT NULL,
///   group_id INTEGER NOT NULL,
///   file_path TEXT NOT NULL,
///   file_name TEXT NOT NULL,
///   file_size INTEGER NOT NULL,
///   uploaded_size INTEGER NOT NULL DEFAULT 0,
///   status INTEGER NOT NULL,
///   created_at INTEGER NOT NULL,
///   FOREIGN KEY (task_id, user_id, group_id)
///     REFERENCES upload_tasks(task_id, user_id, group_id)
/// );