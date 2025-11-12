// pages/folder_detail/file_service.dart
part of '../folder_detail_page_backup.dart';

/// 文件服务类 - 处理文件系统相关操作
class FileService {

  /// 在后台线程加载文件列表
  static Future<List<FileItem>> loadFilesInBackground(String path) async {
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
        final fileItem = await _createFileItem(entity);
        if (fileItem != null) {
          items.add(fileItem);
        }
      }
    }

    // 排序：文件夹优先，然后按名称排序
    items.sort(_compareFileItems);
    return items;
  }

  /// 递归获取所有媒体文件路径
  static Future<List<String>> getAllMediaFilesRecursive(String path) async {
    final mediaPaths = <String>[];
    final directory = Directory(path);

    if (!await directory.exists()) {
      return mediaPaths;
    }

    try {
      await for (var entity in directory.list(recursive: true)) {
        if (entity is File && MediaExtensions.isMedia(entity.path)) {
          mediaPaths.add(entity.path);
        }
      }
    } catch (e) {
      print('Error accessing directory $path: $e');
    }

    return mediaPaths;
  }

  /// 分析待上传文件的统计信息
  static Future<UploadAnalysisResult> analyzeFilesForUpload(List<String> filePaths) async {
    int imageCount = 0;
    int videoCount = 0;
    int totalBytes = 0;

    for (final path in filePaths) {
      try {
        final file = File(path);
        final stat = await file.stat();

        if (stat.type == FileSystemEntityType.file) {
          if (MediaExtensions.isImage(path)) {
            imageCount++;
            totalBytes += stat.size;
          } else if (MediaExtensions.isVideo(path)) {
            videoCount++;
            totalBytes += stat.size;
          }
        }
      } catch (e) {
        // 忽略无法访问的文件
        print('Error analyzing file $path: $e');
      }
    }

    return UploadAnalysisResult(imageCount, videoCount, totalBytes);
  }

  /// 创建文件项
  static Future<FileItem?> _createFileItem(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    FileItemType? type;

    if (MediaExtensions.isImage(file.path)) {
      type = FileItemType.image;
    } else if (MediaExtensions.isVideo(file.path)) {
      type = FileItemType.video;
    }

    if (type != null) {
      final stat = await file.stat();
      return FileItem(
        name: file.path.split(Platform.pathSeparator).last,
        path: file.path,
        type: type,
        size: stat.size,
      );
    }

    return null;
  }

  /// 文件项比较函数
  static int _compareFileItems(FileItem a, FileItem b) {
    // 文件夹优先
    if (a.type == FileItemType.folder && b.type != FileItemType.folder) {
      return -1;
    }
    if (a.type != FileItemType.folder && b.type == FileItemType.folder) {
      return 1;
    }
    // 按名称排序
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
}