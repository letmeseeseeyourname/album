import 'dart:async';
import 'dart:convert';
import 'dart:developer' as LogUtil;
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:semaphore_plus/semaphore_plus.dart';

import '../../minio/minio_service.dart';
import '../../services/thumbnail_helper.dart';
import '../../services/transfer_speed_service.dart';
import '../../user/my_instance.dart';
import '../database/database_helper.dart';
import '../database/upload_task_db_helper.dart';
import '../models/file_detail_model.dart';
import '../models/file_upload_model.dart';
import '../models/local_file_item.dart';
import '../provider/album_provider.dart';

/// 文件类型枚举
enum LocalFileType { image, video, unknown }

/// 本地文件信息
class LocalFileInfo {
  final String filePath;
  final String fileName;
  final LocalFileType fileType;
  final int fileSize;
  final DateTime createTime;

  LocalFileInfo({
    required this.filePath,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.createTime,
  });

  /// 转换为 FileItem（用于数据库存储）
  FileItem toFileItem(String userId, String deviceCode, String md5Hash) {
    return FileItem(
      md5Hash: md5Hash,
      filePath: filePath,
      fileName: fileName,
      fileType: fileType == LocalFileType.image ? "P" : "V",
      fileSize: fileSize,
      assetId: md5Hash,
      status: 0,
      userId: userId,
      deviceCode: deviceCode,
      duration: 0,
      width: 0,
      height: 0,
      lng: 0.0,
      lat: 0.0,
      createDate: createTime.millisecondsSinceEpoch.toDouble(),
    );
  }
}

/// 上传进度信息（增强版）
class LocalUploadProgress {
  final int totalFiles;
  final int uploadedFiles;
  final int failedFiles;
  final int retryRound;        // 当前重试轮次
  final int maxRetryRounds;    // 最大重试轮次
  final String? currentFileName;
  final String? statusMessage; // 状态消息

  LocalUploadProgress({
    required this.totalFiles,
    required this.uploadedFiles,
    required this.failedFiles,
    this.retryRound = 0,
    this.maxRetryRounds = 3,
    this.currentFileName,
    this.statusMessage,
  });

  double get progress => totalFiles > 0 ? uploadedFiles / totalFiles : 0.0;

  bool get isRetrying => retryRound > 0;

  String get displayStatus {
    if (statusMessage != null) return statusMessage!;
    if (isRetrying) {
      return '重试第 $retryRound/$maxRetryRounds 轮，处理失败文件...';
    }
    return '上传中...';
  }
}

/// 上传配置
class LocalUploadConfig {
  static const int maxConcurrentUploads = 5;
  static const int imageChunkSize = 10;
  static const int videoChunkSize = 1;
  static const int maxRetryAttempts = 5;       // 单文件最大重试次数
  static const int maxRetryRounds = 10;         // 失败队列最大重试轮次
  static const int retryDelaySeconds = 2;
  static const int retryRoundDelaySeconds = 5; // 每轮重试前的等待时间
  static const double reservedStorageGB = 8.0;
  static const int md5ReadSizeBytes = 1024 * 1024;
  static const int thumbnailWidth = 300;
  static const int thumbnailHeight = 300;
  static const int thumbnailQuality = 35;
  static const int mediumWidth = 1080;
  static const int mediumHeight = 1920;
  static const int mediumQuality = 75;
}

/// 失败文件记录
class FailedFileRecord {
  final LocalFileInfo fileInfo;
  final String md5Hash;
  final String? errorMessage;
  int retryCount;

  FailedFileRecord({
    required this.fileInfo,
    required this.md5Hash,
    this.errorMessage,
    this.retryCount = 0,
  });

  MapEntry<LocalFileInfo, String> toEntry() => MapEntry(fileInfo, md5Hash);
}

/// 本地文件夹上传管理器（增强版 - 带失败队列重试）
class LocalFolderUploadManager extends ChangeNotifier {
  DatabaseHelper dbHelper = DatabaseHelper.instance;
  UploadFileTaskManager taskManager = UploadFileTaskManager.instance;
  AlbumProvider provider = AlbumProvider();
  final minioService = MinioService.instance;

  LocalUploadProgress? _currentProgress;
  bool _isUploading = false;
  bool _isCancelled = false;

  // 失败文件队列
  final List<FailedFileRecord> _failedQueue = [];

  // 永久失败文件（超过重试次数）
  final List<FailedFileRecord> _permanentlyFailedFiles = [];
  // ✅ 累计已上传字节数（用于速度计算）
  int _totalUploadedBytes = 0;
  LocalFolderUploadManager();

  LocalUploadProgress? get currentProgress => _currentProgress;
  bool get isUploading => _isUploading;
  List<FailedFileRecord> get failedQueue => List.unmodifiable(_failedQueue);
  List<FailedFileRecord> get permanentlyFailedFiles => List.unmodifiable(_permanentlyFailedFiles);

  /// 取消上传
  void cancelUpload() {
    _isCancelled = true;
    LogUtil.log('[UploadManager] Upload cancelled by user');
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
      maxRetryRounds: LocalUploadConfig.maxRetryRounds,
      currentFileName: fileName,
      statusMessage: statusMessage,
    );
    notifyListeners();
  }

  /// 从本地文件列表上传（主入口）
  Future<void> uploadLocalFiles(
      List<String> localFilePaths, {
        Function(LocalUploadProgress)? onProgress,
        Function(bool success, String message)? onComplete,
      }) async {
    if (_isUploading) {
      LogUtil.log("[UploadManager] Upload already in progress");
      onComplete?.call(false, "已有上传任务在进行中");
      return;
    }

    if (localFilePaths.isEmpty) {
      LogUtil.log("[UploadManager] No files to upload");
      onComplete?.call(false, "没有选择文件");
      return;
    }

    _isUploading = true;
    _isCancelled = false;
    _failedQueue.clear();
    _permanentlyFailedFiles.clear();
    _totalUploadedBytes = 0;  // ✅ 重置累计字节数

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
      LogUtil.log("[UploadManager] User: $userId, Device: $deviceCode, Group: $groupId");

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
          LogUtil.log("[UploadManager] Failed to parse file: $filePath, error: $e");
          failedFiles++;
        }
      }

      if (_isCancelled) {
        onComplete?.call(false, "上传已取消");
        return;
      }

      if (localFileInfos.isEmpty) {
        throw Exception("没有有效的文件");
      }

      _updateProgress(total: totalFiles, uploaded: uploadedFiles, failed: failedFiles);
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
          LogUtil.log("[UploadManager] Failed to calculate MD5: ${fileInfo.filePath}");
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
          LogUtil.log("[UploadManager] File already uploaded: ${entry.key.fileName}");
          uploadedFiles++;
        } else {
          newFiles.add(entry);
        }
      }

      if (newFiles.isEmpty) {
        LogUtil.log("[UploadManager] All files already uploaded");
        onComplete?.call(true, "所有文件已存在，无需重复上传");
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
        onComplete?.call(true, "所有文件已存在或重复，无需上传");
        return;
      }

      _updateProgress(total: totalFiles, uploaded: uploadedFiles, failed: failedFiles);
      onProgress?.call(_currentProgress!);

      // 5. 分批处理
      final chunks = _splitIntoChunks(uniqueFiles, LocalUploadConfig.imageChunkSize);

      for (var chunk in chunks) {
        if (_isCancelled) break;

        final chunkSize = chunk.fold<double>(0, (sum, e) => sum + e.key.fileSize) / (1024 * 1024 * 1024);
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
        LogUtil.log("[UploadManager] Starting retry rounds for ${_failedQueue.length} failed files");

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

      // 7. 生成最终结果
      final finalMessage = _generateCompletionMessage(uploadedFiles, failedFiles, totalFiles);
      LogUtil.log("[UploadManager] $finalMessage");

      onComplete?.call(
        _permanentlyFailedFiles.isEmpty,
        finalMessage,
      );

    } catch (e, stackTrace) {
      LogUtil.log("[UploadManager] Error: $e\n$stackTrace");
      onComplete?.call(false, "上传失败：$e");
    } finally {
      _isUploading = false;
      _updateProgress(
        total: totalFiles,
        uploaded: uploadedFiles,
        failed: failedFiles,
        statusMessage: '上传完成',
      );
      onProgress?.call(_currentProgress!);
      TransferSpeedService.instance.onUploadComplete();
      notifyListeners();
    }
  }

  /// ✅ 处理失败队列重试（核心新增方法）
  Future<Map<String, int>> _processFailedQueueWithRetry(
      int userId,
      int groupId,
      String deviceCode,
      int totalFiles,
      int uploadedFiles,
      int failedFiles,
      Function(LocalUploadProgress)? onProgress,
      ) async {
    int currentRound = 0;

    while (_failedQueue.isNotEmpty &&
        currentRound < LocalUploadConfig.maxRetryRounds &&
        !_isCancelled) {

      currentRound++;
      LogUtil.log('[UploadManager] ════════════════════════════════════════');
      LogUtil.log('[UploadManager] Retry Round $currentRound/${LocalUploadConfig.maxRetryRounds}');
      LogUtil.log('[UploadManager] Files to retry: ${_failedQueue.length}');
      LogUtil.log('[UploadManager] ════════════════════════════════════════');

      _updateProgress(
        total: totalFiles,
        uploaded: uploadedFiles,
        failed: failedFiles,
        retryRound: currentRound,
        statusMessage: '重试第 $currentRound/${LocalUploadConfig.maxRetryRounds} 轮...',
      );
      onProgress?.call(_currentProgress!);

      // 等待一段时间再重试（让网络恢复）
      await Future.delayed(Duration(seconds: LocalUploadConfig.retryRoundDelaySeconds));

      // 取出当前轮次要重试的文件
      final filesToRetry = List<FailedFileRecord>.from(_failedQueue);
      _failedQueue.clear();

      // 转换为上传格式
      final retryEntries = filesToRetry.map((r) => r.toEntry()).toList();

      // 分批重试
      final chunks = _splitIntoChunks(retryEntries, LocalUploadConfig.imageChunkSize);

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
      LogUtil.log('[UploadManager] Moving ${_failedQueue.length} files to permanently failed');
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
        LogUtil.log('[UploadManager] File exceeded max retries: ${record.fileInfo.fileName}');
      }
    }

    _failedQueue.removeWhere((r) => toRemove.contains(r));
  }

  /// 添加文件到失败队列
  void _addToFailedQueue(LocalFileInfo fileInfo, String md5Hash, String? errorMessage, {bool isRetry = false}) {
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

    LogUtil.log('[UploadManager] Added to failed queue: ${fileInfo.fileName} (retries: ${_failedQueue.last.retryCount})');
  }

  /// MD5 去重
  List<MapEntry<LocalFileInfo, String>> _deduplicateByMd5(
      List<MapEntry<LocalFileInfo, String>> files,
      ) {
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
        buffer.write('，失败 ${_permanentlyFailedFiles.length} 个');//（已达最大重试次数）
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

        final fileItem = fileInfo.toFileItem(userId.toString(), deviceCode, md5Hash);
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

      if (!response.isSuccess) {
        LogUtil.log("[UploadManager] Failed to create sync task: ${response.message}");
        // 将所有文件加入失败队列
        for (var entry in chunk) {
          _addToFailedQueue(entry.key, entry.value, response.message, isRetry: isRetry);
        }
        return {'uploaded': uploadedFiles, 'failed': failedFiles + uploadList.length};
      }

      final uploadPath = _removeFirstAndLastSlash(response.model?.uploadPath ?? "");
      final taskId = response.model?.taskId ?? 0;

      final chunkFileCount = chunk.length;
      final chunkTotalSize = chunk.fold<int>(0, (sum, e) => sum + e.key.fileSize);

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
        _addToFailedQueue(entry.key, entry.value, e.toString(), isRetry: isRetry);
      }
      return {'uploaded': uploadedFiles, 'failed': failedFiles + uploadList.length};
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
      _uploadSingleFile(fileInfo, md5Hash, uploadPath)
          .then((success) async {
        try {
          if (success) {
            LogUtil.log("[UploadManager] ✅ Uploaded: ${fileInfo.fileName}");
            uploadedEntries.add(entry);
            await dbHelper.updateStatusByMd5Hash(md5Hash, 2);
            uploadedFiles++;
          } else {
            LogUtil.log("[UploadManager] ❌ Failed: ${fileInfo.fileName}");
            await dbHelper.updateStatusByMd5Hash(md5Hash, 3);
            failedFiles++;
            // ✅ 加入失败队列
            _addToFailedQueue(fileInfo, md5Hash, 'Upload failed', isRetry: isRetry);
          }

          _updateProgress(
            total: totalFiles,
            uploaded: uploadedFiles,
            failed: failedFiles,
            retryRound: retryRound,
          );
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

    // 等待所有任务完成
    if (pendingTasks > 0) {
      await completer.future;
    }

    // 报告上传结果
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
  Future<bool> _uploadSingleFile(
      LocalFileInfo fileInfo,
      String md5Hash,
      String uploadPath,
      ) async {
    for (int attempt = 0; attempt < LocalUploadConfig.maxRetryAttempts; attempt++) {
      if (_isCancelled) return false;

      try {
        if (attempt > 0) {
          LogUtil.log("[UploadManager] Retry $attempt/${LocalUploadConfig.maxRetryAttempts}: ${fileInfo.fileName}");
          await Future.delayed(Duration(seconds: LocalUploadConfig.retryDelaySeconds));
        }

        final success = await _doUpload(fileInfo, md5Hash, uploadPath);
        if (success) return true;

      } catch (e) {
        LogUtil.log("[UploadManager] Upload error (attempt $attempt): $e");
      }
    }

    return false;
  }

  /// 执行实际上传
  Future<bool> _doUpload(
      LocalFileInfo fileInfo,
      String md5Hash,
      String uploadPath,
      ) async {
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

      // 1. 上传原始文件
      LogUtil.log("Uploading original file: ${fileInfo.filePath}");
      var result = await minioService.uploadFile(
        bucketName,
        "$uploadPathWithoutBucket/$md5Hash/$fileName",
        file.path,
      );

      if (!result.success) {
        LogUtil.log("Failed to upload original file");
        return false;
      }
      // ✅ 更新累计字节数并通知速度服务
      _totalUploadedBytes += fileInfo.fileSize;
      TransferSpeedService.instance.updateUploadProgress(_totalUploadedBytes);

      // 2. 生成并上传缩略图
      final thumbnailFile = await _createThumbnail(file, imageFileName, fileInfo.fileType);
      if (thumbnailFile == null) {
        LogUtil.log("Failed to create thumbnail");
        return false;
      }

      result = await minioService.uploadFile(
        bucketName,
        "$uploadPathWithoutBucket/$md5Hash/thumbnail_$imageFileName",
        thumbnailFile.path,
      );

      // ✅ 更新累计字节数
      final thumbnailSize = await thumbnailFile.length();
      _totalUploadedBytes += thumbnailSize;
      TransferSpeedService.instance.updateUploadProgress(_totalUploadedBytes);
      await _cleanupFile(thumbnailFile);

      if (!result.success) {
        LogUtil.log("Failed to upload thumbnail");
        return false;
      }

      // 3. 生成并上传中等尺寸
      final mediumFile = await _createMedium(file, imageFileName, fileInfo.fileType);
      if (mediumFile == null) {
        LogUtil.log("Failed to create medium file");
        return false;
      }

      result = await minioService.uploadFile(
        bucketName,
        "$uploadPathWithoutBucket/$md5Hash/show_$imageFileName",
        mediumFile.path,
      );

      // ✅ 更新累计字节数
      final mediumSize = await mediumFile.length();
      _totalUploadedBytes += mediumSize;
      TransferSpeedService.instance.updateUploadProgress(_totalUploadedBytes);
      await _cleanupFile(mediumFile);

      if (!result.success) {
        LogUtil.log("Failed to upload medium file");
        return false;
      }

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
    const imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.heic'];
    const videoExts = ['.mp4', '.mov', '.avi', '.mkv', '.3gp', '.3gp2'];

    if (imageExts.contains(ext)) return LocalFileType.image;
    if (videoExts.contains(ext)) return LocalFileType.video;
    return LocalFileType.unknown;
  }

  List<List<MapEntry<LocalFileInfo, String>>> _splitIntoChunks(
      List<MapEntry<LocalFileInfo, String>> files,
      int chunkSize,
      ) {
    final chunks = <List<MapEntry<LocalFileInfo, String>>>[];
    final imageList = files.where((e) => e.key.fileType == LocalFileType.image).toList();
    final videoList = files.where((e) => e.key.fileType == LocalFileType.video).toList();

    for (var i = 0; i < imageList.length; i += chunkSize) {
      chunks.add(imageList.sublist(i, (i + chunkSize).clamp(0, imageList.length)));
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
    final used = (MyInstance().p6deviceInfoModel?.ttlUsed ?? 0) + additionalSizeGB;
    final max = (MyInstance().p6deviceInfoModel?.ttlAll ?? 0) - LocalUploadConfig.reservedStorageGB;
    return used < max;
  }

  Future<void> _cleanupFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// 创建缩略图
  Future<File?> _createThumbnail(File file, String outputFileName, LocalFileType fileType) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = "${tempDir.path}/thumbnail_$outputFileName";

      if (fileType == LocalFileType.video) {
        // 使用 ThumbnailHelper 生成视频缩略图
        final thumbnailPath = await ThumbnailHelper.generateThumbnail(file.path);

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
  Future<File?> _createMedium(File file, String outputFileName, LocalFileType fileType) async {
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
      // 尝试使用 ffprobe 获取视频信息
      final result = await Process.run(
        'ffprobe',
        [
          '-v', 'quiet',
          '-print_format', 'json',
          '-show_format',
          '-show_streams',
          videoPath,
        ],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        final jsonOutput = result.stdout.toString();
        final data = json.decode(jsonOutput) as Map<String, dynamic>;

        // 获取视频流信息
        final streams = data['streams'] as List<dynamic>?;
        if (streams != null) {
          for (var stream in streams) {
            if (stream['codec_type'] == 'video') {
              final width = stream['width'] as int? ?? 0;
              final height = stream['height'] as int? ?? 0;

              // 获取时长（秒）
              int duration = 0;
              if (stream['duration'] != null) {
                duration = double.parse(stream['duration'].toString()).toInt();
              } else if (data['format'] != null && data['format']['duration'] != null) {
                duration = double.parse(data['format']['duration'].toString()).toInt();
              }

              return VideoMetadata(
                duration: duration,
                width: width,
                height: height,
              );
            }
          }
        }
      }
    } catch (e) {
      LogUtil.log("Failed to get video metadata using ffprobe: $e");
    }

    // 如果 ffprobe 失败，尝试使用文件属性估算
    try {
      final file = File(videoPath);
      final size = await file.length();

      // 根据文件大小估算分辨率（粗略估计）
      int width = 1280;
      int height = 720;

      if (size < 10 * 1024 * 1024) { // < 10MB
        width = 640;
        height = 480;
      } else if (size < 50 * 1024 * 1024) { // < 50MB
        width = 1280;
        height = 720;
      } else { // >= 50MB
        width = 1920;
        height = 1080;
      }

      // 估算时长（假设平均码率 2Mbps）
      final estimatedDuration = (size / (2 * 1024 * 1024 / 8)).toInt();

      LogUtil.log("Using estimated video metadata for: $videoPath");
      return VideoMetadata(
        duration: estimatedDuration,
        width: width,
        height: height,
      );
    } catch (e) {
      LogUtil.log("Error estimating video metadata: $e");
    }

    // 返回默认值
    return VideoMetadata(duration: 0, width: 0, height: 0);
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
      int taskId,
      ) async {
    try {
      final fileDetailList = <FileDetailModel>[];

      for (var entry in uploadedFiles) {
        final fileInfo = entry.key;
        final md5Hash = entry.value;
        final fileName = fileInfo.fileName;
        final fileNameWithoutExt = p.basenameWithoutExtension(fileName);
        final fileExt = p.extension(fileName).replaceFirst('.', '');
        final imageFileName = "$fileNameWithoutExt.jpg";
        final photoDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(fileInfo.createTime);

        // 获取媒体尺寸和时长
        int width = 0;
        int height = 0;
        int duration = 0;

        if (fileInfo.fileType == LocalFileType.image) {
          // 获取图片尺寸
          final dimensions = await _getImageDimensions(fileInfo.filePath);
          width = dimensions.width;
          height = dimensions.height;
          duration = 0;
        } else if (fileInfo.fileType == LocalFileType.video) {
          // 获取视频元数据
          final metadata = await _getVideoMetadata(fileInfo.filePath);
          width = metadata.width;
          height = metadata.height;
          duration = metadata.duration;
          LogUtil.log("[UploadManager] Video metadata for ${fileInfo.fileName}: ${width}x${height}, ${duration}s");
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

      final response = await provider.reportSyncTaskFiles(taskId, fileDetailList);
      if (response.isSuccess) {
        LogUtil.log("[UploadManager] Reported uploaded files successfully");
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