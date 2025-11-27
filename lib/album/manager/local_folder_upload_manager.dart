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
      assetId: md5Hash, // 本地文件使用MD5作为ID
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

/// 上传进度信息
class LocalUploadProgress {
  final int totalFiles;
  final int uploadedFiles;
  final int failedFiles;
  final String? currentFileName;

  LocalUploadProgress({
    required this.totalFiles,
    required this.uploadedFiles,
    required this.failedFiles,
    this.currentFileName,
  });

  double get progress => totalFiles > 0 ? uploadedFiles / totalFiles : 0.0;
}

/// 上传配置
class LocalUploadConfig {
  static const int maxConcurrentUploads = 5;
  static const int imageChunkSize = 10;
  static const int videoChunkSize = 1;
  static const int maxRetryAttempts = 3;
  static const int retryDelaySeconds = 2;
  static const double reservedStorageGB = 8.0;
  static const int md5ReadSizeBytes = 1024 * 1024; // 1MB
  static const int thumbnailWidth = 300;
  static const int thumbnailHeight = 300;
  static const int thumbnailQuality = 35;
  static const int mediumWidth = 1080;
  static const int mediumHeight = 1920;
  static const int mediumQuality = 75;
}

/// 本地文件夹上传管理器
///
/// 专门处理从本地文件夹选择的文件上传，与移动设备相册上传分离
/// 但复用相同的底层服务：数据库、任务管理、文件上传等
class LocalFolderUploadManager extends ChangeNotifier {
  // static final LocalFolderUploadManager _singleton =
  // LocalFolderUploadManager._internal();

  // 复用原有的底层服务
  DatabaseHelper dbHelper = DatabaseHelper.instance;
  UploadFileTaskManager taskManager = UploadFileTaskManager.instance;
  AlbumProvider provider = AlbumProvider();
  final minioService = MinioService.instance;
  LocalUploadProgress? _currentProgress;
  bool _isUploading = false;

  // LocalFolderUploadManager._internal();
  //
  // factory LocalFolderUploadManager() {
  //   return _singleton;
  // }

  LocalFolderUploadManager();

  /// 获取当前上传进度
  LocalUploadProgress? get currentProgress => _currentProgress;

  /// 是否正在上传
  bool get isUploading => _isUploading;

  /// 更新上传进度
  void _updateProgress(int total, int uploaded, int failed, [String? fileName]) {
    _currentProgress = LocalUploadProgress(
      totalFiles: total,
      uploadedFiles: uploaded,
      failedFiles: failed,
      currentFileName: fileName,
    );
    notifyListeners();
  }

  /// 从本地文件列表上传
  ///
  /// [localFilePaths] 本地文件路径列表
  /// [onProgress] 进度回调
  /// [onComplete] 完成回调
  Future<void> uploadLocalFiles(
      List<String> localFilePaths, {
        Function(LocalUploadProgress)? onProgress,
        Function(bool success, String message)? onComplete,
      }) async {
    if (_isUploading) {
      LogUtil.log("Upload already in progress");
      onComplete?.call(false, "已有上传任务在进行中");
      return;
    }

    if (localFilePaths.isEmpty) {
      LogUtil.log("No files to upload");
      onComplete?.call(false, "没有选择文件");
      return;
    }

    _isUploading = true;
    int totalFiles = localFilePaths.length;
    int uploadedFiles = 0;
    int failedFiles = 0;

    // 启动传输速率监控
    TransferSpeedService.instance.startMonitoring();

    try {
      final userId = MyInstance().user?.user?.id ?? 0;
      final groupId = MyInstance().group?.groupId ?? 0;
      final deviceCode = MyInstance().deviceCode;

      if (userId == 0) {
        throw Exception("用户未登录");
      }

      if (deviceCode.isEmpty) {
        throw Exception("设备标识无效");
      }

      LogUtil.log("Starting local folder upload, total: $totalFiles");
      LogUtil.log("User: $userId, Device: $deviceCode, Group: $groupId");

      // 1. 解析本地文件信息
      final localFileInfos = <LocalFileInfo>[];
      for (var filePath in localFilePaths) {
        try {
          final fileInfo = await _parseLocalFile(filePath);
          if (fileInfo != null) {
            localFileInfos.add(fileInfo);
          } else {
            failedFiles++;
          }
        } catch (e) {
          LogUtil.log("Failed to parse file: $filePath, error: $e");
          failedFiles++;
        }
      }

      if (localFileInfos.isEmpty) {
        throw Exception("没有有效的文件");
      }

      _updateProgress(totalFiles, uploadedFiles, failedFiles);
      onProgress?.call(_currentProgress!);

      // 2. 检查数据库中已存在的文件（通过MD5去重）
      final filesWithMd5 = <MapEntry<LocalFileInfo, String>>[];
      for (var fileInfo in localFileInfos) {
        try {
          final file = File(fileInfo.filePath);
          final md5Hash = await _getFileMd5(file);
          filesWithMd5.add(MapEntry(fileInfo, md5Hash));
        } catch (e) {
          LogUtil.log("Failed to calculate MD5: ${fileInfo.filePath}, error: $e");
          failedFiles++;
        }
      }

      // 3. 批量查询数据库，过滤已上传的文件（性能优化：一次查询代替多次）
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
          // 已上传过
          LogUtil.log("File already uploaded: ${entry.key.fileName}");
          uploadedFiles++;
        } else {
          newFiles.add(entry);
        }
      }

      if (newFiles.isEmpty) {
        LogUtil.log("All files already uploaded");
        onComplete?.call(true, "所有文件已存在，无需重复上传");
        return;
      }

      // 3.5. MD5去重：如果多个文件MD5相同，只保留第一个文件上传
      final uniqueFiles = <MapEntry<LocalFileInfo, String>>[];
      final md5ToFilesMap = <String, List<LocalFileInfo>>{};
      final duplicateFilesCount = <String, int>{};

      for (var entry in newFiles) {
        final md5 = entry.value;
        final fileInfo = entry.key;

        if (!md5ToFilesMap.containsKey(md5)) {
          // 首次遇到此MD5，加入上传列表
          md5ToFilesMap[md5] = [fileInfo];
          uniqueFiles.add(entry);
        } else {
          // MD5重复，记录重复文件但不上传
          md5ToFilesMap[md5]!.add(fileInfo);
          duplicateFilesCount[md5] = (duplicateFilesCount[md5] ?? 1) + 1;

          // 将重复文件计入已上传（因为不需要实际上传）
          uploadedFiles++;
          LogUtil.log("Duplicate file (MD5: $md5): ${fileInfo.fileName}");
        }
      }

      // 输出去重统计信息
      if (duplicateFilesCount.isNotEmpty) {
        final totalDuplicates = duplicateFilesCount.values.fold(0, (sum, count) => sum + count);
        LogUtil.log("MD5 Deduplication: Found $totalDuplicates duplicate files");
        LogUtil.log("Unique MD5s to upload: ${uniqueFiles.length} (from ${newFiles.length} files)");

        // 详细日志：显示每组重复文件
        duplicateFilesCount.forEach((md5, count) {
          final fileList = md5ToFilesMap[md5]!;
          LogUtil.log("  MD5 $md5 has ${count + 1} copies:");
          for (var i = 0; i < fileList.length && i < 3; i++) {
            LogUtil.log("    - ${fileList[i].fileName}");
          }
          if (fileList.length > 3) {
            LogUtil.log("    ... and ${fileList.length - 3} more");
          }
        });
      }

      // 使用去重后的文件列表继续处理
      final filesToUpload = uniqueFiles;

      if (filesToUpload.isEmpty) {
        LogUtil.log("All files are duplicates within this batch");
        onComplete?.call(true, "所有文件已存在或重复，无需上传");
        return;
      }

      _updateProgress(totalFiles, uploadedFiles, failedFiles);
      onProgress?.call(_currentProgress!);

      // 4. 分批处理（使用去重后的文件列表）
      final chunks = _splitIntoChunks(filesToUpload, LocalUploadConfig.imageChunkSize);

      for (var chunk in chunks) {
        // 检查存储空间
        final chunkSize = chunk.fold<double>(
            0,
                (sum, entry) => sum + entry.key.fileSize
        ) / (1024 * 1024 * 1024);

        if (!_hasEnoughStorage(chunkSize)) {
          LogUtil.log("Storage is full");
          throw Exception("云端存储空间不足");
        }

        // 处理单个批次
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

      LogUtil.log("Upload completed: $uploadedFiles uploaded, $failedFiles failed");
      onComplete?.call(
        failedFiles == 0,
        failedFiles == 0
            ? "上传完成！共 $uploadedFiles 个文件"
            : "上传完成，成功 $uploadedFiles 个，失败 $failedFiles 个",
      );
    } catch (e, stackTrace) {
      LogUtil.log("Error in uploadLocalFiles: $e\n$stackTrace");
      onComplete?.call(false, "上传失败：$e");
    } finally {
      _isUploading = false;
      _updateProgress(totalFiles, uploadedFiles, failedFiles);
      onProgress?.call(_currentProgress!);

      // 停止传输速率监控
      TransferSpeedService.instance.onUploadComplete();

      notifyListeners();
    }
  }

  /// 解析本地文件信息
  Future<LocalFileInfo?> _parseLocalFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        LogUtil.log("File not found: $filePath");
        return null;
      }

      final fileName = p.basename(filePath);
      final fileType = _detectFileType(filePath);

      if (fileType == LocalFileType.unknown) {
        LogUtil.log("Unsupported file type: $filePath");
        return null;
      }

      final stat = await file.stat();

      return LocalFileInfo(
        filePath: filePath,
        fileName: fileName,
        fileType: fileType,
        fileSize: stat.size,
        createTime: stat.modified,
      );
    } catch (e) {
      LogUtil.log("Error parsing local file: $e");
      return null;
    }
  }

  /// 检测文件类型
  LocalFileType _detectFileType(String filePath) {
    final ext = p.extension(filePath).toLowerCase();

    const imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.heic'];
    const videoExts = ['.mp4', '.mov', '.avi', '.mkv', '.3gp', '.3gp2'];

    if (imageExts.contains(ext)) {
      return LocalFileType.image;
    } else if (videoExts.contains(ext)) {
      return LocalFileType.video;
    }

    return LocalFileType.unknown;
  }

  /// 分批处理
  List<List<MapEntry<LocalFileInfo, String>>> _splitIntoChunks(
      List<MapEntry<LocalFileInfo, String>> files,
      int chunkSize,
      ) {
    final chunks = <List<MapEntry<LocalFileInfo, String>>>[];

    final imageList = files
        .where((entry) => entry.key.fileType == LocalFileType.image)
        .toList();
    final videoList = files
        .where((entry) => entry.key.fileType == LocalFileType.video)
        .toList();

    // 图片按指定大小分批
    for (var i = 0; i < imageList.length; i += chunkSize) {
      final end = (i + chunkSize < imageList.length)
          ? i + chunkSize
          : imageList.length;
      chunks.add(imageList.sublist(i, end));
    }

    // 视频单个处理
    for (var i = 0; i < videoList.length; i += LocalUploadConfig.videoChunkSize) {
      final end = (i + LocalUploadConfig.videoChunkSize < videoList.length)
          ? i + LocalUploadConfig.videoChunkSize
          : videoList.length;
      chunks.add(videoList.sublist(i, end));
    }

    return chunks;
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
      Function(LocalUploadProgress)? onProgress,
      ) async {
    final uploadList = <FileUploadModel>[];
    final fileItemsToInsert = <FileItem>[];

    // 准备上传列表，并将文件信息插入数据库
    for (var entry in chunk) {
      try {
        final fileInfo = entry.key;
        final md5Hash = entry.value;

        // 插入或更新数据库
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
        LogUtil.log("Error preparing file: $e");
        failedFiles++;
      }
    }

    if (uploadList.isEmpty) {
      return {'uploaded': uploadedFiles, 'failed': failedFiles};
    }

    // 创建同步任务（复用原有逻辑）
    try {
      final response = await provider.createSyncTask(uploadList);

      if (!response.isSuccess) {
        LogUtil.log("Failed to create sync task: ${response.message}");
        // 标记所有文件失败
        for (var item in fileItemsToInsert) {
          await dbHelper.updateStatusByMd5Hash(item.md5Hash!, 3); // 状态3表示失败
        }
        return {'uploaded': uploadedFiles, 'failed': failedFiles + uploadList.length};
      }

      final uploadPath = _removeFirstAndLastSlash(response.model?.uploadPath ?? "");
      final taskId = response.model?.taskId ?? 0;

      // ✅ 计算任务的文件统计信息
      final chunkFileCount = chunk.length;
      final chunkTotalSize = chunk.fold<int>(0, (sum, entry) => sum + entry.key.fileSize);

      // 使用原有的任务管理器（包含文件统计）
      await taskManager.insertTask(
        taskId: taskId,
        userId: userId,
        groupId: groupId,
        status: UploadTaskStatus.uploading,
        fileCount: chunkFileCount,
        totalSize: chunkTotalSize,
      );

      // 处理已存在的文件（服务器端去重）
      final failedFileList = response.model?.failedFileList ?? [];
      for (var failed in failedFileList) {
        if (failed.fileCode != null && failed.fileCode!.isNotEmpty) {
          if ((failed.failedReason ?? "").contains("exist")) {
            await dbHelper.updateStatusByMd5Hash(failed.fileCode!, 2);
            uploadedFiles++;
            LogUtil.log("File already exists on server: ${failed.fileCode}");
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
        LogUtil.log("No new files to upload, task revoked");
        return {'uploaded': uploadedFiles, 'failed': failedFiles};
      }

      // 执行上传（复用原有的上传逻辑）
      final uploadResult = await _uploadFiles(
        newFiles,
        uploadPath,
        taskId,
        totalFiles,
        uploadedFiles,
        failedFiles,
        onProgress,
      );

      return uploadResult;
    } catch (e, stackTrace) {
      LogUtil.log("Error processing chunk: $e\n$stackTrace");
      // 标记所有文件失败
      for (var item in fileItemsToInsert) {
        await dbHelper.updateStatusByMd5Hash(item.md5Hash!, 3);
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
      Function(LocalUploadProgress)? onProgress,
      ) async {
    final uploadedEntries = <MapEntry<LocalFileInfo, String>>[];
    final waitAllTaskFinishSignal = LocalSemaphore(1);
    final sm = LocalSemaphore(LocalUploadConfig.maxConcurrentUploads);
    int taskCount = files.length;

    // 计算总字节数和已上传字节数
    int totalBytes = files.fold(0, (sum, entry) => sum + entry.key.fileSize);
    int uploadedBytes = 0;

    LogUtil.log("Files to be uploaded: ${files.length}, Total bytes: $totalBytes");

    // 并发上传
    for (var entry in files) {
      await sm.acquire();

      final fileInfo = entry.key;
      final md5Hash = entry.value;

      // 更新数据库状态为上传中
      await dbHelper.updateStatusByMd5Hash(md5Hash, 1);

      _updateProgress(totalFiles, uploadedFiles, failedFiles, fileInfo.fileName);
      onProgress?.call(_currentProgress!);

      // 异步上传
      _uploadWithRetry(fileInfo, md5Hash, uploadPath, LocalUploadConfig.maxRetryAttempts)
          .then((result) async {
        try {
          if (result) {
            LogUtil.log("[upload] Uploaded: ${fileInfo.fileName}");
            uploadedEntries.add(entry);
            await dbHelper.updateStatusByMd5Hash(md5Hash, 2); // 状态2：已完成
            uploadedFiles++;

            // 更新已上传字节数和传输速率
            uploadedBytes += fileInfo.fileSize;
            TransferSpeedService.instance.updateUploadProgress(uploadedBytes);
          } else {
            LogUtil.log("[upload] Failed to upload: ${fileInfo.fileName}");
            await dbHelper.updateStatusByMd5Hash(md5Hash, 3); // 状态3：失败
            failedFiles++;
          }

          _updateProgress(totalFiles, uploadedFiles, failedFiles);
          onProgress?.call(_currentProgress!);
        } finally {
          sm.release();
          taskCount--;

          if (taskCount == 0) {
            waitAllTaskFinishSignal.release();
          }
        }
      });
    }

    // 等待所有上传完成
    await waitAllTaskFinishSignal.acquire();
    await waitAllTaskFinishSignal.acquire();

    // 报告上传结果
    if (uploadedEntries.isNotEmpty) {
      await _reportUploadedFiles(uploadedEntries, uploadPath, taskId);
      await taskManager.updateStatus(taskId, UploadTaskStatus.success);
    } else {
      LogUtil.log("No files uploaded successfully");
      await provider.revokeSyncTask(taskId);
      await taskManager.deleteTask(taskId);
    }

    return {'uploaded': uploadedFiles, 'failed': failedFiles};
  }

  /// 带重试机制的上传
  Future<bool> _uploadWithRetry(
      LocalFileInfo fileInfo,
      String md5Hash,
      String uploadPath,
      int maxRetries,
      ) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final success = await _uploadSingleFile(fileInfo, md5Hash, uploadPath);
        if (success) {
          return true;
        }

        if (attempt < maxRetries - 1) {
          LogUtil.log("Retry upload ${attempt + 1}/$maxRetries: ${fileInfo.fileName}");
          await Future.delayed(Duration(seconds: LocalUploadConfig.retryDelaySeconds));
        }
      } catch (e) {
        LogUtil.log("Upload attempt ${attempt + 1} failed: $e");
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: LocalUploadConfig.retryDelaySeconds));
        }
      }
    }

    return false;
  }

  /// 上传单个文件（复用原有的MinIO上传逻辑）
  Future<bool> _uploadSingleFile(
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

      // 2. 生成并上传缩略图
      final thumbnailFile = await _createThumbnail(file, imageFileName, fileInfo.fileType);
      if (thumbnailFile == null) {
        LogUtil.log("Failed to create thumbnail");
        return false;
      }

      result = await minioService.uploadFile(
        bucketName,
        "$uploadPathWithoutBucket/$md5Hash/thumbnail_$imageFileName",
        file.path,
      );

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
        file.path,
      );

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


  /// 报告上传的文件
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

        // 获取图片尺寸
        int width = 0;
        int height = 0;
        int duration=0;
        if (fileInfo.fileType == LocalFileType.image) {
          try {
            final file = File(fileInfo.filePath);
            final bytes = await file.readAsBytes();
            final image = img.decodeImage(bytes);
            if (image != null) {
              width = image.width;
              height = image.height;
              duration =0;
            }
          } catch (e) {
            LogUtil.log("Error getting image dimensions: $e");
          }
        }else if (fileInfo.fileType == LocalFileType.video) {
          // 获取视频元数据
          try {
            final metadata = await _getVideoMetadata(fileInfo.filePath);
            duration = metadata.duration;
            width = metadata.width;
            height = metadata.height;
            LogUtil.log("Video metadata for ${fileInfo.fileName}: ${width}x${height}, ${duration}s");
          } catch (e) {
            LogUtil.log("Error getting video metadata: $e");
          }
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
        LogUtil.log("Reported uploaded files successfully");
      } else {
        LogUtil.log("Failed to report uploaded files: ${response.message}");
      }
    } catch (e, stackTrace) {
      LogUtil.log("Error reporting uploaded files: $e\n$stackTrace");
    }
  }

  /// 计算文件MD5
  Future<String> _getFileMd5(File file) async {
    try {
      final bytes = await _readFileMax1M(file);
      final digest = md5.convert(bytes);
      return digest.toString();
    } catch (e) {
      LogUtil.log("Error calculating MD5: $e");
      rethrow;
    }
  }

  /// 读取文件前1MB
  Future<Uint8List> _readFileMax1M(File file) async {
    const maxSize = LocalUploadConfig.md5ReadSizeBytes;

    try {
      final raf = await file.open();
      final fileSize = await file.length();
      final readSize = fileSize > maxSize ? maxSize : fileSize;

      final bytes = await raf.read(readSize);
      await raf.close();

      return Uint8List.fromList(bytes);
    } catch (e) {
      LogUtil.log("Error reading file for MD5: $e");
      rethrow;
    }
  }

  /// 移除路径首尾斜杠
  String _removeFirstAndLastSlash(String path) {
    var result = path;
    if (result.startsWith('/')) {
      result = result.substring(1);
    }
    if (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  /// 检查存储空间
  bool _hasEnoughStorage(double additionalSizeGB) {
    final used = (MyInstance().p6deviceInfoModel?.ttlUsed ?? 0) + additionalSizeGB;
    final max = (MyInstance().p6deviceInfoModel?.ttlAll ?? 0) - LocalUploadConfig.reservedStorageGB;
    return used < max;
  }

  /// 清理临时文件
  Future<void> _cleanupFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        LogUtil.log("Deleted temp file: ${file.path}");
      }
    } catch (e) {
      LogUtil.log("Error deleting temp file: $e");
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