// services/minio_service.dart
// Minio 对象存储服务（改进版 - 支持实时上传进度、取消上传、大文件优化）

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:minio/io.dart';
import 'package:minio/minio.dart';
import '../album/database/upload_task_db_helper.dart';
import 'minio_config.dart';

/// 上传进度回调类型
/// [sent] 已发送字节数
/// [total] 总字节数
typedef UploadProgressCallback = void Function(int sent, int total);

/// ============================================================
/// 取消令牌
/// ============================================================
class CancelToken {
  bool _isCancelled = false;
  String? _reason;

  bool get isCancelled => _isCancelled;
  String? get reason => _reason;

  void cancel([String? reason]) {
    _isCancelled = true;
    _reason = reason ?? '用户取消';
  }

  void reset() {
    _isCancelled = false;
    _reason = null;
  }
}

/// 上传取消异常
class UploadCancelledException implements Exception {
  final String message;
  UploadCancelledException([String? message]) : message = message ?? '上传已取消';

  @override
  String toString() => 'UploadCancelledException: $message';
}

/// ============================================================
/// 上传任务管理
/// ============================================================

class UploadTask {
  final String taskId;
  final String bucket;
  final String objectName;
  final String filePath;
  final CancelToken cancelToken;
  final DateTime startTime;

  int uploadedBytes = 0;
  int totalBytes = 0;
  UploadTaskStatus status = UploadTaskStatus.pending;

  UploadTask({
    required this.taskId,
    required this.bucket,
    required this.objectName,
    required this.filePath,
    required this.cancelToken,
  }) : startTime = DateTime.now();

  double get progress => totalBytes > 0 ? uploadedBytes / totalBytes : 0;
}

/// ============================================================
/// 未完成上传信息
/// ============================================================
class IncompleteUploadInfo {
  final String bucket;
  final String objectName;
  final String uploadId;
  final DateTime? initiated;
  final int size;

  IncompleteUploadInfo({
    required this.bucket,
    required this.objectName,
    required this.uploadId,
    this.initiated,
    required this.size,
  });

  String get readableSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(2)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  String toString() => 'IncompleteUpload(object: $objectName, size: $readableSize, initiated: $initiated)';
}

/// ============================================================
/// MinioService 主类
/// ============================================================
class MinioService {
  static MinioService? _instance;
  late Minio _minio;

  // ✅ 上传任务管理
  final Map<String, UploadTask> _uploadTasks = {};
  final Map<String, CancelToken> _cancelTokens = {};

  // ============================================================
  // 大文件上传配置
  // ============================================================

  /// 分片大小：5MB（minio包最小分片要求）
  static const int chunkSize = 5 * 1024 * 1024;

  /// 单次读取缓冲区大小：64KB（控制内存使用）
  static const int readBufferSize = 64 * 1024;

  /// 进度回调节流间隔（毫秒）
  static const int progressThrottleMs = 100;

  // 单例模式
  static MinioService get instance {
    _instance ??= MinioService._internal();
    return _instance!;
  }

  MinioService._internal() {
    _initMinio();
  }

  // 初始化 Minio 客户端
  void _initMinio() {
    _minio = Minio(
      endPoint: MinioConfig.host,
      port: MinioConfig.port,
      accessKey: MinioConfig.accessKey,
      secretKey: MinioConfig.secretKey,
      useSSL: MinioConfig.useSSL,
    );

    print('Minio initialized: ${MinioConfig.host}:${MinioConfig.port}');
  }

  void reInitializeMinio(String host) {
    _minio = Minio(
      endPoint: host,
      port: MinioConfig.port,
      accessKey: MinioConfig.accessKey,
      secretKey: MinioConfig.secretKey,
      useSSL: MinioConfig.useSSL,
    );

    print('Minio initialized manually: $host:${MinioConfig.port}');
  }

  // ============================================================
  // ✅ 上传任务管理 API
  // ============================================================

  /// 获取所有上传任务
  List<UploadTask> get allUploadTasks => _uploadTasks.values.toList();

  /// 获取正在进行的上传任务
  List<UploadTask> get activeUploadTasks => _uploadTasks.values
      .where((task) => task.status == UploadTaskStatus.uploading)
      .toList();

  /// 获取指定任务
  UploadTask? getTask(String taskId) => _uploadTasks[taskId];

  /// 生成唯一任务ID
  String generateTaskId() => 'upload_${DateTime.now().millisecondsSinceEpoch}_${_uploadTasks.length}';

  /// 清理已完成/已取消/失败的任务记录
  void clearCompletedTasks() {
    _uploadTasks.removeWhere((_, task) =>
    task.status == UploadTaskStatus.success ||
        task.status == UploadTaskStatus.canceled ||
        task.status == UploadTaskStatus.failed);
    _cancelTokens.removeWhere((id, _) => !_uploadTasks.containsKey(id));
  }

  // ============================================================
  // ✅ 取消上传 API
  // ============================================================

  /// 取消指定上传任务
  /// [taskId] 任务ID
  /// [cleanupServer] 是否清理服务器上的未完成分片，默认true
  Future<bool> cancelUpload(String taskId, {bool cleanupServer = true}) async {
    final token = _cancelTokens[taskId];
    final task = _uploadTasks[taskId];

    if (token == null || task == null) {
      print('[MinioService] 任务不存在: $taskId');
      return false;
    }

    // 标记取消
    token.cancel('用户取消上传');
    task.status = UploadTaskStatus.canceled;

    print('[MinioService] 已取消任务: $taskId');

    // 清理服务器上的未完成分片
    if (cleanupServer) {
      try {
        await removeIncompleteUpload(task.bucket, task.objectName);
        print('[MinioService] 已清理服务器未完成分片: ${task.objectName}');
      } catch (e) {
        print('[MinioService] 清理未完成分片失败: $e');
      }
    }

    return true;
  }

  /// 取消所有上传任务
  Future<int> cancelAllUploads({bool cleanupServer = true}) async {
    int cancelledCount = 0;
    final taskIds = _cancelTokens.keys.toList();

    for (final taskId in taskIds) {
      if (await cancelUpload(taskId, cleanupServer: cleanupServer)) {
        cancelledCount++;
      }
    }

    print('[MinioService] 已取消 $cancelledCount 个上传任务');
    return cancelledCount;
  }

  /// 取消指定 bucket 下的所有上传任务
  Future<int> cancelBucketUploads(String bucket, {bool cleanupServer = true}) async {
    int cancelledCount = 0;
    final tasksToCancel = _uploadTasks.entries
        .where((e) => e.value.bucket == bucket && e.value.status == UploadTaskStatus.uploading)
        .map((e) => e.key)
        .toList();

    for (final taskId in tasksToCancel) {
      if (await cancelUpload(taskId, cleanupServer: cleanupServer)) {
        cancelledCount++;
      }
    }

    return cancelledCount;
  }

  // ============================================================
  // ✅ 未完成分片上传管理 API
  // ============================================================

  /// 移除指定对象的未完成分片上传
  Future<void> removeIncompleteUpload(String bucket, String object) async {
    try {
      await _minio.removeIncompleteUpload(bucket, object);
      print('[MinioService] 已移除未完成上传: $bucket/$object');
    } catch (e) {
      print('[MinioService] 移除未完成上传失败: $e');
    }
  }

  /// 列出 bucket 中所有未完成的上传
  Stream<IncompleteUploadInfo> listIncompleteUploads(
      String bucket, {
        String prefix = '',
        bool recursive = false,
      }) async* {
    try {
      await for (final upload in _minio.listIncompleteUploads(bucket, prefix, recursive)) {
        yield IncompleteUploadInfo(
          bucket: bucket,
          objectName: upload.upload?.key ?? '',
          uploadId: upload.upload?.uploadId ?? '',
          initiated: upload.upload?.initiated,
          size: upload.size ?? 0,
        );
      }
    } catch (e) {
      print('[MinioService] 列出未完成上传失败: $e');
    }
  }

  /// 清理 bucket 中所有未完成的上传
  /// [prefix] 对象名前缀过滤
  /// [olderThan] 只清理早于指定时间的上传
  Future<int> cleanupIncompleteUploads(
      String bucket, {
        String prefix = '',
        Duration? olderThan,
      }) async {
    int cleanedCount = 0;
    final now = DateTime.now();

    try {
      await for (final upload in listIncompleteUploads(bucket, prefix: prefix, recursive: true)) {
        // 检查时间过滤
        if (olderThan != null && upload.initiated != null) {
          final age = now.difference(upload.initiated!);
          if (age < olderThan) {
            continue; // 跳过较新的上传
          }
        }

        try {
          await removeIncompleteUpload(bucket, upload.objectName);
          cleanedCount++;
          print('[MinioService] 已清理: ${upload.objectName}');
        } catch (e) {
          print('[MinioService] 清理失败: ${upload.objectName}, 错误: $e');
        }
      }
    } catch (e) {
      print('[MinioService] 清理未完成上传出错: $e');
    }

    print('[MinioService] 共清理 $cleanedCount 个未完成上传');
    return cleanedCount;
  }

  // ============================================================
  // 存储桶操作
  // ============================================================

  /// 创建存储桶
  Future<bool> createBucket(String bucketName) async {
    try {
      final exists = await _minio.bucketExists(bucketName);
      if (!exists) {
        await _minio.makeBucket(bucketName);
        print('存储桶创建成功: $bucketName');
        return true;
      }
      print('存储桶已存在: $bucketName');
      return true;
    } catch (e) {
      print('创建存储桶失败: $e');
      return false;
    }
  }

  /// 检查存储桶是否存在
  Future<bool> bucketExists(String bucketName) async {
    try {
      return await _minio.bucketExists(bucketName);
    } catch (e) {
      print('检查存储桶失败: $e');
      return false;
    }
  }

  // ============================================================
  // ✅ 核心改进：带进度回调的文件上传（使用 minio 原生进度回调）
  // ============================================================

  /// 带进度回调的文件上传方法
  /// [bucketName] 存储桶名称
  /// [objectName] 对象名称（存储在 Minio 中的文件名）
  /// [filePath] 本地文件路径
  /// [onProgress] 进度回调，实时报告已上传字节数
  /// [taskId] 任务ID（可选，用于取消上传）
  /// [cancelToken] 取消令牌（可选）
  Future<UploadResult> uploadFileWithProgress(
      String bucketName,
      String objectName,
      String filePath, {
        UploadProgressCallback? onProgress,
        String? taskId,
        CancelToken? cancelToken,
      }) async {
    // 生成或使用传入的任务ID和取消令牌
    final effectiveTaskId = taskId ?? generateTaskId();
    final effectiveCancelToken = cancelToken ?? CancelToken();

    // 创建任务记录
    final task = UploadTask(
      taskId: effectiveTaskId,
      bucket: bucketName,
      objectName: objectName,
      filePath: filePath,
      cancelToken: effectiveCancelToken,
    );

    _uploadTasks[effectiveTaskId] = task;
    _cancelTokens[effectiveTaskId] = effectiveCancelToken;

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        task.status = UploadTaskStatus.failed;
        return UploadResult(
          success: false,
          message: '文件不存在: $filePath',
          taskId: effectiveTaskId,
        );
      }

      // 确保存储桶存在
      await createBucket(bucketName);

      // 获取文件大小
      final fileSize = await file.length();
      task.totalBytes = fileSize;
      task.status = UploadTaskStatus.uploading;

      debugPrint('[MinioService] 开始上传: $objectName, 大小: ${_formatSize(fileSize)}');

      // ✅ 创建可取消的文件流
      final fileStream = _createCancellableFileStream(
        file: file,
        cancelToken: effectiveCancelToken,
      );

      // ✅ 进度回调节流控制
      int lastProgressTime = 0;

      // ✅ 使用 minio 原生的 onProgress 回调（这是真实的上传进度！）
      await _minio.putObject(
        bucketName,
        objectName,
        fileStream,
        size: fileSize,
        chunkSize: chunkSize,
        onProgress: (uploadedBytes) {
          // 检查是否取消
          if (effectiveCancelToken.isCancelled) {
            throw UploadCancelledException(effectiveCancelToken.reason);
          }

          task.uploadedBytes = uploadedBytes;

          // ✅ 节流：限制进度回调频率
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastProgressTime >= progressThrottleMs || uploadedBytes >= fileSize) {
            onProgress?.call(uploadedBytes, fileSize);
            lastProgressTime = now;
          }
        },
      );

      // 标记完成
      task.status = UploadTaskStatus.success;
      final url = MinioConfig.getFileUrl(bucketName, objectName);

      print('[MinioService] 上传完成: $objectName');

      return UploadResult(
        success: true,
        message: '上传成功',
        url: url,
        objectName: objectName,
        size: fileSize,
        taskId: effectiveTaskId,
      );

    } on UploadCancelledException catch (e) {
      // 上传被取消
      task.status = UploadTaskStatus.canceled;
      print('[MinioService] 上传已取消: ${e.message}');

      // 清理服务器上的未完成分片
      try {
        await removeIncompleteUpload(bucketName, objectName);
      } catch (_) {}

      return UploadResult(
        success: false,
        message: e.message,
        taskId: effectiveTaskId,
        isCancelled: true,
      );

    } catch (e, stackTrace) {
      // 其他错误
      task.status = UploadTaskStatus.failed;
      print('[MinioService] 上传失败: $e');
      print('[MinioService] Stack trace: $stackTrace');

      return UploadResult(
        success: false,
        message: '上传失败: ${e.toString()}',
        taskId: effectiveTaskId,
      );
    }
  }

  /// ✅ 创建可取消的文件流（简化版，不做进度追踪）
  Stream<Uint8List> _createCancellableFileStream({
    required File file,
    required CancelToken cancelToken,
  }) {
    final controller = StreamController<Uint8List>();

    () async {
      RandomAccessFile? raf;
      try {
        raf = await file.open(mode: FileMode.read);
        final buffer = Uint8List(readBufferSize);

        while (true) {
          // 检查取消
          if (cancelToken.isCancelled) {
            controller.addError(UploadCancelledException(cancelToken.reason));
            break;
          }

          // 读取数据
          final bytesRead = await raf.readInto(buffer);
          if (bytesRead == 0) break;

          // 发送数据
          final chunk = bytesRead == buffer.length
              ? Uint8List.fromList(buffer)
              : Uint8List.fromList(buffer.sublist(0, bytesRead));

          controller.add(chunk);

          // 让出事件循环执行权
          await Future.delayed(Duration.zero);
        }

        await controller.close();

      } catch (e) {
        controller.addError(e);
        await controller.close();
      } finally {
        await raf?.close();
    }
    }();

    return controller.stream;
  }

  /// 上传文件（从文件路径）- 原方法保持兼容
  Future<UploadResult> uploadFile(
      String bucketName,
      String objectName,
      String filePath,
      ) async {
    return uploadFileWithProgress(bucketName, objectName, filePath);
  }

  // ============================================================
  // ✅ 带进度回调的字节数据上传方法
  // ============================================================
  Future<UploadResult> uploadBytesWithProgress(
      String bucketName,
      String objectName,
      Uint8List data, {
        String? contentType,
        UploadProgressCallback? onProgress,
        String? taskId,
        CancelToken? cancelToken,
      }) async {
    final effectiveTaskId = taskId ?? generateTaskId();
    final effectiveCancelToken = cancelToken ?? CancelToken();

    final task = UploadTask(
      taskId: effectiveTaskId,
      bucket: bucketName,
      objectName: objectName,
      filePath: '',
      cancelToken: effectiveCancelToken,
    );

    _uploadTasks[effectiveTaskId] = task;
    _cancelTokens[effectiveTaskId] = effectiveCancelToken;

    try {
      // 确保存储桶存在
      await createBucket(bucketName);

      final totalSize = data.length;
      task.totalBytes = totalSize;
      task.status = UploadTaskStatus.uploading;

      // 准备 metadata
      final metadata = contentType != null ? {'Content-Type': contentType} : null;

      // ✅ 创建可取消的数据流
      Stream<Uint8List> createCancellableStream() async* {
        for (int i = 0; i < data.length; i += readBufferSize) {
          // 检查取消
          if (effectiveCancelToken.isCancelled) {
            throw UploadCancelledException(effectiveCancelToken.reason);
          }

          final end = (i + readBufferSize > data.length) ? data.length : i + readBufferSize;
          yield Uint8List.fromList(data.sublist(i, end));

          // 让出事件循环执行权
          await Future.delayed(Duration.zero);
        }
      }

      // ✅ 进度回调节流控制
      int lastProgressTime = 0;

      // ✅ 使用 minio 原生的 onProgress 回调
      await _minio.putObject(
        bucketName,
        objectName,
        createCancellableStream(),
        size: totalSize,
        metadata: metadata,
        chunkSize: chunkSize,
        onProgress: (uploadedBytes) {
          // 检查是否取消
          if (effectiveCancelToken.isCancelled) {
            throw UploadCancelledException(effectiveCancelToken.reason);
          }

          task.uploadedBytes = uploadedBytes;

          // 节流进度回调
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastProgressTime >= progressThrottleMs || uploadedBytes >= totalSize) {
            onProgress?.call(uploadedBytes, totalSize);
            lastProgressTime = now;
          }
        },
      );

      task.status = UploadTaskStatus.success;
      final url = MinioConfig.getFileUrl(bucketName, objectName);

      return UploadResult(
        success: true,
        message: '上传成功',
        url: url,
        objectName: objectName,
        size: totalSize,
        taskId: effectiveTaskId,
      );

    } on UploadCancelledException catch (e) {
      task.status = UploadTaskStatus.canceled;

      try {
        await removeIncompleteUpload(bucketName, objectName);
      } catch (_) {}

      return UploadResult(
        success: false,
        message: e.message,
        taskId: effectiveTaskId,
        isCancelled: true,
      );

    } catch (e) {
      task.status = UploadTaskStatus.failed;

      return UploadResult(
        success: false,
        message: '上传失败: ${e.toString()}',
        taskId: effectiveTaskId,
      );
    }
  }

  /// 上传文件（从字节数据）- 原方法保持兼容
  Future<UploadResult> uploadBytes(
      String bucketName,
      String objectName,
      Uint8List data, {
        String? contentType,
      }) async {
    return uploadBytesWithProgress(
      bucketName,
      objectName,
      data,
      contentType: contentType,
    );
  }

  // ============================================================
  // 下载方法
  // ============================================================

  /// 下载文件
  Future<DownloadResult> downloadFile(
      String bucketName,
      String objectName,
      String savePath,
      ) async {
    try {
      await _minio.fGetObject(bucketName, objectName, savePath);

      final file = File(savePath);
      final size = await file.length();

      return DownloadResult(
        success: true,
        message: '下载成功',
        filePath: savePath,
        size: size,
      );
    } catch (e) {
      print('下载文件失败: $e');
      return DownloadResult(
        success: false,
        message: '下载失败: ${e.toString()}',
      );
    }
  }

  /// 获取文件字节数据
  Future<Uint8List?> getFileBytes(
      String bucketName,
      String objectName,
      ) async {
    try {
      final stream = await _minio.getObject(bucketName, objectName);
      final bytes = await stream.toList();
      return Uint8List.fromList(bytes.expand((x) => x).toList());
    } catch (e) {
      print('获取文件数据失败: $e');
      return null;
    }
  }

  // ============================================================
  // 删除方法
  // ============================================================

  /// 删除文件
  Future<bool> deleteFile(String bucketName, String objectName) async {
    try {
      await _minio.removeObject(bucketName, objectName);
      print('文件删除成功: $objectName');
      return true;
    } catch (e) {
      print('删除文件失败: $e');
      return false;
    }
  }

  /// 批量删除文件
  Future<int> deleteFiles(String bucketName, List<String> objectNames) async {
    int successCount = 0;
    for (final objectName in objectNames) {
      if (await deleteFile(bucketName, objectName)) {
        successCount++;
      }
    }
    return successCount;
  }

  // ============================================================
  // 其他方法
  // ============================================================

  /// 获取文件的预签名 URL（用于临时访问）
  Future<String?> getPresignedUrl(
      String bucketName,
      String objectName, {
        int expires = 604800, // 7天
      }) async {
    try {
      final url = await _minio.presignedGetObject(
        bucketName,
        objectName,
        expires: expires,
      );
      return url;
    } catch (e) {
      print('获取预签名URL失败: $e');
      return null;
    }
  }

  /// 复制对象
  Future<bool> copyObject(
      String sourceBucket,
      String sourceObject,
      String destBucket,
      String destObject,
      ) async {
    try {
      await _minio.copyObject(
        destBucket,
        destObject,
        '$sourceBucket/$sourceObject',
      );
      print('对象复制成功');
      return true;
    } catch (e) {
      print('复制对象失败: $e');
      return false;
    }
  }

  // ============================================================
  // 工具方法
  // ============================================================

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

// ============================================================
// 数据模型
// ============================================================

/// 上传结果类
class UploadResult {
  final bool success;
  final String message;
  final String? url;
  final String? objectName;
  final int? size;
  final String? taskId;
  final bool isCancelled;

  UploadResult({
    required this.success,
    required this.message,
    this.url,
    this.objectName,
    this.size,
    this.taskId,
    this.isCancelled = false,
  });

  @override
  String toString() {
    return 'UploadResult(success: $success, message: $message, taskId: $taskId, isCancelled: $isCancelled)';
  }
}

/// 下载结果类
class DownloadResult {
  final bool success;
  final String message;
  final String? filePath;
  final int? size;

  DownloadResult({
    required this.success,
    required this.message,
    this.filePath,
    this.size,
  });
}

/// Minio 对象信息
class MinioObject {
  final String key;
  final int size;
  final DateTime? lastModified;

  MinioObject({
    required this.key,
    required this.size,
    this.lastModified,
  });

  // 获取文件大小的可读格式
  String get readableSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(2)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// 对象统计信息
class ObjectStat {
  final int size;
  final String? contentType;
  final DateTime? lastModified;
  final String? etag;

  ObjectStat({
    required this.size,
    this.contentType,
    this.lastModified,
    this.etag,
  });
}