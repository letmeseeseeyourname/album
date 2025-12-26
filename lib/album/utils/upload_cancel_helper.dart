// utils/upload_cancel_helper.dart

import 'package:flutter/foundation.dart';

import '../../pages/local_album/controllers/upload_coordinator.dart';
import '../../user/my_instance.dart';
import '../database/database_helper.dart';
import '../database/download_task_db_helper.dart';
import '../database/upload_task_db_helper.dart';
import '../manager/download_queue_manager.dart';
import '../provider/album_provider.dart';

/// 任务取消帮助类
/// 用于切换 Group 或退出登录时统一取消上传/下载任务
class TaskCancelHelper {
  TaskCancelHelper._();

  /// 取消所有上传任务并清理相关数据
  static Future<void> cancelAllUploads() async {
    try {
      debugPrint('⏹️ 开始取消所有上传任务...');

      final userId = MyInstance().user?.user?.id ?? 0;
      final groupId = MyInstance().group?.groupId ?? 0;
      final deviceCode = MyInstance().deviceCode;
      final taskManager = UploadFileTaskManager.instance;
      final albumProvider = AlbumProvider();
      final dbHelper = DatabaseHelper.instance;

      try {
        final coordinator = UploadCoordinator.instance;

        if (coordinator.isUploading) {
          final activeCount = coordinator.activeTaskCount;
          debugPrint('📤 发现 $activeCount 个正在进行的上传任务');

          // ✅ 获取所有活跃任务的 taskId（在取消前获取）
          final activeTaskIds = coordinator.activeDbTaskIds;

          // 1. 取消所有内存中的上传任务（终止 mc.exe 进程）
          await coordinator.cancelAllUploads();
          debugPrint('✅ 内存中的上传任务已取消');

          // 2. 遍历每个任务：调用服务端 API + 更新数据库状态
          for (final taskId in activeTaskIds) {
            // 2.1 调用服务端 API 撤销任务
            try {
              debugPrint('📡 调用 revokeSyncTask: taskId=$taskId');
              final response = await albumProvider.revokeSyncTask(taskId);
              debugPrint('📡 Server revoke result: ${response.message}');
            } catch (e) {
              debugPrint('⚠️ revokeSyncTask 失败 (taskId=$taskId): $e');
            }

            // 2.2 更新 upload_tasks 表状态为 canceled
            if (userId > 0 && groupId > 0) {
              try {
                await taskManager.updateStatusForKey(
                  taskId: taskId,
                  userId: userId,
                  groupId: groupId,
                  status: UploadTaskStatus.canceled,
                );
                debugPrint('✅ upload_tasks 状态已更新: taskId=$taskId -> canceled');
              } catch (e) {
                debugPrint('⚠️ 更新 upload_tasks 状态失败 (taskId=$taskId): $e');
              }
            }
          }

          // 3. 清理 files 表中未完成的记录（status != 2）
          if (userId > 0 && deviceCode.isNotEmpty) {
            try {
              final deletedCount = await dbHelper.deleteIncompleteFiles(
                userId.toString(),
                deviceCode,
              );
              debugPrint('✅ files 表清理完成，删除 $deletedCount 条未完成记录');
            } catch (e) {
              debugPrint('⚠️ 清理 files 表失败: $e');
            }
          }

          debugPrint('✅ 所有上传任务已取消并更新状态');
        } else {
          debugPrint('ℹ️ 没有正在进行的上传任务');
        }
      } catch (e) {
        debugPrint('ℹ️ UploadCoordinator 未初始化，跳过取消上传: $e');
      }
    } catch (e) {
      debugPrint('❌ 取消上传任务失败: $e');
    }
  }

  /// 取消所有下载任务
  static Future<void> cancelAllDownloads() async {
    try {
      debugPrint('⏹️ 开始取消所有下载任务...');

      final downloadManager = DownloadQueueManager.instance;

      final activeTasks = downloadManager.downloadTasks.where(
            (t) => t.status == DownloadTaskStatus.downloading ||
            t.status == DownloadTaskStatus.pending,
      ).toList();

      if (activeTasks.isNotEmpty) {
        debugPrint('📥 发现 ${activeTasks.length} 个正在进行的下载任务');

        for (final task in activeTasks) {
          try {
            await downloadManager.cancelDownload(task.taskId);
            debugPrint('✅ 已取消下载: ${task.fileName}');
          } catch (e) {
            debugPrint('⚠️ 取消下载失败 (${task.fileName}): $e');
          }
        }

        debugPrint('✅ 所有下载任务已取消');
      } else {
        debugPrint('ℹ️ 没有正在进行的下载任务');
      }
    } catch (e) {
      debugPrint('❌ 取消下载任务失败: $e');
    }
  }

  /// 取消所有传输任务（上传 + 下载）
  static Future<void> cancelAllTransfers() async {
    await cancelAllUploads();
    await cancelAllDownloads();
  }
}