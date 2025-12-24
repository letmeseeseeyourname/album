// download_queue_manager.dart (增强版 - 添加多轮重试队列机制)
import 'dart:async';
import 'dart:io';
import 'package:ablumwin/utils/snack_bar_helper.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../../user/my_instance.dart';
import '../../../user/models/resource_list_model.dart';
import '../../../network/constant_sign.dart';
import '../../../services/transfer_speed_service.dart';
import '../../../eventbus/event_bus.dart';
import '../../../eventbus/download_events.dart'; // 新增：导入下载事件
import '../../pages/remote_album/components/album_bottom_bar.dart';
import '../database/download_task_db_helper.dart';
import 'package:ablumwin/main.dart';

/// 下载队列管理器（增强版 - 多轮重试队列机制）
class DownloadQueueManager extends ChangeNotifier {
  static final DownloadQueueManager instance = DownloadQueueManager._init();

  DownloadQueueManager._init();

  final DownloadTaskDbHelper _dbHelper = DownloadTaskDbHelper.instance;
  final Dio _dio = Dio();
  final Uuid _uuid = const Uuid(); // ✅ 新增
  // 当前用户和群组信息
  int? _currentUserId;
  int? _currentGroupId;

  // 下载任务列表
  final List<DownloadTaskRecord> _downloadTasks = [];

  // 当前正在下载的任务
  final Map<String, CancelToken> _activeTasks = {};

  // ==================== 重试配置 ====================
  // 最大并发下载数
  static const int maxConcurrentDownloads = 3;

  // 单文件连接错误自动重试次数
  static const int _maxConnectionRetries = 3;

  // 🆕 失败队列最大重试轮次
  static const int _maxRetryRounds = 6;

  // 🆕 每轮重试前的等待时间（秒）
  static const int _retryRoundDelaySeconds = 5;

  // 记录每个任务的重试次数
  final Map<String, int> _taskRetryCount = {};

  // 🆕 失败队列（等待批量重试）
  final List<DownloadTaskRecord> _failedQueue = [];

  // 🆕 永久失败列表（超过重试轮次）
  final List<DownloadTaskRecord> _permanentlyFailedTasks = [];

  // 🆕 当前重试轮次
  int _currentRetryRound = 0;

  // 🆕 是否正在进行批量重试
  bool _isRetrying = false;

  // 连接预热状态（避免重复预热）
  bool _isConnectionWarmedUp = false;
  DateTime? _lastWarmUpTime;
  static const Duration _warmUpValidDuration = Duration(minutes: 5);

  // 下载目录
  String _downloadPath = '';

  // ==================== Getters ====================
  // 获取所有任务
  List<DownloadTaskRecord> get downloadTasks =>
      List.unmodifiable(_downloadTasks);

  // 获取当前下载路径
  String get downloadPath => _downloadPath;

  // 获取正在下载的任务数量
  int get activeDownloadCount => _activeTasks.length;

  // 获取等待中的任务数量
  int get pendingCount =>
      _downloadTasks
          .where((t) => t.status == DownloadTaskStatus.pending)
          .length;

  // 获取已完成的任务数量
  int get completedCount =>
      _downloadTasks
          .where((t) => t.status == DownloadTaskStatus.completed)
          .length;

  // 获取失败的任务数量
  int get failedCount =>
      _downloadTasks
          .where((t) => t.status == DownloadTaskStatus.failed)
          .length;

  // 🆕 获取失败队列
  List<DownloadTaskRecord> get failedQueue => List.unmodifiable(_failedQueue);

  // 🆕 获取永久失败列表
  List<DownloadTaskRecord> get permanentlyFailedTasks =>
      List.unmodifiable(_permanentlyFailedTasks);

  // 🆕 获取当前重试轮次
  int get currentRetryRound => _currentRetryRound;

  // 🆕 获取最大重试轮次
  int get maxRetryRounds => _maxRetryRounds;

  // 🆕 是否正在重试
  bool get isRetrying => _isRetrying;

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

  /// 🆕 预热连接（唤醒 P2P 隧道）
  Future<bool> _warmUpConnection() async {
    // 检查是否需要预热
    if (_isConnectionWarmedUp && _lastWarmUpTime != null) {
      final elapsed = DateTime.now().difference(_lastWarmUpTime!);
      if (elapsed < _warmUpValidDuration) {
        debugPrint('连接预热仍有效，跳过预热');
        return true;
      }
    }

    final baseUrl = AppConfig.minio();
    debugPrint('开始预热连接: $baseUrl');

    try {
      // 发送轻量级 HEAD 请求唤醒隧道
      await _dio.head(
        baseUrl,
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          validateStatus: (status) => true, // 接受任何状态码
        ),
      );

      _isConnectionWarmedUp = true;
      _lastWarmUpTime = DateTime.now();
      debugPrint('连接预热成功');
      return true;
    } catch (e) {
      debugPrint('连接预热失败（这是正常的，隧道可能正在建立）: $e');

      // 等待一小段时间让隧道建立
      await Future.delayed(const Duration(milliseconds: 500));

      // 再试一次
      try {
        await _dio.head(
          baseUrl,
          options: Options(
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
            validateStatus: (status) => true,
          ),
        );

        _isConnectionWarmedUp = true;
        _lastWarmUpTime = DateTime.now();
        debugPrint('连接预热第二次尝试成功');
        return true;
      } catch (e2) {
        debugPrint('连接预热第二次尝试也失败: $e2');
        // 即使预热失败，也继续下载，让下载逻辑处理重试
        return false;
      }
    }
  }

  /// 🆕 检查是否是连接关闭错误（P2P 隧道冷启动问题）
  bool _isConnectionClosedError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('connection closed') ||
        errorStr.contains('connection reset') ||
        errorStr.contains('socket') ||
        errorStr.contains('broken pipe') ||
        (error is DioException &&
            error.type == DioExceptionType.unknown &&
            error.error is HttpException);
  }

  /// 添加下载任务（从资源列表）
  /// ✅ 修改：为同一批次的任务生成相同的 batchId
  Future<void> addDownloadTasks(List<ResList> resources) async {
    debugPrint('=== addDownloadTasks 开始 ===');
    debugPrint(
        'currentUserId: $_currentUserId, currentGroupId: $_currentGroupId');

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

    final now = DateTime
        .now()
        .millisecondsSinceEpoch;
    final newTasks = <DownloadTaskRecord>[];
    int skippedCount = 0;
    int invalidCount = 0;

    // ✅ 为这一批次生成唯一的 batchId
    final batchId = _uuid.v4();
    debugPrint('生成批次ID: $batchId');

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
        savePath: p.join(
            _downloadPath, resource.fileName ?? 'unknown_${resource.resId}'),
        createdAt: now,
        updatedAt: now,
        batchId: batchId, // ✅ 使用统一的批次ID
      );

      newTasks.add(task);
      _downloadTasks.add(task);
    }

    debugPrint('任务统计: 新增=${newTasks
        .length}, 跳过=${skippedCount}, 无效=${invalidCount}');

    if (newTasks.isNotEmpty) {
      try {
        await _dbHelper.insertTasks(newTasks);
        debugPrint('成功保存到数据库: ${newTasks.length}个任务');

        await _warmUpConnection();
        notifyListeners();
        _processNextDownload();
      } catch (e) {
        debugPrint('保存到数据库失败: $e');
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
    // GlobalSnackBar.showInfo('startDownload : $taskIndex ',duration: const Duration(seconds: 1));
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
      updatedAt: DateTime
          .now()
          .millisecondsSinceEpoch,
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

      // 🆕 检查文件是否已完全下载，如果是则生成新文件名重新下载（避免 416 错误）
      String actualSavePath = task.savePath!;
      if (downloadedSize >= task.fileSize && task.fileSize > 0) {
        debugPrint('文件已存在且完整，生成新文件名重新下载: ${task.fileName}');

        // 生成新文件名: fileName(n).ext
        actualSavePath = _generateUniqueFilePath(task.savePath!);
        downloadedSize = 0; // 重置已下载大小，从头开始下载

        debugPrint('新保存路径: $actualSavePath');

        // 更新任务的保存路径
        final index = _downloadTasks.indexWhere((t) => t.taskId == taskId);
        if (index != -1) {
          _downloadTasks[index] = _downloadTasks[index].copyWith(
            savePath: actualSavePath,
            updatedAt: DateTime
                .now()
                .millisecondsSinceEpoch,
          );
          notifyListeners();
        }

        // 更新数据库中的保存路径
        await _dbHelper.updateSavePath(
          taskId: taskId,
          userId: _currentUserId!,
          groupId: _currentGroupId!,
          savePath: actualSavePath,
        );
      }

      // 开始下载
      debugPrint('开始下载: ${task.fileName} (已下载: $downloadedSize/${task
          .fileSize})');

      await _dio.download(
        task.downloadUrl,
        actualSavePath,
        cancelToken: cancelToken,
        deleteOnError: false,
        options: Options(
          headers: downloadedSize > 0
              ? {'Range': 'bytes=$downloadedSize-'}
              : null,
          // 🆕 增加超时时间，给 P2P 隧道更多建立连接的时间
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
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
              updatedAt: DateTime
                  .now()
                  .millisecondsSinceEpoch,
            );
            notifyListeners();

            // 定期更新数据库（每10%更新一次）
            final progress = currentSize / totalSize;
            if ((progress * 10).floor() >
                ((currentSize - received) / totalSize * 10).floor()) {
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

      // 🆕 清除重试计数
      _taskRetryCount.remove(taskId);

      final index = _downloadTasks.indexWhere((t) => t.taskId == taskId);
      if (index != -1) {
        _downloadTasks[index] = _downloadTasks[index].copyWith(
          status: DownloadTaskStatus.completed,
          downloadedSize: task.fileSize,
          updatedAt: DateTime
              .now()
              .millisecondsSinceEpoch,
        );
        notifyListeners();
      }

      await _dbHelper.updateStatus(
        taskId: taskId,
        userId: _currentUserId!,
        groupId: _currentGroupId!,
        status: DownloadTaskStatus.completed,
      );

      // 🆕 发送下载完成事件
      MCEventBus.fire(DownloadCompleteEvent(
        taskId: taskId,
        fileName: task.fileName,
        savePath: task.savePath,
      ));
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        // 用户取消
        debugPrint('下载取消: ${task.fileName}');
        _taskRetryCount.remove(taskId); // 清除重试计数

        final index = _downloadTasks.indexWhere((t) => t.taskId == taskId);
        if (index != -1) {
          _downloadTasks[index] = _downloadTasks[index].copyWith(
            status: DownloadTaskStatus.canceled,
            updatedAt: DateTime
                .now()
                .millisecondsSinceEpoch,
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
        // 🆕 检查是否是连接关闭错误，如果是则自动重试
        final isConnectionError = _isConnectionClosedError(e);
        final currentRetry = _taskRetryCount[taskId] ?? 0;

        debugPrint('下载失败: ${task.fileName}, 错误: $e');
        debugPrint(
            '是否连接错误: $isConnectionError, 当前重试次数: $currentRetry');

        if (isConnectionError && currentRetry < _maxConnectionRetries) {
          // 自动重试
          _taskRetryCount[taskId] = currentRetry + 1;
          debugPrint('连接错误，将在1秒后自动重试 (${currentRetry +
              1}/$_maxConnectionRetries)');

          // 标记连接需要重新预热
          _isConnectionWarmedUp = false;

          // 更新状态为待下载
          final index = _downloadTasks.indexWhere((t) => t.taskId == taskId);
          if (index != -1) {
            _downloadTasks[index] = _downloadTasks[index].copyWith(
              status: DownloadTaskStatus.pending,
              updatedAt: DateTime
                  .now()
                  .millisecondsSinceEpoch,
            );
            notifyListeners();
          }

          await _dbHelper.updateStatus(
            taskId: taskId,
            userId: _currentUserId!,
            groupId: _currentGroupId!,
            status: DownloadTaskStatus.pending,
          );

          // 清理当前活动任务，延迟后重试
          _activeTasks.remove(taskId);

          // 延迟重试，给隧道时间恢复
          Future.delayed(const Duration(seconds: 1), () async {
            // 预热连接
            await _warmUpConnection();
            // 重新处理下载队列
            _processNextDownload();
          });

          return; // 不执行 finally 中的 _processNextDownload
        }

        // 超过重试次数或非连接错误，标记为失败
        _taskRetryCount.remove(taskId);

        final index = _downloadTasks.indexWhere((t) => t.taskId == taskId);
        if (index != -1) {
          _downloadTasks[index] = _downloadTasks[index].copyWith(
            status: DownloadTaskStatus.failed,
            errorMessage: e.toString(),
            updatedAt: DateTime
                .now()
                .millisecondsSinceEpoch,
          );

          // 🆕 如果正在批量重试模式，将任务添加到失败队列
          if (_isRetrying) {
            _addToFailedQueue(_downloadTasks[index]);
          }

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
          updatedAt: DateTime
              .now()
              .millisecondsSinceEpoch,
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

  /// 取消下载（增强版 - 从内存和数据库中移除）
  /// ✅ 修改：取消下载（只更新状态，不删除记录）
  Future<void> cancelDownload(String taskId) async {
    // 清除重试计数
    _taskRetryCount.remove(taskId);

    // 取消正在进行的下载
    final cancelToken = _activeTasks[taskId];
    if (cancelToken != null) {
      cancelToken.cancel('User canceled');
      _activeTasks.remove(taskId);
    }

    // 删除临时文件
    final taskIndex = _downloadTasks.indexWhere((t) => t.taskId == taskId);
    if (taskIndex != -1) {
      final task = _downloadTasks[taskIndex];

      // 删除未完成的临时文件
      if (task.savePath != null &&
          task.status != DownloadTaskStatus.completed) {
        final file = File(task.savePath!);
        if (await file.exists()) {
          await file.delete();
          debugPrint('已删除临时文件: ${task.savePath}');
        }
      }

      // ✅ 更新状态为已取消（不从列表中移除）
      _downloadTasks[taskIndex] = task.copyWith(
        status: DownloadTaskStatus.canceled,
        updatedAt: DateTime
            .now()
            .millisecondsSinceEpoch,
      );
    }

    // ✅ 更新数据库状态（不删除）
    if (_currentUserId != null && _currentGroupId != null) {
      await _dbHelper.updateStatus(
        taskId: taskId,
        userId: _currentUserId!,
        groupId: _currentGroupId!,
        status: DownloadTaskStatus.canceled,
      );
    }

    notifyListeners();

    // 处理下一个任务
    _processNextDownload();
  }


  /// ✅ 新增：取消整个批次的下载
  Future<void> cancelBatch(String batchId) async {
    final tasksInBatch = _downloadTasks.where((t) => t.batchId == batchId).toList();

    for (final task in tasksInBatch) {
      if (task.status == DownloadTaskStatus.downloading ||
          task.status == DownloadTaskStatus.pending) {
        await cancelDownload(task.taskId);
      }
    }
  }


  /// 重试失败的下载
  Future<void> retryDownload(String taskId) async {
    // 重置重试计数
    _taskRetryCount.remove(taskId);

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

      // 先预热连接再下载
      await _warmUpConnection();
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

    // 🆕 恢复前预热连接
    await _warmUpConnection();

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

  // ==================== 🆕 增强重试功能 ====================

  /// 🆕 重试所有失败的下载任务
  Future<void> retryAllFailedDownloads() async {
    final failedTasks = _downloadTasks
        .where((t) => t.status == DownloadTaskStatus.failed)
        .toList();

    if (failedTasks.isEmpty) {
      debugPrint('没有失败的任务需要重试');
      return;
    }

    debugPrint('═══════════════════════════════════════════');
    debugPrint('批量重试 ${failedTasks.length} 个失败任务');
    debugPrint('═══════════════════════════════════════════');

    // 重置重试状态
    _failedQueue.clear();
    _permanentlyFailedTasks.clear();
    _currentRetryRound = 0;
    _isRetrying = true;

    // 将失败任务加入失败队列
    _failedQueue.addAll(failedTasks);

    notifyListeners();

    // 开始多轮重试
    await _processFailedQueueWithRetry();

    _isRetrying = false;
    notifyListeners();

    // 生成最终报告
    _generateRetryReport();
  }

  /// 🆕 多轮重试失败队列（核心方法）
  Future<void> _processFailedQueueWithRetry() async {
    while (_failedQueue.isNotEmpty &&
        _currentRetryRound < _maxRetryRounds) {

      _currentRetryRound++;
      debugPrint('════════════════════════════════════════');
      debugPrint('重试轮次 $_currentRetryRound/$_maxRetryRounds');
      debugPrint('待重试任务: ${_failedQueue.length} 个');
      debugPrint('════════════════════════════════════════');

      notifyListeners();

      // 等待一段时间再重试（让网络恢复）
      debugPrint('等待 $_retryRoundDelaySeconds 秒后开始重试...');
      await Future.delayed(Duration(seconds: _retryRoundDelaySeconds));

      // 预热连接
      await _warmUpConnection();

      // 取出当前轮次要重试的任务
      final tasksToRetry = List<DownloadTaskRecord>.from(_failedQueue);
      _failedQueue.clear();

      // 重置这些任务的状态为 pending
      for (final task in tasksToRetry) {
        // 重置单文件重试计数
        _taskRetryCount.remove(task.taskId);

        final index = _downloadTasks.indexWhere((t) => t.taskId == task.taskId);
        if (index != -1) {
          _downloadTasks[index] = _downloadTasks[index].copyWith(
            status: DownloadTaskStatus.pending,
            errorMessage: null,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );

          await _dbHelper.updateStatus(
            taskId: task.taskId,
            userId: _currentUserId!,
            groupId: _currentGroupId!,
            status: DownloadTaskStatus.pending,
          );
        }
      }

      notifyListeners();

      // 启动并发下载
      for (int i = 0; i < maxConcurrentDownloads; i++) {
        _processNextDownload();
      }

      // 等待所有任务完成（或失败）
      await _waitForCurrentRoundComplete(tasksToRetry.length);

      // 收集本轮失败的任务
      _collectFailedTasks();

      debugPrint('本轮结束: 失败队列剩余 ${_failedQueue.length} 个');

      // 检查是否有超过最大重试轮次的任务
      _moveExceededTasksToPermanentFailed();
    }

    // 如果还有剩余失败任务，全部移到永久失败
    if (_failedQueue.isNotEmpty) {
      debugPrint('达到最大重试轮次，${_failedQueue.length} 个任务永久失败');
      _permanentlyFailedTasks.addAll(_failedQueue);
      _failedQueue.clear();
    }
  }

  /// 🆕 等待当前轮次的下载完成
  Future<void> _waitForCurrentRoundComplete(int expectedCount) async {
    debugPrint('等待当前轮次下载完成...');

    int maxWaitSeconds = 300; // 最多等待5分钟
    int waited = 0;

    while (waited < maxWaitSeconds) {
      await Future.delayed(const Duration(seconds: 1));
      waited++;

      // 检查是否所有活动任务都完成了
      if (_activeTasks.isEmpty && pendingCount == 0) {
        debugPrint('当前轮次下载完成，用时 $waited 秒');
        break;
      }

      // 每30秒打印一次状态
      if (waited % 30 == 0) {
        debugPrint('等待中... 活动任务: ${_activeTasks.length}, 待处理: $pendingCount');
      }
    }

    if (waited >= maxWaitSeconds) {
      debugPrint('等待超时，强制结束当前轮次');
      // 取消所有活动任务
      for (final cancelToken in _activeTasks.values) {
        cancelToken.cancel('Retry round timeout');
      }
      _activeTasks.clear();
    }
  }

  /// 🆕 收集失败的任务到失败队列
  void _collectFailedTasks() {
    final newlyFailed = _downloadTasks
        .where((t) => t.status == DownloadTaskStatus.failed)
        .where((t) => !_failedQueue.any((f) => f.taskId == t.taskId))
        .where((t) => !_permanentlyFailedTasks.any((p) => p.taskId == t.taskId))
        .toList();

    if (newlyFailed.isNotEmpty) {
      debugPrint('收集到 ${newlyFailed.length} 个新失败任务');
      _failedQueue.addAll(newlyFailed);
    }
  }

  /// 🆕 将超过重试次数的任务移到永久失败列表
  void _moveExceededTasksToPermanentFailed() {
    // 目前使用轮次来判断，每个任务最多重试 _maxRetryRounds 轮
    // 如果需要更细粒度的控制，可以为每个任务维护重试轮次计数
  }

  /// 🆕 生成重试报告
  void _generateRetryReport() {
    final successCount = _downloadTasks
        .where((t) => t.status == DownloadTaskStatus.completed)
        .length;
    final failedCount = _permanentlyFailedTasks.length +
        _downloadTasks.where((t) => t.status == DownloadTaskStatus.failed).length;

    debugPrint('═══════════════════════════════════════════');
    debugPrint('重试完成报告');
    debugPrint('───────────────────────────────────────────');
    debugPrint('总重试轮次: $_currentRetryRound');
    debugPrint('成功下载: $successCount 个');
    debugPrint('永久失败: ${_permanentlyFailedTasks.length} 个');
    debugPrint('仍然失败: ${failedCount - _permanentlyFailedTasks.length} 个');
    debugPrint('═══════════════════════════════════════════');

    if (_permanentlyFailedTasks.isNotEmpty) {
      debugPrint('永久失败的文件:');
      for (final task in _permanentlyFailedTasks) {
        debugPrint('  - ${task.fileName}: ${task.errorMessage ?? "未知错误"}');
      }
    }
  }

  /// 🆕 添加任务到失败队列（供 startDownload 调用）
  void _addToFailedQueue(DownloadTaskRecord task) {
    // 避免重复添加
    if (!_failedQueue.any((t) => t.taskId == task.taskId)) {
      _failedQueue.add(task);
      debugPrint('任务加入失败队列: ${task.fileName}');
    }
  }

  /// 🆕 清空失败队列和永久失败列表
  void clearRetryState() {
    _failedQueue.clear();
    _permanentlyFailedTasks.clear();
    _currentRetryRound = 0;
    _isRetrying = false;
    notifyListeners();
  }

  /// 🆕 获取重试状态消息
  String get retryStatusMessage {
    if (!_isRetrying) return '';
    return '重试第 $_currentRetryRound/$_maxRetryRounds 轮，剩余 ${_failedQueue.length} 个任务...';
  }

  /// 🆕 生成唯一文件路径，避免覆盖已存在的文件
  /// 例如: /path/to/file.jpg -> /path/to/file(1).jpg -> /path/to/file(2).jpg
  String _generateUniqueFilePath(String originalPath) {
    final file = File(originalPath);
    if (!file.existsSync()) {
      return originalPath;
    }

    final directory = file.parent.path;
    final fileName = p.basenameWithoutExtension(originalPath);
    final extension = p.extension(originalPath);

    int counter = 1;
    String newPath;
    do {
      newPath = p.join(directory, '$fileName($counter)$extension');
      counter++;
    } while (File(newPath).existsSync());

    return newPath;
  }

  @override
  void dispose() {
    // 取消所有活动下载
    for (final cancelToken in _activeTasks.values) {
      cancelToken.cancel();
    }
    _activeTasks.clear();
    _taskRetryCount.clear();
    _failedQueue.clear();
    _permanentlyFailedTasks.clear();
    _dio.close();
    super.dispose();
  }
}