// services/file_service.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../models/file_item.dart';
import '../../../album/database/database_helper.dart';
import '../../../album/models/local_file_item.dart' as db; // 数据库中的 FileItem
import '../../../services/sync_status_service.dart';
import '../../../user/my_instance.dart';


/// 文件服务 - 负责加载文件列表并查询上传状态
class FileService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final SyncStatusService _syncService = SyncStatusService.instance;
  /// 支持的图片扩展名
  static const Set<String> _imageExtensions = {
    'bmp', 'gif', 'jpg', 'jpeg', 'png', 'webp', 'wbmp', 'heic'
  };

  /// 支持的视频扩展名
  static const Set<String> _videoExtensions = {
    'mp4', 'mov', 'avi', '3gp', 'mkv', '3gp2'
  };

  /// 加载指定路径下的文件列表
  ///
  /// ✅ 会查询数据库获取每个文件的上传状态
  Future<List<FileItem>> loadFiles1(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      return [];
    }

    final entities = await directory.list().toList();
    final items = <FileItem>[];

    // 获取用户信息用于查询数据库
    final userId = MyInstance().user?.user?.id?.toString() ?? '';
    final deviceCode = MyInstance().deviceCode;

    // ✅ 批量获取已上传文件的路径集合（性能优化）
    final uploadedPaths = await _getUploadedFilePaths(userId, deviceCode);

    for (final entity in entities) {
      final name = p.basename(entity.path);

      // 跳过隐藏文件
      if (name.startsWith('.')) continue;

      if (entity is Directory) {
        items.add(FileItem(
          name: name,
          path: entity.path,
          type: FileItemType.folder,
          size: 0,
          isUploaded: null, // 文件夹不需要显示上传状态
        ));
      } else if (entity is File) {
        final extension = p.extension(name).toLowerCase().replaceFirst('.', '');
        final type = _getFileType(extension);

        // 只处理图片和视频
        if (type == FileItemType.image || type == FileItemType.video) {
          final stat = await entity.stat();

          // ✅ 检查文件是否已上传（通过路径匹配）
          final isUploaded = uploadedPaths.contains(entity.path);

          items.add(FileItem(
            name: name,
            path: entity.path,
            type: type,
            size: stat.size,
            isUploaded: isUploaded,
          ));
        }
      }
    }

    // 排序：文件夹在前，然后按名称排序
    items.sort((a, b) {
      if (a.type == FileItemType.folder && b.type != FileItemType.folder) {
        return -1;
      } else if (a.type != FileItemType.folder && b.type == FileItemType.folder) {
        return 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return items;
  }

  /// ✅ 获取已上传文件的路径集合
  ///
  /// 通过查询数据库，获取 status == 2（上传成功）的文件路径
  Future<Set<String>> _getUploadedFilePaths(String userId, String deviceCode) async {
    if (userId.isEmpty || deviceCode.isEmpty) {
      return {};
    }

    try {
      // 获取该用户和设备下所有已上传的文件
      final List<db.FileItem> dbFiles = await _dbHelper.fetchFilesByUserAndDevice(userId, deviceCode);

      // 筛选 status == 2（上传成功）的文件路径
      final uploadedPaths = <String>{};
      for (final file in dbFiles) {
        // status: 0=待上传, 1=上传中, 2=上传成功
        if (file.status == 2 && file.filePath.isNotEmpty) {
          uploadedPaths.add(file.filePath);
        }
      }

      return uploadedPaths;
    } catch (e) {
      print('Error fetching uploaded files: $e');
      return {};
    }
  }

  /// 加载指定路径下的文件列表
  ///
  /// ✅ 通过 SyncStatusService 查询服务端判断同步状态
  Future<List<FileItem>> loadFiles(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      return [];
    }

    final entities = await directory.list().toList();
    final items = <FileItem>[];
    final mediaFilePaths = <String>[];  // 收集需要检查同步状态的文件路径

    // 第一遍：解析所有文件，收集媒体文件路径
    for (final entity in entities) {
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;

      if (entity is Directory) {
        items.add(FileItem(
          name: name,
          path: entity.path,
          type: FileItemType.folder,
          size: 0,
          isUploaded: null,  // 文件夹不需要同步状态
        ));
      } else if (entity is File) {
        final extension = p.extension(name).toLowerCase().replaceFirst('.', '');
        final type = _getFileType(extension);

        if (type == FileItemType.image || type == FileItemType.video) {
          final stat = await entity.stat();
          items.add(FileItem(
            name: name,
            path: entity.path,
            type: type,
            size: stat.size,
            isUploaded: false,  // 先默认为未同步，后续批量更新
          ));
          mediaFilePaths.add(entity.path);
        }
      }
    }

    // 第二遍：批量查询同步状态
    if (mediaFilePaths.isNotEmpty) {
      final syncStatus = await _syncService.checkSyncStatusBatch(mediaFilePaths);

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        if (item.type != FileItemType.folder) {
          final isSynced = syncStatus[item.path];
          if (isSynced != null) {
            items[i] = item.copyWith(isUploaded: isSynced);
          }
        }
      }
    }

    // 排序：文件夹在前，然后按名称排序
    items.sort((a, b) {
      if (a.type == FileItemType.folder && b.type != FileItemType.folder) {
        return -1;
      } else if (a.type != FileItemType.folder && b.type == FileItemType.folder) {
        return 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return items;
  }


  /// 根据扩展名判断文件类型
  FileItemType _getFileType(String extension) {
    if (_imageExtensions.contains(extension)) {
      return FileItemType.image;
    } else if (_videoExtensions.contains(extension)) {
      return FileItemType.video;
    }
    return FileItemType.folder; // 其他类型暂时返回 folder，实际不会显示
  }

  /// 获取指定文件夹下的所有媒体文件路径（递归）
  Future<List<String>> getMediaFilePaths(String folderPath) async {
    final paths = <String>[];
    final directory = Directory(folderPath);

    if (!await directory.exists()) {
      return paths;
    }

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        final extension = p.extension(entity.path).toLowerCase().replaceFirst('.', '');
        if (_imageExtensions.contains(extension) || _videoExtensions.contains(extension)) {
          paths.add(entity.path);
        }
      }
    }

    return paths;
  }

  /// 统计文件夹中的媒体文件
  Future<Map<String, int>> countMediaFiles(String folderPath) async {
    int imageCount = 0;
    int videoCount = 0;
    int totalSize = 0;

    final directory = Directory(folderPath);
    if (!await directory.exists()) {
      return {'images': 0, 'videos': 0, 'totalSize': 0};
    }

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        final extension = p.extension(entity.path).toLowerCase().replaceFirst('.', '');
        if (_imageExtensions.contains(extension)) {
          imageCount++;
          totalSize += await entity.length();
        } else if (_videoExtensions.contains(extension)) {
          videoCount++;
          totalSize += await entity.length();
        }
      }
    }

    return {
      'images': imageCount,
      'videos': videoCount,
      'totalSize': totalSize,
    };
  }

  /// ✅ 递归获取文件夹下所有媒体文件路径
  /// 供 UploadCoordinator 调用
  Future<List<String>> getAllMediaFilesRecursive(String folderPath) async {
    final paths = <String>[];
    final directory = Directory(folderPath);

    if (!await directory.exists()) {
      return paths;
    }

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        final extension = p.extension(entity.path).toLowerCase().replaceFirst('.', '');
        if (_imageExtensions.contains(extension) || _videoExtensions.contains(extension)) {
          paths.add(entity.path);
        }
      }
    }

    return paths;
  }

  /// ✅ 分析待上传文件列表
  /// 返回图片数量、视频数量和总字节数
  Future<FileAnalysisResult> analyzeFilesForUpload(List<String> filePaths) async {
    int imageCount = 0;
    int videoCount = 0;
    int totalBytes = 0;

    for (final filePath in filePaths) {
      final file = File(filePath);
      if (!await file.exists()) continue;

      final extension = p.extension(filePath).toLowerCase().replaceFirst('.', '');
      final fileSize = await file.length();

      if (_imageExtensions.contains(extension)) {
        imageCount++;
        totalBytes += fileSize;
      } else if (_videoExtensions.contains(extension)) {
        videoCount++;
        totalBytes += fileSize;
      }
    }

    return FileAnalysisResult(
      imageCount: imageCount,
      videoCount: videoCount,
      totalBytes: totalBytes,
    );
  }
}

/// 文件分析结果
class FileAnalysisResult {
  final int imageCount;
  final int videoCount;
  final int totalBytes;

  FileAnalysisResult({
    required this.imageCount,
    required this.videoCount,
    required this.totalBytes,
  });
}