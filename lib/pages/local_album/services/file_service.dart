// services/file_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../models/file_item.dart';

/// 文件服务类 - 负责文件系统相关操作
class FileService {
  // 支持的媒体文件扩展名
  static const List<String> imageExtensions = [
    'bmp', 'gif', 'jpg', 'jpeg', 'png', 'webp', 'wbmp', 'heic'
  ];

  static const List<String> videoExtensions = [
    'mp4', 'mov', 'avi', '3gp', 'mkv', '3gp2'
  ];

  /// 加载指定路径下的文件列表
  Future<List<FileItem>> loadFiles(String path) async {
    return compute(_loadFilesInBackground, path);
  }

  /// 递归获取所有媒体文件路径
  Future<List<String>> getAllMediaFilesRecursive(String path) async {
    return compute(_getAllMediaFilesRecursive, path);
  }

  /// 分析文件列表的统计数据
  Future<UploadAnalysisResult> analyzeFilesForUpload(List<String> filePaths) async {
    return compute(_analyzeFilesForUpload, filePaths);
  }

  /// 判断文件类型
  static FileItemType? getFileType(String extension) {
    final ext = extension.toLowerCase();
    if (imageExtensions.contains(ext)) {
      return FileItemType.image;
    } else if (videoExtensions.contains(ext)) {
      return FileItemType.video;
    }
    return null;
  }
}

// ============ 后台隔离区运行的静态方法 ============

/// 用于返回上传分析结果的模型
class UploadAnalysisResult {
  final int imageCount;
  final int videoCount;
  final int totalBytes;

  UploadAnalysisResult(this.imageCount, this.videoCount, this.totalBytes);
}

/// 后台加载文件列表
Future<List<FileItem>> _loadFilesInBackground(String path) async {
  final directory = Directory(path);
  final entities = await directory.list().toList();

  final items = <FileItem>[];

  for (var entity in entities) {
    if (entity is Directory) {
      items.add(
        FileItem(
          name: entity.path.split(Platform.pathSeparator).last,
          path: entity.path,
          type: FileItemType.folder,
        ),
      );
    } else if (entity is File) {
      final ext = entity.path.split('.').last.toLowerCase();
      final type = FileService.getFileType(ext);

      if (type != null) {
        final stat = await entity.stat();
        items.add(
          FileItem(
            name: entity.path.split(Platform.pathSeparator).last,
            path: entity.path,
            type: type,
            size: stat.size,
          ),
        );
      }
    }
  }

  // 排序：文件夹在前，然后按名称排序
  items.sort((a, b) {
    if (a.type == FileItemType.folder && b.type != FileItemType.folder) {
      return -1;
    }
    if (a.type != FileItemType.folder && b.type == FileItemType.folder) {
      return 1;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return items;
}

/// 递归获取所有媒体文件路径
Future<List<String>> _getAllMediaFilesRecursive(String path) async {
  final mediaPaths = <String>[];
  final directory = Directory(path);
  if (!await directory.exists()) return mediaPaths;

  const mediaExtensions = [
    ...FileService.imageExtensions,
    ...FileService.videoExtensions,
  ];

  try {
    await for (var entity in directory.list(recursive: true)) {
      if (entity is File) {
        final ext = entity.path.split('.').last.toLowerCase();
        if (mediaExtensions.contains(ext)) {
          mediaPaths.add(entity.path);
        }
      }
    }
  } catch (e) {
    print('Error accessing directory $path: $e');
  }

  return mediaPaths;
}

/// 分析最终上传文件列表的统计数据
Future<UploadAnalysisResult> _analyzeFilesForUpload(List<String> filePaths) async {
  int imageCount = 0;
  int videoCount = 0;
  int totalBytes = 0;

  for (final path in filePaths) {
    try {
      final file = File(path);
      final stat = await file.stat();
      if (stat.type == FileSystemEntityType.file) {
        final ext = path.split('.').last.toLowerCase();

        if (FileService.imageExtensions.contains(ext)) {
          imageCount++;
          totalBytes += stat.size;
        } else if (FileService.videoExtensions.contains(ext)) {
          videoCount++;
          totalBytes += stat.size;
        }
      }
    } catch (e) {
      // 忽略无法访问的文件
    }
  }

  return UploadAnalysisResult(imageCount, videoCount, totalBytes);
}