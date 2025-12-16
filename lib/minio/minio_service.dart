// services/minio_service.dart
// Minio 对象存储服务（改进版 - 支持实时上传进度）

import 'dart:io';
import 'dart:typed_data';
import 'package:minio/io.dart';
import 'package:minio/minio.dart';
import 'minio_config.dart';

/// 上传进度回调类型
/// [sent] 已发送字节数
/// [total] 总字节数
typedef UploadProgressCallback = void Function(int sent, int total);

class MinioService {
  static MinioService? _instance;
  late Minio _minio;

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

  /// ============================================================
  /// ✅ 新增：带进度回调的文件上传方法
  /// ============================================================
  /// [bucketName] 存储桶名称
  /// [objectName] 对象名称（存储在 Minio 中的文件名）
  /// [filePath] 本地文件路径
  /// [onProgress] 进度回调，实时报告已上传字节数
  Future<UploadResult> uploadFileWithProgress(
      String bucketName,
      String objectName,
      String filePath, {
        UploadProgressCallback? onProgress,
      }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return UploadResult(
          success: false,
          message: '文件不存在: $filePath',
        );
      }

      // 确保存储桶存在
      await createBucket(bucketName);

      // 获取文件大小
      final fileSize = await file.length();

      // ✅ 创建带进度追踪的 Stream（转换为 Uint8List）
      int uploadedBytes = 0;
      final fileStream = file.openRead().map((chunk) {
        uploadedBytes += chunk.length;
        // 调用进度回调
        onProgress?.call(uploadedBytes, fileSize);
        // 转换为 Uint8List 以满足 minio 包的类型要求
        return Uint8List.fromList(chunk);
      });

      // 使用 putObject 上传（支持 Stream）
      await _minio.putObject(
        bucketName,
        objectName,
        fileStream,
        size: fileSize,
      );

      final url = MinioConfig.getFileUrl(bucketName, objectName);

      return UploadResult(
        success: true,
        message: '上传成功',
        url: url,
        objectName: objectName,
        size: fileSize,
      );
    } catch (e) {
      print('上传文件失败: $e');
      return UploadResult(
        success: false,
        message: '上传失败: ${e.toString()}',
      );
    }
  }

  /// 上传文件（从文件路径）- 原方法保持兼容
  /// [bucketName] 存储桶名称
  /// [objectName] 对象名称（存储在 Minio 中的文件名）
  /// [filePath] 本地文件路径
  Future<UploadResult> uploadFile(
      String bucketName,
      String objectName,
      String filePath,
      ) async {
    // ✅ 内部调用带进度的版本，但不传回调
    return uploadFileWithProgress(bucketName, objectName, filePath);
  }

  /// ============================================================
  /// ✅ 新增：带进度回调的字节数据上传方法
  /// ============================================================
  Future<UploadResult> uploadBytesWithProgress(
      String bucketName,
      String objectName,
      Uint8List data, {
        String? contentType,
        UploadProgressCallback? onProgress,
      }) async {
    try {
      // 确保存储桶存在
      await createBucket(bucketName);

      final totalSize = data.length;

      // 准备 metadata（如果有 contentType）
      final metadata = contentType != null
          ? {'Content-Type': contentType}
          : null;

      // ✅ 创建带进度追踪的 Stream
      // 将数据分块发送以支持进度回调
      const chunkSize = 64 * 1024; // 64KB 分块
      int uploadedBytes = 0;

      Stream<Uint8List> createProgressStream() async* {
        for (int i = 0; i < data.length; i += chunkSize) {
          final end = (i + chunkSize > data.length) ? data.length : i + chunkSize;
          final chunk = data.sublist(i, end);
          uploadedBytes += chunk.length;
          onProgress?.call(uploadedBytes, totalSize);
          yield Uint8List.fromList(chunk);
        }
      }

      // 上传字节数据
      await _minio.putObject(
        bucketName,
        objectName,
        createProgressStream(),
        size: totalSize,
        metadata: metadata,
      );

      final url = MinioConfig.getFileUrl(bucketName, objectName);

      return UploadResult(
        success: true,
        message: '上传成功',
        url: url,
        objectName: objectName,
        size: totalSize,
      );
    } catch (e) {
      print('上传文件失败: $e');
      return UploadResult(
        success: false,
        message: '上传失败: ${e.toString()}',
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
}

// 上传结果类
class UploadResult {
  final bool success;
  final String message;
  final String? url;
  final String? objectName;
  final int? size;

  UploadResult({
    required this.success,
    required this.message,
    this.url,
    this.objectName,
    this.size,
  });
}

// 下载结果类
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

// Minio 对象信息
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

// 对象统计信息
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