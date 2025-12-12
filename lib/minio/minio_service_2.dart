// services/minio_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:minio/io.dart';
import 'package:minio/minio.dart';
import 'minio_config.dart';

class MinioServiceHelper {
  static MinioServiceHelper? _instance;
  // 将 _minio 声明为可空，以支持延迟初始化
  Minio? _minio;
  // 添加一个字段来保存当前的配置，可选
  MinioConfig? _currentConfig;

  // 单例模式 (修改: 移除构造函数中的自动初始化)
  static MinioServiceHelper get instance {
    _instance ??= MinioServiceHelper._internal();
    return _instance!;
  }

  // 私有构造函数，现在它不执行任何操作
  MinioServiceHelper._internal();

  /// 【新增】手动初始化 Minio 客户端
  /// 传入 MinioConfig 对象来配置客户端。
  /// 此方法必须在任何 Minio 操作之前调用。
  void initializeMinio(MinioConfig config) {
    _currentConfig = config;
    _minio = Minio(
      endPoint: MinioConfig.host,
      port: MinioConfig.port,
      accessKey: MinioConfig.accessKey,
      secretKey: MinioConfig.secretKey,
      useSSL: MinioConfig.useSSL,
    );

    print('Minio initialized manually: ${MinioConfig.host}:${MinioConfig.port}');
  }

  /// 【修改】获取 Minio 实例，确保它已被初始化
  Minio get _minioClient {
    if (_minio == null) {
      throw StateError(
          'MinioService must be initialized before use. Call MinioService.instance.initializeMinio() first.');
    }
    return _minio!;
  }

  /// 【修改】创建存储桶
  Future<bool> createBucket(String bucketName) async {
    try {
      // 使用 _minioClient 代替 _minio
      final exists = await _minioClient.bucketExists(bucketName);
      if (!exists) {
        await _minioClient.makeBucket(bucketName);
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
      return await _minioClient.bucketExists(bucketName);
    } catch (e) {
      print('检查存储桶失败: $e');
      return false;
    }
  }

  /// 上传文件（从文件路径）
  /// [bucketName] 存储桶名称
  /// [objectName] 对象名称（存储在 Minio 中的文件名）
  /// [filePath] 本地文件路径
  Future<UploadResult> uploadFile(
      String bucketName,
      String objectName,
      String filePath,
      ) async {
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

      // 上传文件
      await _minioClient.fPutObject(bucketName, objectName, filePath);

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

  /// 上传文件（从字节数据）
  /// [bucketName] 存储桶名称
  /// [objectName] 对象名称
  /// [data] 文件字节数据
  /// [contentType] 文件类型，如 'image/jpeg'
  Future<UploadResult> uploadBytes(
      String bucketName,
      String objectName,
      Uint8List data, {
        String? contentType,
      }) async {
    try {
      // 确保存储桶存在
      await createBucket(bucketName);

      // 准备 metadata（如果有 contentType）
      final metadata = contentType != null
          ? {'Content-Type': contentType}
          : null;

      // 上传字节数据
      await _minioClient.putObject(
        bucketName,
        objectName,
        Stream.value(data),
        size: data.length,
        metadata: metadata,
      );

      final url = MinioConfig.getFileUrl(bucketName, objectName);

      return UploadResult(
        success: true,
        message: '上传成功',
        url: url,
        objectName: objectName,
        size: data.length,
      );
    } catch (e) {
      print('上传文件失败: $e');
      return UploadResult(
        success: false,
        message: '上传失败: ${e.toString()}',
      );
    }
  }

  /// 下载文件
  /// [bucketName] 存储桶名称
  /// [objectName] 对象名称
  /// [savePath] 保存路径
  Future<DownloadResult> downloadFile(
      String bucketName,
      String objectName,
      String savePath,
      ) async {
    try {
      await _minioClient.fGetObject(bucketName, objectName, savePath);

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
  /// [bucketName] 存储桶名称
  /// [objectName] 对象名称
  Future<Uint8List?> getFileBytes(
      String bucketName,
      String objectName,
      ) async {
    try {
      final stream = await _minioClient.getObject(bucketName, objectName);
      final bytes = await stream.toList();
      return Uint8List.fromList(bytes.expand((x) => x).toList());
    } catch (e) {
      print('获取文件数据失败: $e');
      return null;
    }
  }

  /// 删除文件
  /// [bucketName] 存储桶名称
  /// [objectName] 对象名称
  Future<bool> deleteFile(String bucketName, String objectName) async {
    try {
      await _minioClient.removeObject(bucketName, objectName);
      print('文件删除成功: $objectName');
      return true;
    } catch (e) {
      print('删除文件失败: $e');
      return false;
    }
  }

  /// 批量删除文件
  /// [bucketName] 存储桶名称
  /// [objectNames] 对象名称列表
  Future<int> deleteFiles(String bucketName, List<String> objectNames) async {
    int successCount = 0;
    for (final objectName in objectNames) {
      if (await deleteFile(bucketName, objectName)) {
        successCount++;
      }
    }
    return successCount;
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