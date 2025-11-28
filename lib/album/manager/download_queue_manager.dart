// download_queue_manager.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../../../user/my_instance.dart';
import '../../../user/models/resource_list_model.dart';
import '../../../network/constant_sign.dart';
import '../../../services/transfer_speed_service.dart';
import '../database/download_task_db_helper.dart';


/// 下载队列管理器
class DownloadQueueManager extends ChangeNotifier {
  static final DownloadQueueManager instance = DownloadQueueManager._init();
  DownloadQueueManager._init();

  final DownloadTaskDbHelper _dbHelper = DownloadTaskDbHelper.instance;
  final Dio _dio = Dio();

  // 当前用户和群组信息
  int? _currentUserId;
  int? _currentGroupId;

  // 下载任务列表
  final List<DownloadTaskRecord> _downloadTasks = [];

  // 当前正在下载的任务
  final Map<String, CancelToken> _activeTasks = {};

  // 最大并发下载数
  static const int maxConcurrentDownloads = 3;

  // 下载目录
  String _downloadPath = '';

  // 获取所有任务
  List<DownloadTaskRecord> get downloadTasks => List.unmodifiable(_downloadTasks);

  // 获取当前下载路径
  String get downloadPath => _downloadPath;

  // 获取正在下载的任务数量
  int get activeDownloadCount => _activeTasks.length;

  // 获取等待中的任务数量
  int get pendingCount => _downloadTasks.where((t) => t.status == DownloadTaskStatus.pending).length;

  // 获取已完成的任务数量
  int get completedCount => _downloadTasks.where((t) => t.status == DownloadTaskStatus.completed).length;

  // 获取失败的任务数量
  int get failedCount => _downloadTasks.where((t) => t.status == DownloadTaskStatus.failed).length;

  /// 初始化管理器
  Future<void> initialize({
    required int userId,
    required int groupId,
    required String downloadPath,
  }) async {
    debugPrint('=== 初始化下载队列管理器 ===');
    debugPrint('userId: $userId, groupId: $groupId');
    debugPrint('downloadPath: $downloadPath');

    _currentUserId = userId;
    _currentGroupId = groupId;
    _downloadPath = downloadPath;

    // 确保下载目录存在
    final dir = Directory(_downloadPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      debugPrint('创建下载目录: $_downloadPath');
    }

    // 加载未完成的任务
    await _loadIncompleteTasks();

    // 自动恢复下载
    if (_downloadTasks.isNotEmpty) {
      debugPrint('发现 ${_downloadTasks.length} 个未完成任务，准备恢复');
      await resumeAllPendingDownloads();
    }
  }

  /// 使用 MyInstance 初始化（便捷方法）
  Future<void> initializeWithMyInstance({
    required int userId,
    required int groupId,
  }) async {
    final downloadPath = await MyInstance().getDownloadPath();
    await initialize(
      userId: userId,
      groupId: groupId,
      downloadPath: downloadPath,
    );
  }

  /// 更新下载路径
  Future<void> updateDownloadPath(String newPath) async {
    _downloadPath = newPath;

    // 确保新目录存在
    final dir = Directory(_downloadPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    debugPrint('下载路径已更新为: $_downloadPath');
    notifyListeners();
  }

  /// 加载未完成的任务
  Future<void> _loadIncompleteTasks() async {
    if (_currentUserId == null || _currentGroupId == null) {
      debugPrint('错误：无法加载任务，用户或群组ID为空');
      return;
    }

    try {
      debugPrint('正在从数据库加载未完成任务...');
      final tasks = await _dbHelper.getIncompleteTasks(
        userId: _currentUserId!,
        groupId: _currentGroupId!,
      );

      _downloadTasks.clear();
      _downloadTasks.addAll(tasks);

      debugPrint('加载未完成任务: ${tasks.length}个');
      for (final task in tasks) {
        debugPrint('  - ${task.fileName} (${task.status.name})');
      }

      notifyListeners();
    } catch (e, stack) {
      debugPrint('加载未完成任务失败: $e');
      debugPrint('堆栈: $stack');
    }
  }

  /// 添加下载任务（从资源列表）
  Future<void> addDownloadTasks(List<ResList> resources) async {
    debugPrint('=== addDownloadTasks 开始 ===');
    debugPrint('currentUserId: $_currentUserId, currentGroupId: $_currentGroupId');

    if (_currentUserId == null || _currentGroupId == null) {
      debugPrint('错误：用户ID或群组ID为空');
      return;
    }

    // 确保使用最新的下载路径
    final currentDownloadPath = await MyInstance().getDownloadPath();
    if (currentDownloadPath != _downloadPath) {
      _downloadPath = currentDownloadPath;
      debugPrint('更新下载路径为: $_downloadPath');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final newTasks = <DownloadTaskRecord>[];
    int skippedCount = 0;
    int invalidCount = 0;

    for (final resource in resources) {
      // 检查必要字段
      if (resource.resId == null || resource.resId!.isEmpty) {
        debugPrint('警告：资源缺少resId: ${resource.fileName}');
        invalidCount++;
        continue;
      }

      if (resource.originPath == null || resource.originPath!.isEmpty) {
        debugPrint('警告：资源缺少filePath: ${resource.fileName}');
        invalidCount++;
        continue;
      }

      // 检查任务是否已存在
      final exists = _downloadTasks.any((t) => t.taskId == resource.resId);
      if (exists) {
        debugPrint('任务已存在: ${resource.fileName}');
        skippedCount++;
        continue;
      }

      // 构建下载URL
      final downloadUrl = "${AppConfig.minio()}/${resource.originPath}";
      final thumbnailUrl = resource.thumbnailPath != null
          ? "${AppConfig.minio()}/${resource.thumbnailPath}"
          : null;

      debugPrint('创建任务: ${resource.fileName}');
      debugPrint('  resId: ${resource.resId}');
      debugPrint('  downloadUrl: $downloadUrl');
      debugPrint('  fileSize: ${resource.fileSize}');

      // 创建任务记录
      final task = DownloadTaskRecord(
        taskId: resource.resId!,
        userId: _currentUserId!,
        groupId: _currentGroupId!,
        fileName: resource.fileName ?? 'unknown_${resource.resId}',
        filePath: resource.originPath,
        thumbnailUrl: thumbnailUrl,
        downloadUrl: downloadUrl,
        fileSize: resource.fileSize ?? 0,
        downloadedSize: 0,
        fileType: resource.fileType ?? 'P',
        status: DownloadTaskStatus.pending,
        savePath: p.join(_downloadPath, resource.fileName ?? 'unknown_${resource.resId}'),
        createdAt: now,
        updatedAt: now,
      );

      newTasks.add(task);
      _downloadTasks.add(task);
    }

    debugPrint('任务统计: 新增=${newTasks.length}, 跳过=${skippedCount}, 无效=${invalidCount}');

    if (newTasks.isNotEmpty) {
      try {
        // 批量保存到数据库
        await _dbHelper.insertTasks(newTasks);
        debugPrint('成功保存到数据库: ${newTasks.length}个任务');
        notifyListeners();

        // 自动开始下载
        _processNextDownload();
      } catch (e) {
        debugPrint('保存到数据库失败: $e');
        // 从内存中移除失败的任务
        for (final task in newTasks) {
          _downloadTasks.removeWhere((t) => t.taskId == task.taskId);
        }
        notifyListeners();
      }
    } else {
      debugPrint('没有有效的新任务需要添加');
      notifyListeners();
    }
  }

  /// 开始/恢复下载任务
  Future<void> startDownload(String taskId) async {
    final taskIndex = _downloadTasks.indexWhere((t) => t.taskId == taskId);
    if (taskIndex == -1) return;

    final task = _downloadTasks[taskIndex];

    // 检查是否已在下载
    if (_activeTasks.containsKey(taskId)) {
      debugPrint('任务已在下载: ${task.fileName}');
      return;
    }

    // 检查并发限制
    if (_activeTasks.length >= maxConcurrentDownloads) {
      debugPrint('达到最大并发数，任务等待: ${task.fileName}');
      return;
    }

    // 创建取消令牌
    final cancelToken = CancelToken();
    _activeTasks[taskId] = cancelToken;

    // 更新状态为下载中
    _downloadTasks[taskIndex] = task.copyWith(
      status: DownloadTaskStatus.downloading,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();

    await _dbHelper.updateStatus(
      taskId: taskId,
      userId: _currentUserId!,
      groupId: _currentGroupId!,
      status: DownloadTaskStatus.downloading,
    );

    // 启动传输速率监控
    TransferSpeedService.instance.startMonitoring();

    try {
      // 确保保存目录存在
      final saveFile = File(task.savePath!);
      final saveDir = saveFile.parent;
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      // 检查是否支持断点续传
      int downloadedSize = 0;
      if (await saveFile.exists()) {
        downloadedSize = await saveFile.length();
      }

      // 开始下载
      debugPrint('开始下载: ${task.fileName} (已下载: $downloadedSize/${task.fileSize})');

      await _dio.download(
        task.downloadUrl,
        task.savePath,
        cancelToken: cancelToken,
        deleteOnError: false,
        options: Options(
          headers: downloadedSize > 0
              ? {'Range': 'bytes=$downloadedSize-'}
              : null,
        ),
        onReceiveProgress: (received, total) {
          final totalSize = downloadedSize + total;
          final currentSize = downloadedSize + received;

          // 更新传输速率服务
          TransferSpeedService.instance.updateDownloadProgress(currentSize);

          // 更新进度
          final index = _downloadTasks.indexWhere((t) => t.taskId == taskId);
          if (index != -1) {
            _downloadTasks[index] = _downloadTasks[index].copyWith(
              downloadedSize: currentSize,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            );
            notifyListeners();

            // 定期更新数据库（每10%更新一次）
            final progress = currentSize / totalSize;
            if ((progress * 10).floor() > ((currentSize - received) / totalSize * 10).floor()) {
              _dbHelper.updateProgress(
                taskId: taskId,
                userId: _currentUserId!,
                groupId: _currentGroupId!,
                downloadedSize: currentSize,
              );
            }
          }
        },
      );

      // 下载完成
      debugPrint('下载完成: ${task.fileName}');

      final index = _downloadTasks.indexWhere((t) => t.taskId == taskId);
      if (index != -1) {
        _downloadTasks[index] = _downloadTasks[index].copyWith(
          status: DownloadTaskStatus.completed,
          downloadedSize: task.fileSize,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        notifyListeners();
      }

      await _dbHelper.updateStatus(
        taskId: taskId,
        userId: _currentUserId!,
        groupId: _currentGroupId!,
        status: DownloadTaskStatus.completed,
      );

    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        // 用户取消
        debugPrint('下载取消: ${task.fileName}');
        final index = _downloadTasks.indexWhere((t) => t.taskId == taskId);
        if (index != -1) {
          _downloadTasks[index] = _downloadTasks[index].copyWith(
            status: DownloadTaskStatus.canceled,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
          notifyListeners();
        }

        await _dbHelper.updateStatus(
          taskId: taskId,
          userId: _currentUserId!,
          groupId: _currentGroupId!,
          status: DownloadTaskStatus.canceled,
        );
      } else {
        // 下载失败
        debugPrint('下载失败: ${task.fileName}, 错误: $e');
        final index = _downloadTasks.indexWhere((t) => t.taskId == taskId);
        if (index != -1) {
          _downloadTasks[index] = _downloadTasks[index].copyWith(
            status: DownloadTaskStatus.failed,
            errorMessage: e.toString(),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
          notifyListeners();
        }

        await _dbHelper.updateStatus(
          taskId: taskId,
          userId: _currentUserId!,
          groupId: _currentGroupId!,
          status: DownloadTaskStatus.failed,
          errorMessage: e.toString(),
        );
      }
    } finally {
      // 清理活动任务
      _activeTasks.remove(taskId);

      // 如果没有活动任务了，停止速率监控
      if (_activeTasks.isEmpty) {
        TransferSpeedService.instance.onDownloadComplete();
      }

      // 处理下一个任务
      _processNextDownload();
    }
  }

  /// 暂停下载
  Future<void> pauseDownload(String taskId) async {
    final cancelToken = _activeTasks[taskId];
    if (cancelToken != null) {
      cancelToken.cancel('User paused');
      _activeTasks.remove(taskId);

      final index = _downloadTasks.indexWhere((t) => t.taskId == taskId);
      if (index != -1) {
        _downloadTasks[index] = _downloadTasks[index].copyWith(
          status: DownloadTaskStatus.paused,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        notifyListeners();

        await _dbHelper.updateStatus(
          taskId: taskId,
          userId: _currentUserId!,
          groupId: _currentGroupId!,
          status: DownloadTaskStatus.paused,
        );
      }
    }
  }

  /// 取消下载
  Future<void> cancelDownload(String taskId) async {
    // 停止下载
    await pauseDownload(taskId);

    // 删除文件
    final task = _downloadTasks.firstWhere((t) => t.taskId == taskId);
    if (task.savePath != null) {
      final file = File(task.savePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // 从列表和数据库中删除
    _downloadTasks.removeWhere((t) => t.taskId == taskId);
    await _dbHelper.deleteTask(
      taskId: taskId,
      userId: _currentUserId!,
      groupId: _currentGroupId!,
    );

    notifyListeners();
  }

  /// 重试失败的下载
  Future<void> retryDownload(String taskId) async {
    final index = _downloadTasks.indexWhere((t) => t.taskId == taskId);
    if (index != -1) {
      _downloadTasks[index] = _downloadTasks[index].copyWith(
        status: DownloadTaskStatus.pending,
        errorMessage: null,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      notifyListeners();

      await _dbHelper.updateStatus(
        taskId: taskId,
        userId: _currentUserId!,
        groupId: _currentGroupId!,
        status: DownloadTaskStatus.pending,
      );

      _processNextDownload();
    }
  }

  /// 恢复所有待下载任务
  Future<void> resumeAllPendingDownloads() async {
    // 将所有下载中的任务重置为待下载
    for (int i = 0; i < _downloadTasks.length; i++) {
      if (_downloadTasks[i].status == DownloadTaskStatus.downloading) {
        _downloadTasks[i] = _downloadTasks[i].copyWith(
          status: DownloadTaskStatus.pending,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        await _dbHelper.updateStatus(
          taskId: _downloadTasks[i].taskId,
          userId: _currentUserId!,
          groupId: _currentGroupId!,
          status: DownloadTaskStatus.pending,
        );
      }
    }
    notifyListeners();

    // 开始处理队列
    for (int i = 0; i < maxConcurrentDownloads; i++) {
      _processNextDownload();
    }
  }

  /// 处理下一个待下载任务
  void _processNextDownload() {
    debugPrint('=== 处理下一个下载任务 ===');
    debugPrint('当前活动任务数: ${_activeTasks.length}');
    debugPrint('最大并发数: $maxConcurrentDownloads');

    if (_activeTasks.length >= maxConcurrentDownloads) {
      debugPrint('已达到最大并发数，等待中...');
      return;
    }

    // 找到下一个待下载任务
    final nextTask = _downloadTasks.firstWhere(
          (t) => t.status == DownloadTaskStatus.pending,
      orElse: () => DownloadTaskRecord(
        taskId: '',
        userId: 0,
        groupId: 0,
        fileName: '',
        downloadUrl: '',
        fileSize: 0,
        fileType: '',
        status: DownloadTaskStatus.completed,
        createdAt: 0,
        updatedAt: 0,
      ),
    );

    if (nextTask.taskId.isNotEmpty) {
      debugPrint('找到待下载任务: ${nextTask.fileName} (${nextTask.taskId})');
      startDownload(nextTask.taskId);
    } else {
      debugPrint('没有待下载的任务了');
    }
  }

  /// 清理已完成的任务
  Future<void> clearCompletedTasks() async {
    final completedIds = _downloadTasks
        .where((t) => t.status == DownloadTaskStatus.completed)
        .map((t) => t.taskId)
        .toList();

    if (completedIds.isNotEmpty) {
      _downloadTasks.removeWhere((t) => completedIds.contains(t.taskId));
      await _dbHelper.deleteTasks(completedIds, _currentUserId!, _currentGroupId!);
      notifyListeners();
    }
  }

  /// 获取下载统计
  Future<Map<String, int>> getStatistics() async {
    if (_currentUserId == null || _currentGroupId == null) {
      return {};
    }

    return await _dbHelper.getStatistics(
      userId: _currentUserId!,
      groupId: _currentGroupId!,
    );
  }

  @override
  void dispose() {
    // 取消所有活动下载
    for (final cancelToken in _activeTasks.values) {
      cancelToken.cancel();
    }
    _activeTasks.clear();
    _dio.close();
    super.dispose();
  }
}