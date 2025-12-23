import 'dart:async';
import 'dart:convert';
import 'dart:developer' as LogUtil;
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:semaphore_plus/semaphore_plus.dart';

import '../../minio/mc_output_parser.dart';
import '../../minio/mc_service.dart';
import '../../minio/minio_service.dart';
import '../../network/constant_sign.dart';
import '../../network/network.dart';
import '../../services/thumbnail_helper.dart';
import '../../services/transfer_speed_service.dart';
import '../../user/my_instance.dart';
import '../database/database_helper.dart';
import '../database/upload_task_db_helper.dart';
import '../models/file_detail_model.dart';
import '../models/file_upload_model.dart';
import '../models/local_file_item.dart';
import '../provider/album_provider.dart';
import 'package:media_kit/media_kit.dart';

import '../upload/config/local_upload_config.dart';
import '../upload/models/failed_file_record.dart';
import '../upload/models/local_file_info.dart';
import '../upload/models/local_upload_progress.dart';
import '../upload/upload_progress_tracker.dart';

// 1. 新增：进度追踪器类（添加到文件顶部的类定义区域）
// ============================================================


/// 本地文件夹上传管理器（增强版 - 带失败队列重试和连接预热）
class LocalFolderUploadManager extends ChangeNotifier {
  DatabaseHelper dbHelper = DatabaseHelper.instance;
  UploadFileTaskManager taskManager = UploadFileTaskManager.instance;
  AlbumProvider provider = AlbumProvider();
  final minioService = MinioService.instance;

  // ✅ 新增：字节进度追踪
  int _globalTotalBytes = 0;        // 所有待上传文件的总字节数
  int _completedBytes = 0;          // 已完成文件的累计字节数
  int _currentFileTransferred = 0;  // 当前文件已传输字节
  int _currentFileTotal = 0;        // 当前文件总字节
  int _currentSpeed = 0;            // 当前传输速度
  Function(LocalUploadProgress)? _activeProgressCallback;  // 当前进度回调引用

  // 🆕 用于预热连接的 Dio 实例
  final Dio _dio = Network.instance.getDio();

  LocalUploadProgress? _currentProgress;
  bool _isUploading = false;
  bool _isCancelled = false;

  /// ✅ 新增：当前数据库任务ID（用于关联 McService 任务）
  int? _currentDbTaskId;
  /// ✅ 新增：当前正在执行的 McService 任务ID
  String? _currentMcTaskId;
  /// ✅ 新增：获取数据库任务ID
  int? get currentDbTaskId => _currentDbTaskId;

  // 失败文件队列
  final List<FailedFileRecord> _failedQueue = [];

  // 永久失败文件（超过重试次数）
  final List<FailedFileRecord> _permanentlyFailedFiles = [];

  // ✅ 累计已上传字节数（用于速度计算）
  // int _totalUploadedBytes = 0;
  // ✅ 替换为：
  final UploadProgressTracker _progressTracker = UploadProgressTracker();

  // ✅ 新增：记录本次上传成功的 MD5 列表
  final List<String> _uploadedMd5List = [];

  /// 获取上传成功的 MD5 列表
  List<String> get uploadedMd5List => List.unmodifiable(_uploadedMd5List);

  // 🆕 连接预热状态
  bool _isConnectionWarmedUp = false;
  DateTime? _lastWarmUpTime;
  static const Duration _warmUpValidDuration = Duration(minutes: 5);

  LocalFolderUploadManager();

  LocalUploadProgress? get currentProgress => _currentProgress;

  bool get isUploading => _isUploading;

  List<FailedFileRecord> get failedQueue => List.unmodifiable(_failedQueue);

  List<FailedFileRecord> get permanentlyFailedFiles =>
      List.unmodifiable(_permanentlyFailedFiles);

  /// ✅ 新增：设置数据库任务ID
  void setDbTaskId(int taskId) {
    _currentDbTaskId = taskId;
  }

  /// ✅ 重置字节进度追踪
  void _resetBytesTracking(int totalBytes) {
    _globalTotalBytes = totalBytes;
    _completedBytes = 0;
    _currentFileTransferred = 0;
    _currentFileTotal = 0;
    _currentSpeed = 0;
  }

  /// ✅ 从 mc 输出更新字节进度并通知 UI
  void _updateBytesProgressFromMcOutput(String output) {
    final info = McOutputParser.parse(output);
    if (info.total > 0) {
      _currentFileTransferred = info.transferred;
      _currentFileTotal = info.total;
      _currentSpeed = info.speed;

      // 实时更新进度回调
      if (_currentProgress != null && _activeProgressCallback != null) {
        final updated = _currentProgress!.copyWithBytesProgress(
          transferredBytes: info.transferred,
          totalBytes: info.total,
          speed: info.speed,
          globalTransferredBytes: _completedBytes + info.transferred,
          globalTotalBytes: _globalTotalBytes,
        );
        _activeProgressCallback!(updated);
      }
    }
  }

  /// ✅ 标记文件上传完成
  void _onFileUploadComplete(int fileSize) {
    _completedBytes += fileSize;
    _currentFileTransferred = 0;
    _currentFileTotal = 0;
  }

  /// ✅ 修改：取消上传（同时终止 McService 进程）
  Future<void> cancelUpload() async {
    _isCancelled = true;
    LogUtil.log('[UploadManager] Upload cancelled by user');

    // ✅ 终止当前正在执行的 McService 任务
    if (_currentMcTaskId != null) {
      final cancelled = await McService.instance.cancelTask(_currentMcTaskId!);
      LogUtil.log('[UploadManager] McService task cancelled: $cancelled');
    }

    // ✅ 如果有数据库任务ID，也可以用它来取消（备用方案）
    if (_currentDbTaskId != null) {
      final taskIdStr = _currentDbTaskId.toString();
      // 尝试用数据库任务ID取消（如果之前用这个ID注册的话）
      await McService.instance.cancelTask(taskIdStr);
    }
  }

  /// 🆕 预热 MinIO 连接（唤醒 P2P 隧道）
  Future<bool> _warmUpMinioConnection() async {
    // 检查预热是否仍有效
    if (_isConnectionWarmedUp && _lastWarmUpTime != null) {
      final elapsed = DateTime.now().difference(_lastWarmUpTime!);
      if (elapsed < _warmUpValidDuration) {
        LogUtil.log('[UploadManager] 连接预热仍有效，跳过预热');
        return true;
      }
    }

    final baseUrl = AppConfig.minio();
    LogUtil.log(
        '[UploadManager] 开始预热 MinIO 连接: $baseUrl, usedIP: ${AppConfig
            .usedIP},currentIP: ${AppConfig.currentIP},');

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
      LogUtil.log('[UploadManager] MinIO 连接预热成功');
      return true;
    } catch (e) {
      LogUtil.log('[UploadManager] MinIO 连接预热失败（隧道可能正在建立）: $e');

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
        LogUtil.log('[UploadManager] MinIO 连接预热第二次尝试成功');
        return true;
      } catch (e2) {
        LogUtil.log('[UploadManager] MinIO 连接预热第二次尝试也失败: $e2');
        // 即使预热失败，也继续上传，让上传逻辑处理重试
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
        errorStr.contains('connection refused') ||
        errorStr.contains('network is unreachable');
  }

  /// 更新上传进度
  void _updateProgress({
    required int total,
    required int uploaded,
    required int failed,
    int retryRound = 0,
    String? fileName,
    String? statusMessage,
  }) {
    _currentProgress = LocalUploadProgress(
      totalFiles: total,
      uploadedFiles: uploaded,
      failedFiles: failed,
      retryRound: retryRound,
      currentFileName: fileName,
      statusMessage: statusMessage,
      // ✅ 包含字节进度
      transferredBytes: _currentFileTransferred,
      totalBytes: _currentFileTotal,
      speed: _currentSpeed,
      globalTransferredBytes: _completedBytes + _currentFileTransferred,
      globalTotalBytes: _globalTotalBytes,
    );
  }

  /// 从本地文件列表上传（主入口）
  Future<void> uploadLocalFiles(List<String> localFilePaths, {
    Function(LocalUploadProgress)? onProgress,
    Function(bool success, String message, List<String> uploadedMd5s)? onComplete,
  }) async {
    if (_isUploading) {
      LogUtil.log("[UploadManager] Upload already in progress");
      onComplete?.call(false, "已有上传任务在进行中",[]);
      return;
    }

    if (localFilePaths.isEmpty) {
      LogUtil.log("[UploadManager] No files to upload");
      onComplete?.call(false, "没有选择文件",[]);
      return;
    }

    _isUploading = true;
    _isCancelled = false;
    _failedQueue.clear();
    _permanentlyFailedFiles.clear();
    _progressTracker.reset();// ✅ 重置累计字节数

    _uploadedMd5List.clear();  // ✅ 清空上次的记录

    int totalFiles = localFilePaths.length;
    int uploadedFiles = 0;
    int failedFiles = 0;

    TransferSpeedService.instance.startMonitoring();

    try {
      final userId = MyInstance().user?.user?.id ?? 0;
      final groupId = MyInstance().group?.groupId ?? 0;
      final deviceCode = MyInstance().deviceCode;

      if (userId == 0) throw Exception("用户未登录");
      if (deviceCode.isEmpty) throw Exception("设备标识无效");

      LogUtil.log("[UploadManager] Starting upload, total: $totalFiles");
      LogUtil.log(
          "[UploadManager] User: $userId, Device: $deviceCode, Group: $groupId");

      // 1. 解析本地文件信息
      final localFileInfos = <LocalFileInfo>[];
      for (var filePath in localFilePaths) {
        if (_isCancelled) break;
        try {
          final fileInfo = await _parseLocalFile(filePath);
          if (fileInfo != null) {
            localFileInfos.add(fileInfo);
          } else {
            failedFiles++;
          }
        } catch (e) {
          LogUtil.log(
              "[UploadManager] Failed to parse file: $filePath, error: $e");
          failedFiles++;
        }
      }

      if (_isCancelled) {
        onComplete?.call(false, "",[]);//上传已取消
        return;
      }

      if (localFileInfos.isEmpty) {
        throw Exception("没有有效的文件");
      }

      _updateProgress(
          total: totalFiles, uploaded: uploadedFiles, failed: failedFiles);
      onProgress?.call(_currentProgress!);

      // 2. 计算 MD5 并检查数据库去重
      final filesWithMd5 = <MapEntry<LocalFileInfo, String>>[];
      for (var fileInfo in localFileInfos) {
        if (_isCancelled) break;
        try {
          final file = File(fileInfo.filePath);
          final md5Hash = await _getFileMd5(file);
          filesWithMd5.add(MapEntry(fileInfo, md5Hash));
        } catch (e) {
          LogUtil.log(
              "[UploadManager] Failed to calculate MD5: ${fileInfo.filePath}");
          failedFiles++;
        }
      }

      // 3. 批量查询数据库，过滤已上传的文件
      final md5List = filesWithMd5.map((e) => e.value).toList();
      final existingFilesMap = await dbHelper.queryFilesByMd5HashList(
        "$userId",
        deviceCode,
        md5List,
      );

      final newFiles = <MapEntry<LocalFileInfo, String>>[];
      for (var entry in filesWithMd5) {
        final existingFile = existingFilesMap[entry.value];
        if (existingFile != null && existingFile.status == 2) {
          LogUtil.log(
              "[UploadManager] File already uploaded: ${entry.key.fileName}");
          uploadedFiles++;
        } else {
          newFiles.add(entry);
        }
      }

      if (newFiles.isEmpty) {
        LogUtil.log("[UploadManager] All files already uploaded");
        onComplete?.call(true, "所有文件已存在，无需重复上传",[]);
        return;
      }

      // 4. MD5 去重（批次内）
      final uniqueFiles = _deduplicateByMd5(newFiles);
      final duplicateCount = newFiles.length - uniqueFiles.length;
      if (duplicateCount > 0) {
        uploadedFiles += duplicateCount;
        LogUtil.log("[UploadManager] Skipped $duplicateCount duplicate files");
      }

      if (uniqueFiles.isEmpty) {
        onComplete?.call(true, "所有文件已存在或重复，无需上传",[]);
        return;
      }

      // ✅ 计算总字节数并初始化追踪
      final totalUploadBytes = uniqueFiles.fold<int>(
        0, (sum, entry) => sum + entry.key.fileSize,
      );
      _resetBytesTracking(totalUploadBytes);
      _activeProgressCallback = onProgress;

      _updateProgress(
          total: totalFiles, uploaded: uploadedFiles, failed: failedFiles);
      onProgress?.call(_currentProgress!);

      // 🆕 5. 预热 MinIO 连接
      LogUtil.log('[UploadManager] 上传前预热 MinIO 连接...');
      await _warmUpMinioConnection();

      // 6. 分批处理
      final chunks = _splitIntoChunks(
          uniqueFiles, LocalUploadConfig.imageChunkSize);

      for (var chunk in chunks) {
        if (_isCancelled) break;

        final chunkSize = chunk.fold<double>(
            0, (sum, e) => sum + e.key.fileSize) / (1024 * 1024 * 1024);
        if (!_hasEnoughStorage(chunkSize)) {
          throw Exception("云端存储空间不足");
        }

        final result = await _processChunk(
          chunk,
          userId,
          groupId,
          deviceCode,
          totalFiles,
          uploadedFiles,
          failedFiles,
          onProgress,
        );

        uploadedFiles = result['uploaded'] as int;
        failedFiles = result['failed'] as int;
      }

      // 6. ✅ 处理失败队列重试
      if (_failedQueue.isNotEmpty && !_isCancelled) {
        LogUtil.log("[UploadManager] Starting retry rounds for ${_failedQueue
            .length} failed files");

        final retryResult = await _processFailedQueueWithRetry(
          userId,
          groupId,
          deviceCode,
          totalFiles,
          uploadedFiles,
          failedFiles,
          onProgress,
        );

        uploadedFiles = retryResult['uploaded'] as int;
        failedFiles = retryResult['failed'] as int;
      }
      // ✅ 修复：在生成完成消息之前检查取消状态
      if (_isCancelled) {
        LogUtil.log("[UploadManager] Upload was cancelled, skipping completion message");
        onComplete?.call(false, "", []);
        return;  // 直接返回，不执行后面的完成消息逻辑
      }

      // 7. 生成最终结果
      final finalMessage = _generateCompletionMessage(
          uploadedFiles, failedFiles, totalFiles);
      LogUtil.log("[UploadManager] $finalMessage");

      onComplete?.call(
        _permanentlyFailedFiles.isEmpty,
        finalMessage,
        List.from(_uploadedMd5List),  // ✅ 传递上传成功的 MD5 列表
      );
    } catch (e, stackTrace) {
      LogUtil.log("[UploadManager] Error: $e\n$stackTrace");
      // ✅ 修改：异常时也检查取消状态
      if (_isCancelled) {
        onComplete?.call(false, "", []);
      } else {
        onComplete?.call(false, "上传失败：$e", []);
      }
    } finally {
      // 在 finally 块中添加:

      // ✅ 清理任务ID
      _currentMcTaskId = null;
      _currentDbTaskId = null;

      _activeProgressCallback = null;
      _resetBytesTracking(0);
      _isUploading = false;

      // ✅ 修改：取消状态下不更新进度消息
      if (!_isCancelled) {
        _updateProgress(
          total: totalFiles,
          uploaded: uploadedFiles,
          failed: failedFiles,
          statusMessage: '上传完成',
        );
        onProgress?.call(_currentProgress!);
      }

      TransferSpeedService.instance.onUploadComplete();
      notifyListeners();
    }
  }

  /// ✅ 处理失败队列重试（核心新增方法）
  Future<Map<String, int>> _processFailedQueueWithRetry(int userId,
      int groupId,
      String deviceCode,
      int totalFiles,
      int uploadedFiles,
      int failedFiles,
      Function(LocalUploadProgress)? onProgress,) async {
    int currentRound = 0;

    while (_failedQueue.isNotEmpty &&
        currentRound < LocalUploadConfig.maxRetryRounds &&
        !_isCancelled) {
      currentRound++;
      LogUtil.log('[UploadManager] ════════════════════════════════════════');
      LogUtil.log('[UploadManager] Retry Round $currentRound/${LocalUploadConfig
          .maxRetryRounds}');
      LogUtil.log('[UploadManager] Files to retry: ${_failedQueue.length}');
      LogUtil.log('[UploadManager] ════════════════════════════════════════');

      _updateProgress(
        total: totalFiles,
        uploaded: uploadedFiles,
        failed: failedFiles,
        retryRound: currentRound,
        statusMessage: '重试第 $currentRound/${LocalUploadConfig
            .maxRetryRounds} 轮...',
      );
      onProgress?.call(_currentProgress!);

      // 等待一段时间再重试（让网络恢复）
      await Future.delayed(
          Duration(seconds: LocalUploadConfig.retryRoundDelaySeconds));

      // 🆕 预热连接
      LogUtil.log('[UploadManager] 重试轮次 $currentRound 前预热连接...');
      _isConnectionWarmedUp = false; // 强制重新预热
      await _warmUpMinioConnection();

      // 取出当前轮次要重试的文件
      final filesToRetry = List<FailedFileRecord>.from(_failedQueue);
      _failedQueue.clear();

      // 转换为上传格式
      final retryEntries = filesToRetry.map((r) => r.toEntry()).toList();

      // 分批重试
      final chunks = _splitIntoChunks(
          retryEntries, LocalUploadConfig.imageChunkSize);

      for (var chunk in chunks) {
        if (_isCancelled) break;

        final result = await _processChunk(
          chunk,
          userId,
          groupId,
          deviceCode,
          totalFiles,
          uploadedFiles,
          failedFiles,
          onProgress,
          isRetry: true,
          retryRound: currentRound,
        );

        uploadedFiles = result['uploaded'] as int;
        failedFiles = result['failed'] as int;
      }

      // 检查是否还有失败的文件
      if (_failedQueue.isEmpty) {
        LogUtil.log('[UploadManager] All retry files uploaded successfully!');
        break;
      }

      // 检查失败文件的重试次数，超过限制的移到永久失败列表
      _moveExceededFilesToPermanentFailed();
    }

    // 如果还有剩余失败文件，全部移到永久失败列表
    if (_failedQueue.isNotEmpty) {
      LogUtil.log('[UploadManager] Moving ${_failedQueue
          .length} files to permanently failed');
      _permanentlyFailedFiles.addAll(_failedQueue);
      _failedQueue.clear();
    }

    return {'uploaded': uploadedFiles, 'failed': failedFiles};
  }

  /// 将超过重试次数的文件移到永久失败列表
  void _moveExceededFilesToPermanentFailed() {
    final toRemove = <FailedFileRecord>[];

    for (var record in _failedQueue) {
      if (record.retryCount >= LocalUploadConfig.maxRetryRounds) {
        _permanentlyFailedFiles.add(record);
        toRemove.add(record);
        LogUtil.log(
            '[UploadManager] File exceeded max retries: ${record.fileInfo
                .fileName}');
      }
    }

    _failedQueue.removeWhere((r) => toRemove.contains(r));
  }

  /// 添加文件到失败队列
  void _addToFailedQueue(LocalFileInfo fileInfo, String md5Hash,
      String? errorMessage, {bool isRetry = false}) {
    // 检查是否已在队列中
    final existingIndex = _failedQueue.indexWhere((r) => r.md5Hash == md5Hash);

    if (existingIndex >= 0) {
      // 已存在，增加重试计数
      _failedQueue[existingIndex].retryCount++;
    } else {
      // 新增记录
      _failedQueue.add(FailedFileRecord(
        fileInfo: fileInfo,
        md5Hash: md5Hash,
        errorMessage: errorMessage,
        retryCount: isRetry ? 1 : 0,
      ));
    }

    LogUtil.log('[UploadManager] Added to failed queue: ${fileInfo
        .fileName} (retries: ${_failedQueue.last.retryCount})');
  }

  /// MD5 去重
  List<MapEntry<LocalFileInfo, String>> _deduplicateByMd5(
      List<MapEntry<LocalFileInfo, String>> files,) {
    final uniqueFiles = <MapEntry<LocalFileInfo, String>>[];
    final seenMd5 = <String>{};

    for (var entry in files) {
      if (!seenMd5.contains(entry.value)) {
        seenMd5.add(entry.value);
        uniqueFiles.add(entry);
      }
    }

    return uniqueFiles;
  }

  /// 生成完成消息
  String _generateCompletionMessage(int uploaded, int failed, int total) {
    final buffer = StringBuffer();

    if (_permanentlyFailedFiles.isEmpty) {
      buffer.write('上传完成！共 $uploaded 个文件');
    } else {
      buffer.write('上传完成，成功 $uploaded 个');
      if (_permanentlyFailedFiles.isNotEmpty) {
        buffer.write('，失败 ${_permanentlyFailedFiles.length} 个'); //（已达最大重试次数）
      }
    }

    return buffer.toString();
  }

  /// 处理单个批次
  Future<Map<String, int>> _processChunk(
      List<MapEntry<LocalFileInfo, String>> chunk,
      int userId,
      int groupId,
      String deviceCode,
      int totalFiles,
      int uploadedFiles,
      int failedFiles,
      Function(LocalUploadProgress)? onProgress, {
        bool isRetry = false,
        int retryRound = 0,
      }) async {
    final uploadList = <FileUploadModel>[];
    final fileItemsToInsert = <FileItem>[];

    for (var entry in chunk) {
      try {
        final fileInfo = entry.key;
        final md5Hash = entry.value;

        final fileItem = fileInfo.toFileItem(
            userId.toString(), deviceCode, md5Hash);
        await dbHelper.insertFile(fileItem);
        fileItemsToInsert.add(fileItem);

        uploadList.add(FileUploadModel(
          fileCode: md5Hash,
          filePath: fileInfo.filePath,
          fileName: fileInfo.fileName,
          fileType: fileInfo.fileType == LocalFileType.image ? "P" : "V",
          storageSpace: fileInfo.fileSize,
        ));
      } catch (e) {
        LogUtil.log("[UploadManager] Error preparing file: $e");
        failedFiles++;
      }
    }

    if (uploadList.isEmpty) {
      return {'uploaded': uploadedFiles, 'failed': failedFiles};
    }

    try {
      final response = await provider.createSyncTask(uploadList);
      final taskId = response.model?.taskId ?? 0;
      // ✅ 保存数据库任务ID
      _currentDbTaskId = taskId;

      if (!response.isSuccess) {
        LogUtil.log(
            "[UploadManager] Failed to create sync task: ${response.message}");
        // 将所有文件加入失败队列
        for (var entry in chunk) {
          _addToFailedQueue(
              entry.key, entry.value, response.message, isRetry: isRetry);
        }
        return {
          'uploaded': uploadedFiles,
          'failed': failedFiles + uploadList.length
        };
      }

      final uploadPath = _removeFirstAndLastSlash(
          response.model?.uploadPath ?? "");

      final chunkFileCount = chunk.length;
      final chunkTotalSize = chunk.fold<int>(
          0, (sum, e) => sum + e.key.fileSize);

      await taskManager.insertTask(
        taskId: taskId,
        userId: userId,
        groupId: groupId,
        status: UploadTaskStatus.uploading,
        fileCount: chunkFileCount,
        totalSize: chunkTotalSize,
      );

      // 处理已存在的文件
      final failedFileList = response.model?.failedFileList ?? [];
      for (var failed in failedFileList) {
        if (failed.fileCode != null && failed.fileCode!.isNotEmpty) {
          if ((failed.failedReason ?? "").contains("exist")) {
            await dbHelper.updateStatusByMd5Hash(failed.fileCode!, 2);
            uploadedFiles++;
          }
        }
      }

      // 过滤出需要上传的文件
      final newFiles = chunk.where((entry) {
        final md5 = entry.value;
        return !failedFileList.any((failed) => failed.fileCode == md5);
      }).toList();

      if (newFiles.isEmpty) {
        await provider.revokeSyncTask(taskId);
        await taskManager.deleteTask(taskId);
        return {'uploaded': uploadedFiles, 'failed': failedFiles};
      }

      // 执行上传
      final uploadResult = await _uploadFiles(
        newFiles,
        uploadPath,
        taskId,
        totalFiles,
        uploadedFiles,
        failedFiles,
        onProgress,
        isRetry: isRetry,
        retryRound: retryRound,
      );

      return uploadResult;
    } catch (e, stackTrace) {
      LogUtil.log("[UploadManager] Error processing chunk: $e\n$stackTrace");
      // 将所有文件加入失败队列
      for (var entry in chunk) {
        _addToFailedQueue(
            entry.key, entry.value, e.toString(), isRetry: isRetry);
      }
      return {
        'uploaded': uploadedFiles,
        'failed': failedFiles + uploadList.length
      };
    }
  }

  /// 上传文件列表
  Future<Map<String, int>> _uploadFiles(
      List<MapEntry<LocalFileInfo, String>> files,
      String uploadPath,
      int taskId,
      int totalFiles,
      int uploadedFiles,
      int failedFiles,
      Function(LocalUploadProgress)? onProgress, {
        bool isRetry = false,
        int retryRound = 0,
      }) async {
    final uploadedEntries = <MapEntry<LocalFileInfo, String>>[];
    final sm = LocalSemaphore(LocalUploadConfig.maxConcurrentUploads);
    int pendingTasks = files.length;
    final completer = Completer<void>();

    LogUtil.log("[UploadManager] Files to upload: ${files.length}");

    for (var entry in files) {
      if (_isCancelled) break;

      await sm.acquire();

      // ✅ 获取信号量后再次检查
      if (_isCancelled) {
        sm.release();
        pendingTasks--;
        if (pendingTasks == 0 && !completer.isCompleted) {
          completer.complete();
        }
        continue;
      }

      final fileInfo = entry.key;
      final md5Hash = entry.value;

      await dbHelper.updateStatusByMd5Hash(md5Hash, 1);

      _updateProgress(
        total: totalFiles,
        uploaded: uploadedFiles,
        failed: failedFiles,
        retryRound: retryRound,
        fileName: fileInfo.fileName,
      );
      onProgress?.call(_currentProgress!);

      // 异步上传
      _uploadSingleFile(fileInfo, md5Hash, uploadPath,taskId)
          .then((success) async {
        try {
          // ✅ 关键：在回调中也检查取消状态
          if (_isCancelled) {
            LogUtil.log("[UploadManager] ⏹️ Cancelled: ${fileInfo.fileName}");
            // 取消的文件：不更新失败状态，不加入失败队列
            return;
          }

          if (success) {
            LogUtil.log("[UploadManager] ✅ Uploaded: ${fileInfo.fileName}");
            uploadedEntries.add(entry);
            // ✅ 修改：不在这里更新状态，等上报成功后再更新
            uploadedFiles++;
          } else {
            LogUtil.log("[UploadManager] ❌ Failed: ${fileInfo.fileName}");
            await dbHelper.updateStatusByMd5Hash(md5Hash, 3);
            failedFiles++;
            // ✅ 只有非取消状态才加入失败队列（双重保险）
            if (!_isCancelled) {
              _addToFailedQueue(
                  fileInfo, md5Hash, 'Upload failed', isRetry: isRetry);
            }
          }
          // ✅ 取消时不更新进度
          if (!_isCancelled) {
            _updateProgress(
              total: totalFiles,
              uploaded: uploadedFiles,
              failed: failedFiles,
              retryRound: retryRound,
            );
            onProgress?.call(_currentProgress!);
          }
          onProgress?.call(_currentProgress!);
        } finally {
          sm.release();
          pendingTasks--;
          if (pendingTasks == 0 && !completer.isCompleted) {
            completer.complete();
          }
        }
      });
    }

    if (pendingTasks > 0) {
      await completer.future;
    }

    // ✅ 取消时：清空失败队列，不调用 revokeSyncTask
    if (_isCancelled) {
      LogUtil.log("[UploadManager] Upload cancelled, clearing failed queue");
      _failedQueue.clear();
      // 不调用 revokeSyncTask，让 upload_records_page 统一处理
      return {'uploaded': uploadedFiles, 'failed': 0};
    }

    if (uploadedEntries.isNotEmpty) {
      await _reportUploadedFiles(uploadedEntries, uploadPath, taskId);
    } else {
      LogUtil.log("[UploadManager] No files uploaded successfully, revoking task");
      await provider.revokeSyncTask(taskId);
      await taskManager.deleteTask(taskId);
    }

    return {'uploaded': uploadedFiles, 'failed': failedFiles};
  }

  /// 上传单个文件（带重试）
  Future<bool> _uploadSingleFile(LocalFileInfo fileInfo,
      String md5Hash,
      String uploadPath,
      int taskId) async {
    for (int attempt = 0; attempt < LocalUploadConfig.maxRetryAttempts; attempt++) {
      // ✅ 每次重试前检查
      if (_isCancelled) {
        LogUtil.log("[UploadManager] Upload cancelled before attempt $attempt");
        return false;
      }

      try {
        if (attempt > 0) {
          LogUtil.log("[UploadManager] Retry $attempt/${LocalUploadConfig.maxRetryAttempts}: ${fileInfo.fileName}");
          await Future.delayed(Duration(seconds: LocalUploadConfig.retryDelaySeconds));

          // ✅ 延迟后再检查
          if (_isCancelled) return false;

          if (!_isConnectionWarmedUp) {
            LogUtil.log('[UploadManager] 重试前预热连接...');
            await _warmUpMinioConnection();
          }
        }

        final success = await _doUpload(fileInfo, md5Hash, uploadPath, taskId);
        if (success) return true;

        // ✅ 上传失败后检查是否是取消导致的
        if (_isCancelled) return false;

      } catch (e) {
        LogUtil.log("[UploadManager] Upload error (attempt $attempt): $e");

        if (_isConnectionClosedError(e)) {
          LogUtil.log('[UploadManager] 检测到连接错误，标记需要重新预热');
          _isConnectionWarmedUp = false;
        }

        // ✅ 异常后检查取消状态
        if (_isCancelled) return false;
      }
    }

    return false;
  }

  /// 执行实际上传
  Future<bool> _doUpload(LocalFileInfo fileInfo,
      String md5Hash,
      String uploadPath,
      int taskId) async {
    try {
      final file = File(fileInfo.filePath);
      if (!await file.exists()) {
        LogUtil.log("File not found: ${fileInfo.filePath}");
        return false;
      }

      final fileName = fileInfo.fileName;
      final fileNameWithoutExt = p.basenameWithoutExtension(fileName);
      final imageFileName = "$fileNameWithoutExt.jpg";

      // 解析bucket和路径
      final pathParts = uploadPath.split('/');
      if (pathParts.isEmpty) {
        LogUtil.log("Invalid upload path: $uploadPath");
        return false;
      }

      final bucketName = pathParts.first;
      final uploadPathWithoutBucket = pathParts.skip(1).join('/');

      // ✅ 为每个子文件创建唯一的进度key
      final originalFileKey = "${md5Hash}_original";
      final thumbnailFileKey = "${md5Hash}_thumbnail";
      final mediumFileKey = "${md5Hash}_medium";

      // 1. 上传原始文件
      LogUtil.log("Uploading original file: ${fileInfo.filePath}");

      // ✅ 使用数据库 taskId 作为 McService 的任务ID
      final mcTaskId = '${taskId}_original_$md5Hash';
      _currentMcTaskId = mcTaskId;  // ✅ 保存当前任务ID

      // ✅ 使用带进度回调的上传方法
      var result = await McService.instance.uploadFileDefault(
        file.path,
        bucketName,
        objectName:"$uploadPathWithoutBucket/$md5Hash/$fileName",
        taskId: mcTaskId,
        onOutput: (output) {
          // TransferSpeedService.instance.updateUploadSpeedForTaskFromMcOutput(taskId.toString(),output);
          // ✅ 更新字节进度
          _updateBytesProgressFromMcOutput(output);
        },
      );
      
      if (!result.success||_isCancelled) {
        LogUtil.log("Failed to upload original file");
        return false;
      }

      // ✅ 标记原始文件上传完成，更新累计字节
      _onFileUploadComplete(fileInfo.fileSize);

      // 2. 生成并上传缩略图
      final thumbnailFile = await _createThumbnail(
          file, imageFileName, fileInfo.fileType);
      if (thumbnailFile == null) {
        LogUtil.log("Failed to create thumbnail");
        return false;
      }


      // ✅ 使用带进度回调的上传方法
      result = await McService.instance.uploadFileDefault(
        thumbnailFile.path,
        bucketName,
        objectName:"$uploadPathWithoutBucket/$md5Hash/thumbnail_$imageFileName",
        taskId: mcTaskId,  // ✅ 传入任务ID
        onOutput: (output) {
          // TransferSpeedService.instance.updateUploadSpeedForTaskFromMcOutput(taskId.toString(),output);
        },
      );

      await _cleanupFile(thumbnailFile);

      if (!result.success|| _isCancelled) {
        LogUtil.log("Failed to upload thumbnail");
      //  _progressTracker.removeFileProgress(thumbnailFileKey);
        return false;
      }
      // ✅ 标记缩略图上传完成
      // _progressTracker.confirmFileComplete(thumbnailFileKey, thumbnailSize);

      // 3. 生成并上传中等尺寸
      final mediumFile = await _createMedium(
          file, imageFileName, fileInfo.fileType);
      if (mediumFile == null) {
        LogUtil.log("Failed to create medium file");
        return false;
      }

      // ✅ 使用带进度回调的上传方法
      result = await McService.instance.uploadFileDefault(
        mediumFile.path,
        bucketName,
        objectName:"$uploadPathWithoutBucket/$md5Hash/show_$imageFileName",
        taskId: mcTaskId,  // ✅ 传入任务ID
        onOutput: (output) {
          // TransferSpeedService.instance.updateUploadSpeedForTaskFromMcOutput(taskId.toString(),output);
        },
      );

      await _cleanupFile(mediumFile);

      if (!result.success|| _isCancelled) {
        LogUtil.log("Failed to upload medium file");
        // _progressTracker.removeFileProgress(mediumFileKey);
        return false;
      }

      // ✅ 标记中等尺寸上传完成
      // _progressTracker.confirmFileComplete(mediumFileKey, mediumSize);

      LogUtil.log("Successfully uploaded: ${fileInfo.fileName}");
      return true;
    } catch (e, stackTrace) {
      LogUtil.log("Error uploading file: $e\n$stackTrace");
      return false;
    }
  }

  // ==================== 辅助方法 ====================

  Future<LocalFileInfo?> _parseLocalFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final fileName = p.basename(filePath);
      final fileType = _detectFileType(filePath);
      if (fileType == LocalFileType.unknown) return null;

      final stat = await file.stat();
      return LocalFileInfo(
        filePath: filePath,
        fileName: fileName,
        fileType: fileType,
        fileSize: stat.size,
        createTime: stat.modified,
      );
    } catch (e) {
      return null;
    }
  }

  LocalFileType _detectFileType(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    const imageExts = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
      '.heic'
    ];
    const videoExts = ['.mp4', '.mov', '.avi', '.mkv', '.3gp', '.3gp2'];

    if (imageExts.contains(ext)) return LocalFileType.image;
    if (videoExts.contains(ext)) return LocalFileType.video;
    return LocalFileType.unknown;
  }

  List<List<MapEntry<LocalFileInfo, String>>> _splitIntoChunks(
      List<MapEntry<LocalFileInfo, String>> files,
      int chunkSize,) {
    final chunks = <List<MapEntry<LocalFileInfo, String>>>[];
    final imageList = files
        .where((e) => e.key.fileType == LocalFileType.image)
        .toList();
    final videoList = files
        .where((e) => e.key.fileType == LocalFileType.video)
        .toList();

    for (var i = 0; i < imageList.length; i += chunkSize) {
      chunks.add(
          imageList.sublist(i, (i + chunkSize).clamp(0, imageList.length)));
    }

    for (var video in videoList) {
      chunks.add([video]);
    }

    return chunks;
  }

  Future<String> _getFileMd5(File file) async {
    final bytes = await _readFileMax1M(file);
    return md5.convert(bytes).toString();
  }

  Future<Uint8List> _readFileMax1M(File file) async {
    const maxSize = LocalUploadConfig.md5ReadSizeBytes;
    final raf = await file.open();
    final fileSize = await file.length();
    final readSize = fileSize > maxSize ? maxSize : fileSize;
    final bytes = await raf.read(readSize);
    await raf.close();
    return Uint8List.fromList(bytes);
  }

  String _removeFirstAndLastSlash(String path) {
    var result = path;
    if (result.startsWith('/')) result = result.substring(1);
    if (result.endsWith('/')) result = result.substring(0, result.length - 1);
    return result;
  }

  bool _hasEnoughStorage(double additionalSizeGB) {
    final used = (MyInstance().p6deviceInfoModel?.ttlUsed ?? 0) +
        additionalSizeGB;
    final max = (MyInstance().p6deviceInfoModel?.ttlAll ?? 0) -
        LocalUploadConfig.reservedStorageGB;
    debugPrint('P6 device storage: $used/$max GB');
    return used < max;
  }

  Future<void> _cleanupFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// 创建缩略图
  Future<File?> _createThumbnail(File file, String outputFileName,
      LocalFileType fileType) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = "${tempDir.path}/thumbnail_$outputFileName";

      if (fileType == LocalFileType.video) {
        // 使用 ThumbnailHelper 生成视频缩略图
        final thumbnailPath = await ThumbnailHelper.generateThumbnail(
            file.path);

        if (thumbnailPath == null) {
          LogUtil.log("Failed to generate video thumbnail");
          return null;
        }

        // 将生成的缩略图复制到目标路径
        final thumbnailFile = File(thumbnailPath);
        if (!await thumbnailFile.exists()) {
          LogUtil.log("Generated thumbnail file not found: $thumbnailPath");
          return null;
        }

        final outputFile = File(filePath);
        await thumbnailFile.copy(outputFile.path);

        // 清理原始缩略图文件（ThumbnailHelper 生成的临时文件）
        try {
          await thumbnailFile.delete();
        } catch (e) {
          LogUtil.log("Failed to delete temp thumbnail: $e");
        }

        return outputFile;
      } else {
        // 图片缩略图
        final bytes = await file.readAsBytes();
        final original = img.decodeImage(bytes);
        if (original == null) return null;

        final thumbnail = img.copyResize(
          original,
          width: LocalUploadConfig.thumbnailWidth,
          height: LocalUploadConfig.thumbnailHeight,
        );

        final compressedBytes = img.encodeJpg(
          thumbnail,
          quality: LocalUploadConfig.thumbnailQuality,
        );

        final outputFile = File(filePath);
        await outputFile.writeAsBytes(compressedBytes);
        return outputFile;
      }
    } catch (e) {
      LogUtil.log("Error creating thumbnail: $e");
      return null;
    }
  }

  /// 创建中等尺寸
  Future<File?> _createMedium(File file, String outputFileName,
      LocalFileType fileType) async {
    try {
      if (fileType == LocalFileType.video) {
        // 视频不需要中等尺寸，复用缩略图
        return await _createThumbnail(file, outputFileName, fileType);
      }

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/show_$outputFileName';

      final bytes = await file.readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) return null;

      final width = original.width;
      final height = original.height;
      final targetWidth = width > height
          ? LocalUploadConfig.mediumWidth
          : LocalUploadConfig.mediumHeight;
      final targetHeight = width > height
          ? LocalUploadConfig.mediumHeight
          : LocalUploadConfig.mediumWidth;

      img.Image resized;
      if (width > targetWidth || height > targetHeight) {
        resized = img.copyResize(
          original,
          width: width > height ? targetWidth : null,
          height: width > height ? null : targetHeight,
        );
      } else {
        resized = original;
      }

      final compressedBytes = img.encodeJpg(
        resized,
        quality: LocalUploadConfig.mediumQuality,
      );

      final outputFile = File(filePath);
      await outputFile.writeAsBytes(compressedBytes);
      return outputFile;
    } catch (e) {
      LogUtil.log("Error creating medium: $e");
      return null;
    }
  }

  /// 获取视频元数据（duration、width、height）
  Future<VideoMetadata> _getVideoMetadata(String videoPath) async {
    try {
      final player = Player();
      final completer = Completer<VideoMetadata>();

      // 监听媒体打开事件
      StreamSubscription? subscription;
      subscription = player.stream.duration.listen((duration) {
        if (duration > Duration.zero && !completer.isCompleted) {
          // 获取视频轨道信息
          final videoTrack = player.state.tracks.video.firstOrNull;
          int width = 0;
          int height = 0;

          if (videoTrack != null) {
            width = videoTrack.w ?? 0;
            height = videoTrack.h ?? 0;
          }

          completer.complete(VideoMetadata(
            duration: duration.inSeconds,
            width: width,
            height: height,
          ));
          subscription?.cancel();
          player.dispose();
        }
      });

      // 设置超时
      Future.delayed(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.complete(VideoMetadata(duration: 0, width: 0, height: 0));
          subscription?.cancel();
          player.dispose();
        }
      });

      await player.open(Media(videoPath), play: false);

      return await completer.future;
    } catch (e) {
      LogUtil.log("Failed to get video metadata: $e");
      return VideoMetadata(duration: 0, width: 0, height: 0);
    }
  }
  /// 获取图片尺寸
  Future<ImageDimensions> _getImageDimensions(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null) {
        return ImageDimensions(width: image.width, height: image.height);
      }
    } catch (e) {
      LogUtil.log("[UploadManager] Error getting image dimensions: $e");
    }
    return ImageDimensions(width: 0, height: 0);
  }

  Future<void> _reportUploadedFiles(
      List<MapEntry<LocalFileInfo, String>> uploadedFiles,
      String uploadPath,
      int taskId,) async {
    try {
      final fileDetailList = <FileDetailModel>[];

      for (var entry in uploadedFiles) {
        final fileInfo = entry.key;
        final md5Hash = entry.value;
        final fileName = fileInfo.fileName;
        final fileNameWithoutExt = p.basenameWithoutExtension(fileName);
        final fileExt = p.extension(fileName).replaceFirst('.', '');
        final imageFileName = "$fileNameWithoutExt.jpg";
        final photoDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(
            fileInfo.createTime);

        int width = 0;
        int height = 0;
        int duration = 0;

        if (fileInfo.fileType == LocalFileType.image) {
          final dimensions = await _getImageDimensions(fileInfo.filePath);
          width = dimensions.width;
          height = dimensions.height;
          duration = 0;
        } else if (fileInfo.fileType == LocalFileType.video) {
          final metadata = await _getVideoMetadata(fileInfo.filePath);
          width = metadata.width;
          height = metadata.height;
          duration = metadata.duration;
          LogUtil.log("[UploadManager] Video metadata for ${fileInfo
              .fileName}: ${width}x${height}, ${duration}s");
        }

        fileDetailList.add(FileDetailModel(
          fileCode: md5Hash,
          metaPath: "$uploadPath/$md5Hash/$fileName",
          middlePath: "$uploadPath/$md5Hash/show_$imageFileName",
          snailPath: "$uploadPath/$md5Hash/thumbnail_$imageFileName",
          fileName: fileName,
          fileType: fileInfo.fileType == LocalFileType.image ? "P" : "V",
          duration: duration,
          width: width,
          height: height,
          size: fileInfo.fileSize,
          fmt: fileExt,
          photoDate: photoDate,
          latitude: "0.0",
          longitude: "0.0",
        ));
      }

      final response = await provider.reportSyncTaskFiles(
          taskId, fileDetailList);

      if (response.isSuccess) {
        LogUtil.log("[UploadManager] Reported uploaded files successfully");

        // ✅ 上报成功后批量更新状态为 status=2
        for (var entry in uploadedFiles) {
          final md5Hash = entry.value;
          await dbHelper.updateStatusByMd5Hash(md5Hash, 2);
          _uploadedMd5List.add(md5Hash);  // ✅ 记录成功的 MD5
        }

        await taskManager.updateStatus(taskId, UploadTaskStatus.success);
        LogUtil.log("[UploadManager] Updated ${uploadedFiles
            .length} files status to success");
      } else {
        LogUtil.log("[UploadManager] Failed to report: ${response.message}");
      }
    } catch (e, stackTrace) {
      LogUtil.log("[UploadManager] Error reporting: $e\n$stackTrace");
    }
  }
}
/// 视频元数据
class VideoMetadata {
  final int duration;  // 时长（秒）
  final int width;     // 宽度
  final int height;    // 高度

  VideoMetadata({
    required this.duration,
    required this.width,
    required this.height,
  });
}

/// 图片尺寸
class ImageDimensions {
  final int width;
  final int height;

  ImageDimensions({
    required this.width,
    required this.height,
  });
}