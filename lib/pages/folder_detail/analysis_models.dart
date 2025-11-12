// pages/folder_detail/analysis_models.dart
part of '../folder_detail_page_backup.dart';

/// 上传分析结果模型
class UploadAnalysisResult {
  final int imageCount;
  final int videoCount;
  final int totalBytes;

  UploadAnalysisResult(this.imageCount, this.videoCount, this.totalBytes);

  /// 获取格式化的文件大小
  String get formattedSize {
    const int kb = 1024;
    const int mb = kb * 1024;
    const int gb = mb * 1024;

    if (totalBytes >= gb) {
      return '${(totalBytes / gb).toStringAsFixed(2)} GB';
    } else if (totalBytes >= mb) {
      return '${(totalBytes / mb).toStringAsFixed(2)} MB';
    } else if (totalBytes >= kb) {
      return '${(totalBytes / kb).toStringAsFixed(2)} KB';
    } else {
      return '$totalBytes B';
    }
  }

  /// 获取以MB为单位的大小
  double get totalSizeMB => totalBytes / (1024 * 1024);
}

/// 文件过滤类型枚举
enum FileFilterType {
  all('all', '全部'),
  image('image', '图片'),
  video('video', '视频');

  final String value;
  final String label;

  const FileFilterType(this.value, this.label);

  static FileFilterType fromValue(String value) {
    return FileFilterType.values.firstWhere(
          (type) => type.value == value,
      orElse: () => FileFilterType.all,
    );
  }
}

/// 媒体文件扩展名常量
class MediaExtensions {
  static const List<String> imageExtensions = [
    'bmp', 'gif', 'jpg', 'jpeg', 'png', 'webp', 'wbmp', 'heic'
  ];

  static const List<String> videoExtensions = [
    'mp4', 'mov', 'avi', '3gp', 'mkv', '3gp2'
  ];

  static List<String> get allExtensions => [...imageExtensions, ...videoExtensions];

  static bool isImage(String path) {
    final ext = path.split('.').last.toLowerCase();
    return imageExtensions.contains(ext);
  }

  static bool isVideo(String path) {
    final ext = path.split('.').last.toLowerCase();
    return videoExtensions.contains(ext);
  }

  static bool isMedia(String path) {
    final ext = path.split('.').last.toLowerCase();
    return allExtensions.contains(ext);
  }
}