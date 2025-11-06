import 'dart:developer' as LogUtil;
import 'dart:io';
import 'dart:typed_data';
import 'package:ablumwin/user/provider/mine_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../minio/minio_service.dart';
import '../../user/models/resource_list_model.dart';
import '../../user/native_bridge.dart';
import '../../utils/file_util.dart';
import '../models/local_file_item.dart';
import '../../user/my_instance.dart';
import '../database/database_helper.dart';
import '../database/upload_task_db_helper.dart';
import '../models/file_detail_model.dart';
import '../models/file_upload_model.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:semaphore_plus/semaphore_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:intl/intl.dart';

import '../provider/album_provider.dart';

enum FileType { image, video, unknown }

/// 照片上传进度信息
class UploadProgress {
  final int totalFiles;
  final int uploadedFiles;
  final int failedFiles;
  final String? currentFileName;

  UploadProgress({
    required this.totalFiles,
    required this.uploadedFiles,
    required this.failedFiles,
    this.currentFileName,
  });

  double get progress => totalFiles > 0 ? uploadedFiles / totalFiles : 0.0;
}

/// 上传配置
class UploadConfig {
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

/// 照片上传管理器 - 管理所有照片和视频的上传任务
class UploadAllPhotosManager extends ChangeNotifier {
  static final UploadAllPhotosManager _singleton =
  UploadAllPhotosManager._internal();

  DatabaseHelper dbHelper = DatabaseHelper.instance;
  UploadFileTaskManager taskManager = UploadFileTaskManager.instance;
  AlbumProvider provider = AlbumProvider();
  final minioService = MinioService.instance;
  List<AssetEntity> mediaList = [];
  UploadProgress? _currentProgress;
  bool _isUploading = false;

  UploadAllPhotosManager._internal();

  factory UploadAllPhotosManager() {
    return _singleton;
  }

  /// 获取当前上传进度
  UploadProgress? get currentProgress => _currentProgress;

  /// 是否正在上传
  bool get isUploading => _isUploading;

  /// 更新上传进度
  void _updateProgress(int total, int uploaded, int failed, [String? fileName]) {
    _currentProgress = UploadProgress(
      totalFiles: total,
      uploadedFiles: uploaded,
      failedFiles: failed,
      currentFileName: fileName,
    );
    notifyListeners();
  }

  /// 开始处理图片 - 扫描设备并记录到数据库
  Future<void> beginProcessImages(Function complete) async {
    try {
      final mediaList = await getAllMedia();
      LogUtil.log("beginProcessImages ${mediaList.length}");

      final userId = MyInstance().user?.user?.id ?? 0;
      if (userId == 0) {
        LogUtil.log("Invalid user ID");
        complete();
        return;
      }

      final currentDevice = MyInstance().deviceCode;
      if (currentDevice.isEmpty) {
        LogUtil.log("Invalid device code");
        complete();
        return;
      }

      LogUtil.log("Starting uploadAll for user $userId on device $currentDevice");

      final localList = await dbHelper.fetchFilesByUserAndDevice(
          "$userId",
          currentDevice
      );

      this.mediaList = mediaList;
      if (mediaList.isEmpty) {
        LogUtil.log("No media found");
        complete();
        return;
      }

      // 批量插入新文件记录
      final newFiles = <FileItem>[];
      for (var entity in mediaList) {
        final fileItem = localList
            .where((element) => element.assetId == entity.id)
            .firstOrNull;

        if (fileItem != null) {
          continue; // 已在数据库中，跳过
        }

        newFiles.add(FileItem(
          md5Hash: "",
          filePath: "",
          fileName: "",
          fileType: entity.type == AssetType.image ? "P" : "V",
          fileSize: 0,
          assetId: entity.id,
          status: 0,
          userId: "$userId",
          deviceCode: currentDevice,
          duration: 0,
          width: 0,
          height: 0,
          lng: 0.0,
          lat: 0.0,
          createDate: entity.createDateTime.millisecondsSinceEpoch.toDouble(),
        ));
      }

      // 批量插入优化性能
      if (newFiles.isNotEmpty) {
        for (var file in newFiles) {
          await dbHelper.insertFile(file);
        }
        LogUtil.log("Inserted ${newFiles.length} new files into database");
      }

      complete();
    } catch (e, stackTrace) {
      LogUtil.log("Error in beginProcessImages: $e\n$stackTrace");
      complete();
    }
  }

  void load() {
    LogUtil.log("Loading UploadAllPhotosManager");
  }

  /// 请求权限并获取所有图片/视频
  static Future<List<AssetEntity>> getAllMedia() async {
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.hasAccess) {
        debugPrint("Permission denied");
        return [];
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        onlyAll: true,
      );

      final mediaList = <AssetEntity>[];
      for (var album in albums) {
        int page = 0;
        final albumList = <AssetEntity>[];

        while (true) {
          final assets = await album.getAssetListPaged(page: page, size: 100);
          if (assets.isEmpty) break;

          mediaList.addAll(assets);
          albumList.addAll(assets);
          page++;
        }

        LogUtil.log("Loaded album: ${album.name}, total assets: ${albumList.length}");
      }

      return mediaList;
    } catch (e, stackTrace) {
      LogUtil.log("Error in getAllMedia: $e\n$stackTrace");
      return [];
    }
  }

  /// 读取文件的前1MB用于计算MD5
  Future<Uint8List> readFileMax1M(File file) async {
    const maxSize = UploadConfig.md5ReadSizeBytes;

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

  /// 计算文件MD5值
  Future<String> getFileMd5(File file) async {
    try {
      final bytes = await readFileMax1M(file);
      final digest = md5.convert(bytes);
      return digest.toString();
    } catch (e) {
      LogUtil.log("Error calculating MD5: $e");
      rethrow;
    }
  }

  /// 检测文件类型
  static FileType detectFileType(File file) {
    final mimeType = lookupMimeType(file.path) ?? '';

    if (mimeType.startsWith('image/')) {
      return FileType.image;
    } else if (mimeType.startsWith('video/')) {
      return FileType.video;
    } else {
      return FileType.unknown;
    }
  }

  /// 获取Asset文件大小
  Future<int?> getAssetFileSize(AssetEntity asset) async {
    try {
      final file = await asset.file;
      if (file != null) {
        return await file.length();
      }
      return null;
    } catch (e) {
      LogUtil.log("Error getting asset file size: $e");
      return null;
    }
  }

  /// 将文件列表分成多个批次
  List<List<T>> splitIntoChunks<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];

    // 分离图片和视频
    final imageList = list
        .where((item) => (item is FileItem) && item.fileType == "P")
        .toList();
    final videoList = list
        .where((item) => (item is FileItem) && item.fileType == "V")
        .toList();

    // 图片按指定大小分批
    for (var i = 0; i < imageList.length; i += chunkSize) {
      final end = (i + chunkSize < imageList.length)
          ? i + chunkSize
          : imageList.length;
      chunks.add(imageList.sublist(i, end));
    }

    // 视频单个处理
    for (var i = 0; i < videoList.length; i += UploadConfig.videoChunkSize) {
      final end = (i + UploadConfig.videoChunkSize < videoList.length)
          ? i + UploadConfig.videoChunkSize
          : videoList.length;
      chunks.add(videoList.sublist(i, end));
    }

    return chunks;
  }

  /// 移除路径首尾的斜杠
  static String removeFirstAndLastSlash(String path) {
    var result = path;
    if (result.startsWith('/')) {
      result = result.substring(1);
    }
    if (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  /// 创建Asset的本地副本文件
  Future<File?> createAssetFile(AssetEntity? entity) async {
    if (entity == null) {
      return null;
    }

    try {
      final fileName = "${entity.id.toMd5()}.jpg";
      final tempDir = await getSafeLibraryDir();
      final filePath = "${tempDir.path}/preview_local_$fileName"; // 修复：移除末尾空格

      final file = File(filePath);
      if (await file.exists()) {
        return file;
      }

      final sourceFile = await entity.file;
      if (sourceFile != null) {
        await sourceFile.copy(file.path); // 修复：添加await
      }

      return file;
    } catch (e) {
      LogUtil.log("Error creating asset file: $e");
      return null;
    }
  }

  /// 创建本地缩略图文件
  Future<File?> createThumbnailLocalFile(
      String assetId, {
        int width = 200,
        int height = 200,
      }) async {
    try {
      final asset = mediaList
          .where((element) => element.id == assetId)
          .firstOrNull;

      if (asset == null) {
        return null;
      }

      final fileName = "${assetId.toMd5()}.jpg";
      final tempDir = await getSafeLibraryDir();
      final filePath = "${tempDir.path}/thumbnail_local_$fileName"; // 修复：移除末尾空格

      final file = File(filePath);
      if (await file.exists()) {
        return file;
      }

      final thumbData = await asset.thumbnailDataWithSize(
        ThumbnailSize(width, height),
        quality: 60,
      );

      if (thumbData == null) return null;

      await file.writeAsBytes(thumbData);
      return file;
    } catch (e) {
      LogUtil.log("Error creating thumbnail local file: $e");
      return null;
    }
  }

  /// 获取缩略图Image组件
  Future<Image?> getThumImage(String assetId) async {
    try {
      final asset = mediaList
          .where((element) => element.id == assetId)
          .firstOrNull;

      if (asset == null) {
        return null;
      }

      final thumbData = await asset.thumbnailDataWithSize(
        ThumbnailSize(300, 300),
        quality: 60,
      );

      if (thumbData == null) {
        return null;
      }

      return Image.memory(
        thumbData,
        fit: BoxFit.cover,
        width: 300,
        height: 300,
      );
    } catch (e) {
      LogUtil.log("Error getting thumbnail image: $e");
      return null;
    }
  }

  /// 根据ID获取Asset
  AssetEntity? getAssetById(String assetId) {
    return mediaList
        .where((element) => element.id == assetId)
        .firstOrNull;
  }

  /// 获取所有本地待上传照片
  Future<List<ResList>> getAllLocalPhotos() async {
    try {
      final userId = MyInstance().user?.user?.id ?? 0;
      if (userId == 0) {
        return [];
      }

      final currentDevice = MyInstance().deviceCode;
      if (currentDevice.isEmpty) {
        return [];
      }

      final mediaList = await getAllMedia();
      LogUtil.log("Total media found: ${mediaList.length}");

      final assetIds = mediaList.map((e) => e.id).toList();
      final filter = await dbHelper.queryStatusZeroByAssetIdList(
        "$userId",
        currentDevice,
        assetIds,
      );

      LogUtil.log("Total media filter found: ${filter.length}");

      final resList = filter.map((fileItem) => ResList(
        resId: null,
        thumbnailPath: null,
        mediumPath: null,
        originPath: "asset_${fileItem.assetId}",
        resType: null,
        fileType: null,
        fileName: null,
        createDate: DateTime.fromMillisecondsSinceEpoch(
            fileItem.createDate.toInt()
        ),
        updateDate: null,
        photoDate: null,
        fileSize: null,
        duration: null,
        width: null,
        height: null,
        shareUserId: null,
        shareUserName: null,
        shareUserHeadUrl: null,
        personLabels: null,
        deviceName: null,
        locate: null,
        scence: null,
        address: null,
        storeContent: null,
        isPrivate: null,
      )).toList();

      return resList;
    } catch (e, stackTrace) {
      LogUtil.log("Error getting local photos: $e\n$stackTrace");
      return [];
    }
  }

  /// 获取待上传的图片和视频数量
  Future<List<int>> getImageVideoUploadingCount() async {
    try {
      final userId = MyInstance().user?.user?.id ?? 0;
      final currentDevice = MyInstance().deviceCode;

      if (userId == 0 || currentDevice.isEmpty) {
        return [0, 0];
      }

      final list = await dbHelper.fetchFilesByUserAndDevice(
        "$userId",
        currentDevice,
      );

      final mediaList = list.where((item) => item.status == 0).toList();
      if (mediaList.isEmpty) {
        return [0, 0];
      }

      final imageCount = mediaList
          .where((item) => item.fileType == "P")
          .length;
      final videoCount = mediaList
          .where((item) => item.fileType == "V")
          .length;

      return [imageCount, videoCount];
    } catch (e) {
      LogUtil.log("Error getting upload count: $e");
      return [0, 0];
    }
  }

  /// 检查是否启用自动同步
  Future<bool> _isAutoSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('autoSync') ?? true;
    } catch (e) {
      LogUtil.log("Error checking auto sync: $e");
      return true;
    }
  }

  /// 获取城市名称（通过原生桥接）
  Future<String?> _getCityName(double lng, double lat) async {
    try {
      const platform = MethodChannel('album/native');
      final String? result = await platform.invokeMethod('getCity');
      return result;
    } catch (e) {
      LogUtil.log('Error getting location: $e');
      return null;
    }
  }

  /// 检查存储空间是否充足
  bool _hasEnoughStorage(double additionalSizeGB) {
    final used = (MyInstance().p6deviceInfoModel?.ttlUsed ?? 0) + additionalSizeGB;
    final max = (MyInstance().p6deviceInfoModel?.ttlAll ?? 0) - UploadConfig.reservedStorageGB;
    return used < max;
  }

  /// 上传所有待上传文件
  Future<void> uploadAll(Function completion) async {
    if (_isUploading) {
      LogUtil.log("Upload already in progress");
      return;
    }

    _isUploading = true;

    try {
      final userId = MyInstance().user?.user?.id ?? 0;
      final groupId = MyInstance().group?.groupId ?? 0;

      if (userId == 0) {
        LogUtil.log("Invalid user ID");
        completion();
        return;
      }

      final currentDevice = MyInstance().deviceCode;
      if (currentDevice.isEmpty) {
        LogUtil.log("Invalid device code");
        completion();
        return;
      }

      await dbHelper.updateFileStatusBeforeUploadAll("$userId", currentDevice);
      LogUtil.log("Starting uploadAll for user $userId on device $currentDevice");

      // 清理失败的任务
      await _cleanupFailedTasks(userId, groupId);

      // 获取待上传文件
      final list = await dbHelper.fetchFilesByUserAndDevice(
        "$userId",
        currentDevice,
      );

      final filter = list.where((item) => item.status == 0).toList();
      if (filter.isEmpty) {
        LogUtil.log("No media found to upload");
        completion();
        return;
      }

      // 分批处理
      final chunks = splitIntoChunks(filter, UploadConfig.imageChunkSize);
      int totalFiles = filter.length;
      int uploadedFiles = 0;
      int failedFiles = 0;

      _updateProgress(totalFiles, uploadedFiles, failedFiles);

      for (var chunk in chunks) {
        // 检查自动同步开关
        if (!await _isAutoSync()) {
          LogUtil.log("Auto sync is disabled, stopping uploadAll");
          break;
        }

        // 处理单个批次
        final result = await _processChunk(
          chunk,
          userId,
          groupId,
          currentDevice,
          totalFiles,
          uploadedFiles,
          failedFiles,
        );

        uploadedFiles = result['uploaded'] as int;
        failedFiles = result['failed'] as int;
      }

      LogUtil.log("Upload completed: $uploadedFiles uploaded, $failedFiles failed");
      completion();
    } catch (e, stackTrace) {
      LogUtil.log("Error in uploadAll: $e\n$stackTrace");
      completion();
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  /// 清理失败的上传任务
  Future<void> _cleanupFailedTasks(int userId, int groupId) async {
    try {
      final failedTaskList = await taskManager.listTasks(
        userId: userId,
        groupId: groupId,
        status: UploadTaskStatus.uploading,
      );

      for (var task in failedTaskList) {
        final taskId = task.taskId;
        try {
          final response = await provider.revokeSyncTask(taskId);
          if (response.isSuccess) {
            await taskManager.deleteTask(taskId);
            LogUtil.log("Revoked sync task successfully: $taskId");
          } else {
            LogUtil.log("Failed to revoke sync task: ${response.message}");
          }
        } catch (e) {
          LogUtil.log("Error revoking task $taskId: $e");
          await taskManager.deleteTask(taskId);
        }
      }
    } catch (e) {
      LogUtil.log("Error cleaning up failed tasks: $e");
    }
  }

  /// 处理单个上传批次
  Future<Map<String, int>> _processChunk(
      List<FileItem> chunk,
      int userId,
      int groupId,
      String currentDevice,
      int totalFiles,
      int uploadedFiles,
      int failedFiles,
      ) async {
    final uploadList = <FileUploadModel>[];
    final newChunk = <FileItem>[];

    // 检查存储空间
    final fileTotalSize = chunk
        .map((e) => e.fileSize)
        .fold<double>(0, (a, b) => a + b) / (1024 * 1024 * 1024);

    if (!_hasEnoughStorage(fileTotalSize)) {
      LogUtil.log("Storage is full, stopping uploadAll");
      return {'uploaded': uploadedFiles, 'failed': failedFiles};
    }

    // 准备上传列表
    for (var element in chunk) {
      try {
        final filterList = mediaList.where((e) => e.id == element.assetId);

        if (filterList.isEmpty) {
          LogUtil.log("Asset not found for id: ${element.assetId}");

          if (element.md5Hash.isNotEmpty) {
            await dbHelper.updateStatusByMd5Hash(element.md5Hash, 2);
          } else {
            await dbHelper.deleteFileByAssetId(element.assetId);
          }

          failedFiles++;
          continue;
        }

        final entity = filterList.first;
        final file = await entity.file;

        if (file == null) {
          LogUtil.log("File not found for asset: ${entity.id}");
          failedFiles++;
          continue;
        }

        final fileName = p.basename(file.path);
        final md5Hash = await getFileMd5(file);
        final fileType = entity.type == AssetType.image ? "P" : "V";
        final storageSpace = await getAssetFileSize(entity) ?? 0;

        final updateItem = FileItem(
          id: element.id,
          md5Hash: md5Hash,
          filePath: file.path,
          fileName: fileName,
          fileType: fileType,
          fileSize: storageSpace,
          assetId: entity.id,
          status: 0,
          userId: "$userId",
          deviceCode: currentDevice,
          duration: entity.duration,
          width: entity.width,
          height: entity.height,
          lng: entity.longitude ?? 0.0,
          lat: entity.latitude ?? 0.0,
          createDate: entity.createDateTime.millisecondsSinceEpoch.toDouble(),
        );

        await dbHelper.updateFile(updateItem);
        newChunk.add(updateItem);

        uploadList.add(FileUploadModel(
          fileCode: md5Hash,
          filePath: file.path,
          fileName: fileName,
          fileType: fileType,
          storageSpace: storageSpace,
        ));
      } catch (e) {
        LogUtil.log("Error preparing file: $e");
        failedFiles++;
      }
    }

    if (uploadList.isEmpty) {
      return {'uploaded': uploadedFiles, 'failed': failedFiles};
    }

    // 创建同步任务
    try {
      final response = await provider.createSyncTask(uploadList);

      if (!response.isSuccess) {
        LogUtil.log("Failed to create sync task: ${response.message}");
        return {'uploaded': uploadedFiles, 'failed': failedFiles + uploadList.length};
      }

      LogUtil.log("Chunk createSyncTask successfully");

      final uploadPath = removeFirstAndLastSlash(response.model?.uploadPath ?? "");
      final taskId = response.model?.taskId ?? 0;

      await taskManager.insertTask(
        taskId: taskId,
        userId: userId,
        groupId: groupId,
        status: UploadTaskStatus.uploading,
      );

      // 处理已存在的文件
      final failedFileList = response.model?.failedFileList ?? [];
      for (var failed in failedFileList) {
        if (failed.fileCode != null && failed.fileCode!.isNotEmpty) {
          if ((failed.failedReason ?? "").contains("exist")) {
            await dbHelper.updateStatusByMd5Hash(failed.fileCode!, 2);
            LogUtil.log("File already exists: ${failed.fileCode}");
          }
        }
      }

      // 过滤出需要上传的文件
      final newAssets = newChunk.where((media) {
        final md5 = media.md5Hash;
        return md5 != null &&
            !failedFileList.any((failed) => failed.fileCode == md5);
      }).toList();

      if (newAssets.isEmpty) {
        await provider.revokeSyncTask(taskId);
        await taskManager.deleteTask(taskId);
        LogUtil.log("No files to upload, task revoked");
        notifyListeners();
        return {'uploaded': uploadedFiles, 'failed': failedFiles};
      }

      // 执行上传
      final uploadResult = await _uploadFiles(
        newAssets,
        uploadPath,
        taskId,
        totalFiles,
        uploadedFiles,
        failedFiles,
      );

      return uploadResult;
    } catch (e, stackTrace) {
      LogUtil.log("Error processing chunk: $e\n$stackTrace");
      return {'uploaded': uploadedFiles, 'failed': failedFiles + uploadList.length};
    }
  }

  /// 上传文件列表
  Future<Map<String, int>> _uploadFiles(
      List<FileItem> files,
      String uploadPath,
      int taskId,
      int totalFiles,
      int uploadedFiles,
      int failedFiles,
      ) async {
    final uploadedFileCodes = <FileItem>[];
    final waitAllTaskFinishSignal = LocalSemaphore(1);
    final sm = LocalSemaphore(UploadConfig.maxConcurrentUploads);
    int taskCount = files.length;

    LogUtil.log("Files to be uploaded: ${files.length}");

    // 并发上传
    for (var entity in files) {
      await sm.acquire();

      LogUtil.log("[upload] begin Uploaded: ${entity.fileName}");
      _updateProgress(totalFiles, uploadedFiles, failedFiles, entity.fileName);

      // 异步上传
      _uploadWithRetry(entity, uploadPath, UploadConfig.maxRetryAttempts)
          .then((result) async {
        try {
          if (result) {
            LogUtil.log("[upload] Uploaded: ${entity.fileName}");
            uploadedFileCodes.add(entity);
            await dbHelper.updateStatusByMd5Hash(entity.md5Hash!, 1);
            uploadedFiles++;
          } else {
            LogUtil.log("[upload] Failed to upload: ${entity.fileName}");
            failedFiles++;
          }

          _updateProgress(totalFiles, uploadedFiles, failedFiles);
          notifyListeners();
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
    if (uploadedFileCodes.isNotEmpty) {
      await _reportUploadedFiles(uploadedFileCodes, uploadPath, taskId);

      // 使用 for-in 替代 forEach with async
      for (var entity in uploadedFileCodes) {
        await dbHelper.updateStatusByMd5Hash(entity.md5Hash!, 2);
      }
    } else {
      LogUtil.log("No files uploaded successfully");
      await provider.revokeSyncTask(taskId);
      await taskManager.deleteTask(taskId);
    }

    notifyListeners();
    return {'uploaded': uploadedFiles, 'failed': failedFiles};
  }

  /// 带重试机制的上传
  Future<bool> _uploadWithRetry(
      FileItem entity,
      String uploadPath,
      int maxRetries,
      ) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final success = await uploadMedia(entity, uploadPath);
        if (success) {
          return true;
        }

        if (attempt < maxRetries - 1) {
          LogUtil.log("Retry upload ${attempt + 1}/$maxRetries: ${entity.fileName}");
          await Future.delayed(Duration(seconds: UploadConfig.retryDelaySeconds));
        }
      } catch (e) {
        LogUtil.log("Upload attempt ${attempt + 1} failed: $e");
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: UploadConfig.retryDelaySeconds));
        }
      }
    }

    return false;
  }

  /// 报告已上传的文件
  Future<void> _reportUploadedFiles(
      List<FileItem> uploadedFiles,
      String uploadPath,
      int taskId,
      ) async {
    try {
      final fileDetailList = <FileDetailModel>[];

      for (var entity in uploadedFiles) {
        final code = entity.md5Hash!;
        final fileName = p.basename(entity.fileName!);
        final fileNameWithoutExt = p.basenameWithoutExtension(entity.fileName!);
        final fileExt = entity.fileName!.split('.').last;
        final imageFileName = "$fileNameWithoutExt.jpg";

        final dt = DateTime.fromMillisecondsSinceEpoch(entity.createDate.toInt());
        final photoDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);

        fileDetailList.add(FileDetailModel(
          fileCode: code,
          metaPath: "$uploadPath/$code/$fileName",
          middlePath: "$uploadPath/$code/show_$imageFileName",
          snailPath: "$uploadPath/$code/thumbnail_$imageFileName",
          fileName: fileName,
          fileType: entity.fileType,
          duration: entity.duration,
          width: entity.width,
          height: entity.height, // 修复：之前错误地使用了 width
          size: entity.fileSize,
          fmt: fileExt,
          photoDate: photoDate,
          latitude: entity.lat.toString(),
          longitude: entity.lng.toString(),
        ));
      }

      final response = await provider.reportSyncTaskFiles(taskId, fileDetailList);

      if (response.isSuccess) {
        await taskManager.updateStatus(taskId, UploadTaskStatus.success);
        LogUtil.log("Reported uploaded files successfully");
      } else {
        LogUtil.log("Failed to report uploaded files: ${response.message}");
      }
    } catch (e, stackTrace) {
      LogUtil.log("Error reporting uploaded files: $e\n$stackTrace");
    }
  }

  /// 创建图片缩略图
  static Future<Uint8List> createImageThumbnail(String path, int width) async {
    try {
      final bytes = await File(path).readAsBytes();
      final original = img.decodeImage(bytes);

      if (original == null) throw Exception("Invalid image");

      final thumbnail = img.copyResize(original, width: width);
      return Uint8List.fromList(img.encodeJpg(thumbnail));
    } catch (e) {
      LogUtil.log("Error creating image thumbnail: $e");
      rethrow;
    }
  }

  /// 创建视频缩略图
  static Future<Uint8List?> createVideoThumbnail(
      String videoPath,
      int width,
      ) async {
    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: width,
        quality: 60,
      );
      return uint8list;
    } catch (e) {
      LogUtil.log("Error creating video thumbnail: $e");
      return null;
    }
  }

  /// 压缩JPG文件
  static Future<List<int>?> compressJpgFile(String filePath) async {
    try {
      return await FlutterImageCompress.compressWithFile(
        filePath,
        quality: UploadConfig.thumbnailQuality,
        format: CompressFormat.jpeg,
      );
    } catch (e) {
      LogUtil.log("Error compressing JPG file: $e");
      return null;
    }
  }

  /// 压缩JPG字节数据
  static Future<List<int>?> compressJpgAsset(Uint8List bytes) async {
    try {
      return await FlutterImageCompress.compressWithList(
        bytes,
        quality: UploadConfig.thumbnailQuality,
        format: CompressFormat.jpeg,
      );
    } catch (e) {
      LogUtil.log("Error compressing JPG asset: $e");
      return null;
    }
  }

  /// 创建缩略图文件
  static Future<File?> createThumbnailFile(
      AssetEntity asset,
      String fileName, {
        int width = UploadConfig.thumbnailWidth,
        int height = UploadConfig.thumbnailHeight,
      }) async {
    try {
      final assetFile = await asset.file;
      if (assetFile == null) return null;

      final tempDir = await getTemporaryDirectory();
      final filePath = "${tempDir.path}/thumbnail_$fileName"; // 修复：移除末尾空格

      final thumbData = await asset.thumbnailDataWithSize(
        ThumbnailSize(width, height),
        quality: UploadConfig.thumbnailQuality,
      );

      if (thumbData == null) return null;

      final compressedData = await compressJpgAsset(thumbData);
      if (compressedData == null) return null;

      debugPrint(
          "Thumbnail size: ${thumbData.length} bytes -> ${compressedData.length} bytes"
      );

      final file = File(filePath);
      await file.writeAsBytes(compressedData);

      return file;
    } catch (e) {
      LogUtil.log("Error creating thumbnail file: $e");
      return null;
    }
  }

  /// 创建中等尺寸文件
  static Future<File?> createMediumFile(
      AssetEntity asset,
      String fileName, {
        int width = UploadConfig.mediumWidth,
        int height = UploadConfig.mediumHeight,
      }) async {
    try {
      final thumbData = await asset.thumbnailDataWithSize(
        ThumbnailSize(width, height),
        quality: UploadConfig.mediumQuality,
      );

      if (thumbData == null) return null;

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/show_$fileName';

      final file = File(filePath);
      await file.writeAsBytes(thumbData);

      return file;
    } catch (e) {
      LogUtil.log("Error creating medium file: $e");
      return null;
    }
  }

  /// 上传单个媒体文件（包含原始文件、缩略图和中等尺寸）
  Future<bool> uploadMedia(FileItem entity, String uploadPath) async {
    try {
      final md5Hash = entity.md5Hash;
      final fileName = entity.fileName;
      final fileNameWithoutExt = p.basenameWithoutExtension(fileName);
      final imageFileName = "$fileNameWithoutExt.jpg";

      // 修复：正确解析bucket和路径
      final pathParts = uploadPath.split('/');
      if (pathParts.isEmpty) {
        LogUtil.log("Invalid upload path: $uploadPath");
        return false;
      }

      final bucketName = pathParts.first;
      final uploadPathWithoutBucket = pathParts.skip(1).join('/');

      // 获取Asset
      final filterAsset = mediaList.where((element) => element.id == entity.assetId);
      if (filterAsset.isEmpty) {
        LogUtil.log("Asset not found for id: ${entity.assetId}");
        return false;
      }

      final asset = filterAsset.first;

      LogUtil.log("Getting asset file: ${entity.filePath}");
      final file = await asset.file;
      if (file == null) {
        LogUtil.log("Failed to get file from asset");
        return false;
      }

      // 1. 上传原始文件
      LogUtil.log("Uploading original file: ${entity.filePath}");
      // var success = await NativeBridge.minio_upload(
      //   file.path,
      //   bucketName,
      //   "$uploadPathWithoutBucket/$md5Hash/$fileName",
      // );

      var result = await minioService.uploadFile(
        bucketName,
        "$uploadPathWithoutBucket/$md5Hash/$fileName",
        file.path,
      );

      if (!result.success) {
        LogUtil.log("Failed to upload original file: ${entity.filePath}");
        return false;
      }
      LogUtil.log("Original file uploaded: ${entity.filePath}");

      // 2. 上传缩略图
      final thumbnailFile = await createThumbnailFile(asset, imageFileName);
      if (thumbnailFile == null) {
        LogUtil.log("Failed to create thumbnail for ${entity.fileName}");
        return false;
      }

      // success = await NativeBridge.minio_upload(
      //   thumbnailFile.path,
      //   bucketName,
      //   "$uploadPathWithoutBucket/$md5Hash/thumbnail_$imageFileName",
      // );

      result = await minioService.uploadFile(
        bucketName,
        "$uploadPathWithoutBucket/$md5Hash/thumbnail_$imageFileName",
        file.path,
      );

      if (!result.success) {
        LogUtil.log("Failed to upload thumbnail: ${thumbnailFile.path}");
        await _cleanupFile(thumbnailFile);
        return false;
      }
      LogUtil.log("Thumbnail uploaded: ${thumbnailFile.path}");

      // 3. 上传中等尺寸
      final mediumFile = await createMediumFile(asset, imageFileName);
      if (mediumFile == null) {
        LogUtil.log("Failed to create medium file for ${entity.fileName}");
        await _cleanupFile(thumbnailFile);
        return false;
      }

      // success = await NativeBridge.minio_upload(
      //   mediumFile.path,
      //   bucketName,
      //   "$uploadPathWithoutBucket/$md5Hash/show_$imageFileName",
      // );

      result = await minioService.uploadFile(
        bucketName,
        "$uploadPathWithoutBucket/$md5Hash/show_$imageFileName",
        file.path,
      );

      if (!result.success) {
        LogUtil.log("Failed to upload medium file: ${mediumFile.path}");
        await _cleanupFile(thumbnailFile);
        await _cleanupFile(mediumFile);
        return false;
      }
      LogUtil.log("Medium file uploaded: ${mediumFile.path}");

      // 4. 清理临时文件
      await _cleanupFile(thumbnailFile);
      await _cleanupFile(mediumFile);

      return true;
    } catch (e, stackTrace) {
      LogUtil.log("Error uploading media: $e\n$stackTrace");
      return false;
    }
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