import 'dart:convert';
import 'dart:developer' as LogUtil;
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import '../album/manager/local_folder_upload_manager.dart';
import '../models/file_item.dart';

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

/// 文件工具类 - 提供文件操作的静态方法
class FileUtils {
  FileUtils._(); // 私有构造函数，防止实例化

  /// 支持的图片扩展名
  static const imageExtensions = [
    'bmp', 'gif', 'jpg', 'jpeg', 'png', 'webp', 'wbmp', 'heic'
  ];

  /// 支持的视频扩展名
  static const videoExtensions = [
    'mp4', 'mov', 'avi', '3gp', 'mkv', '3gp2'
  ];

  /// 所有媒体扩展名
  static const mediaExtensions = [...imageExtensions, ...videoExtensions];

  /// 检查是否为图片文件
  static bool isImage(String path) {
    final ext = path.split('.').last.toLowerCase();
    return imageExtensions.contains(ext);
  }

  /// 检查是否为视频文件
  static bool isVideo(String path) {
    final ext = path.split('.').last.toLowerCase();
    return videoExtensions.contains(ext);
  }

  /// 检查是否为媒体文件
  static bool isMediaFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return mediaExtensions.contains(ext);
  }

  /// 获取文件类型
  static FileItemType? getFileType(String path) {
    final ext = path.split('.').last.toLowerCase();

    if (imageExtensions.contains(ext)) {
      return FileItemType.image;
    } else if (videoExtensions.contains(ext)) {
      return FileItemType.video;
    }

    return null;
  }

  /// 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// 格式化时长
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
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
        if (entity is File && isMediaFile(entity.path)) {
          mediaPaths.add(entity.path);
        }
      }
    } catch (e) {
      debugPrint('Error accessing directory $path: $e');
    }

    return mediaPaths;
  }

  /// 加载指定路径的文件列表
  static Future<List<FileItem>> loadFiles(String path) async {
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
        final type = getFileType(entity.path);

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
}

/// 上传分析结果模型
class UploadAnalysisResult {
  final int imageCount;
  final int videoCount;
  final int totalBytes;

  UploadAnalysisResult(this.imageCount, this.videoCount, this.totalBytes);

  double get totalSizeMB => totalBytes / (1024 * 1024);
}

/// 文件分析工具
class FileAnalyzer {
  /// 分析文件列表的统计数据
  static Future<UploadAnalysisResult> analyzeFiles(
      List<String> filePaths) async {
    int imageCount = 0;
    int videoCount = 0;
    int totalBytes = 0;

    for (final path in filePaths) {
      try {
        final file = File(path);
        final stat = await file.stat();

        if (stat.type == FileSystemEntityType.file) {
          if (FileUtils.isImage(path)) {
            imageCount++;
            totalBytes += stat.size;
          } else if (FileUtils.isVideo(path)) {
            videoCount++;
            totalBytes += stat.size;
          }
        }
      } catch (e) {
        debugPrint('Error analyzing file $path: $e');
      }
    }

    return UploadAnalysisResult(imageCount, videoCount, totalBytes);
  }
}