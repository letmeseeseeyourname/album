// lib/services/thumbnail_helper.dart

import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/file_item.dart';

/// 处理文件系统操作和 C# 辅助程序调用的服务类。
class ThumbnailHelper {
  static String? _helperExePath;
  static const List<String> videoExtensions = [
    '.mp4', '.avi', '.mkv', '.mov', '.wmv',
    '.flv', '.webm', '.m4v', '.mpg', '.mpeg'
  ];

  String? get helperExePath => _helperExePath;

  /// 初始化 C# 辅助程序，将其部署到临时目录。
  Future<void> initializeHelper() async {
    try {
      final tempDir = await getTemporaryDirectory();
      _helperExePath = path.join(tempDir.path, 'ThumbnailGenerator.exe');

      // 仅在文件不存在时复制
      if (!await File(_helperExePath!).exists()) {
        final byteData = await rootBundle.load('assets/ThumbnailGenerator.exe');
        final file = File(_helperExePath!);
        await file.writeAsBytes(byteData.buffer.asUint8List());
        print('✅ C# 辅助程序已部署到: $_helperExePath');
      }
    } catch (e) {
      print('❌ 初始化辅助程序失败: $e');
      rethrow; // 抛出异常，让调用方处理 UI 提示
    }
  }

  /// 扫描指定文件夹，返回视频文件列表。
  Future<List<FileItem>> scanVideoFiles(String folderPath) async {
    final directory = Directory(folderPath);
    final entities = directory.listSync();
    List<FileItem> videoFiles = [];

    for (var entity in entities) {
      if (entity is File) {
        String extension = path.extension(entity.path).toLowerCase();
        if (videoExtensions.contains(extension)) {
          videoFiles.add(FileItem(
            name: path.basename(entity.path),
            path: entity.path,
            thumbnail: null,
            size: entity.lengthSync(),
            type: FileItemType.video,
          ));
        }
      }
    }
    return videoFiles;
  }

  /// 使用 C# 辅助程序生成缩略图。
  static Future<String?> generateThumbnail(String videoPath) async {
    if (_helperExePath == null) return null;

    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath = path.join(
        tempDir.path,
        '${path.basenameWithoutExtension(videoPath)}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // 调用 C# 程序
      final result = await Process.run(
        _helperExePath!,
        [videoPath, outputPath, '320', '180'], // 假设缩略图大小固定
        runInShell: false,
      );

      final output = result.stdout.toString().trim();

      if (output.startsWith('SUCCESS:')) {
        final generatedPath = output.substring(8);
        if (await File(generatedPath).exists()) {
          return generatedPath;
        }
      } else if (output.startsWith('ERROR:')) {
        print('生成缩略图失败: ${output.substring(6)}');
      }

      return null;
    } catch (e) {
      print('调用辅助程序失败: $e');
      return null;
    }
  }

  /// 格式化文件大小。
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}