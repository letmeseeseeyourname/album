import 'dart:convert';
import 'dart:developer' as LogUtil;
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import '../album/manager/local_folder_upload_manager.dart';
import '../models/file_item.dart';
import 'package:flutter/foundation.dart';


Future<Directory> getSafeLibraryDir() async {
  if (Platform.isAndroid) {
    // Android 上用 getTemporaryDirectory 代替
    return await getTemporaryDirectory();
  } else {
    return await getLibraryDirectory();
  }
}


/// 获取视频元数据（duration、width、height）
Future<VideoMetadata> getVideoMetadata(String videoPath) async {
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

/// 文件上传分析结果模型
class UploadAnalysisResult {
  final int imageCount;
  final int videoCount;
  final int totalBytes;

  const UploadAnalysisResult({
    required this.imageCount,
    required this.videoCount,
    required this.totalBytes,
  });
}

/// 文件工具类 - 提供文件操作相关的静态方法
class FileUtils {
  // 支持的媒体文件扩展名
  static const imageExtensions = [
    'bmp', 'gif', 'jpg', 'jpeg', 'png', 'webp', 'wbmp', 'heic'
  ];

 static const videoExtensions = ['mp4', 'mov', 'avi', '3gp', 'mkv', '3gp2'];

  static const mediaExtensions = [
    ...imageExtensions,
    ...videoExtensions,
  ];

  /// 递归获取指定路径下的所有媒体文件
  static Future<List<String>> getAllMediaFilesRecursive(String path) async {
    final mediaPaths = <String>[];
    final directory = Directory(path);

    if (!await directory.exists()) {
      return mediaPaths;
    }

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
      // 记录错误但不中断其他文件的收集
      debugPrint('Error accessing directory $path: $e');
    }

    return mediaPaths;
  }

  /// 分析文件列表的统计信息
  static Future<UploadAnalysisResult> analyzeFilesForUpload(
      List<String> filePaths,
      ) async {
    int imageCount = 0;
    int videoCount = 0;
    int totalBytes = 0;

    for (final path in filePaths) {
      try {
        final file = File(path);
        final stat = await file.stat();

        if (stat.type == FileSystemEntityType.file) {
          final ext = path.split('.').last.toLowerCase();

          if (imageExtensions.contains(ext)) {
            imageCount++;
            totalBytes += stat.size;
          } else if (videoExtensions.contains(ext)) {
            videoCount++;
            totalBytes += stat.size;
          }
        }
      } catch (e) {
        // 忽略无法访问的文件
        debugPrint('Error analyzing file $path: $e');
      }
    }

    return UploadAnalysisResult(
      imageCount: imageCount,
      videoCount: videoCount,
      totalBytes: totalBytes,
    );
  }

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
        final ext = entity.path.split('.').last.toLowerCase();
        FileItemType? type;

        if (imageExtensions.contains(ext)) {
          type = FileItemType.image;
        } else if (videoExtensions.contains(ext)) {
          type = FileItemType.video;
        }

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

    // 排序：文件夹优先，然后按名称排序
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

  /// 判断文件是否为图片
  static bool isImageFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return imageExtensions.contains(ext);
  }

  /// 判断文件是否为视频
  static bool isVideoFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return videoExtensions.contains(ext);
  }

  /// 判断文件是否为媒体文件
  static bool isMediaFile(String path) {
    return isImageFile(path) || isVideoFile(path);
  }

  /// 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}