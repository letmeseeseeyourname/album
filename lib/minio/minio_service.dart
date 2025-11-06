// services/minio_service.dart
// Minio 对象存储服务

import 'dart:io';
import 'dart:typed_data';
import 'package:minio/io.dart';
import 'package:minio/minio.dart';
import 'minio_config.dart';

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
      endPoint: MinioConfig.endpoint.split(':')[0],
      port: int.parse(MinioConfig.endpoint.split(':')[1]),
      accessKey: MinioConfig.accessKey,
      secretKey: MinioConfig.secretKey,
      useSSL: MinioConfig.useSSL,
    );
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
      await _minio.fPutObject(bucketName, objectName, filePath);

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
      await _minio.putObject(
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
  /// [bucketName] 存储桶名称
  /// [objectName] 对象名称
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
  /// [bucketName] 存储桶名称
  /// [objectName] 对象名称
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

  /// 列出存储桶中的所有对象
  /// [bucketName] 存储桶名称
  /// [prefix] 对象名称前缀（可选）
  // Future<List<MinioObject>> listObjects(
  //     String bucketName, {
  //       String? prefix,
  //     }) async {
  //   try {
  //     final objects = <MinioObject>[];
  //     final stream = _minio.listObjects(
  //       bucketName,
  //       prefix: prefix ?? '',
  //     );
  //
  //     await for (final obj in stream) {
  //       // ListObjectsResult 的属性：name, lastModified, eTag, size, isDir
  //       if (obj.name != null && !obj.isDir) {
  //         objects.add(MinioObject(
  //           key: obj.name!,
  //           size: obj.size ?? 0,
  //           lastModified: obj.lastModified,
  //         ));
  //       }
  //     }
  //
  //     return objects;
  //   } catch (e) {
  //     print('列出对象失败: $e');
  //     return [];
  //   }
  // }

  /// 获取文件的预签名 URL（用于临时访问）
  /// [bucketName] 存储桶名称
  /// [objectName] 对象名称
  /// [expires] 过期时间（秒），默认7天
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
  /// [sourceBucket] 源存储桶
  /// [sourceObject] 源对象名称
  /// [destBucket] 目标存储桶
  /// [destObject] 目标对象名称
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

  /// 获取对象信息
  /// [bucketName] 存储桶名称
  /// [objectName] 对象名称
//   Future<ObjectStat?> getObjectStat(
//       String bucketName,
//       String objectName,
//       ) async {
//     try {
//       final stat = await _minio.statObject(bucketName, objectName);
//       // StatObjectResult 的属性：size, lastModified, eTag, metaData
//       return ObjectStat(
//         size: stat.size ?? 0,
//         contentType: stat.metaData?['content-type'],
//         lastModified: stat.lastModified,
//         etag: stat.eTag,
//       );
//     } catch (e) {
//       print('获取对象信息失败: $e');
//       return null;
//     }
//   }
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