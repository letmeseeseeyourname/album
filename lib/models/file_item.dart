// models/file_item.dart
enum FileItemType {
  folder,
  image,
  video,
}

class FileItem {
  final String name;
  final String path;
  final FileItemType type;
  final int size; // 文件大小（字节）
  final String? thumbnail; // 缩略图路径（可选）
  final bool? isUploaded; // 是否已上传：true=已上传, false/null=未上传

  FileItem({
    required this.name,
    required this.path,
    required this.type,
    this.size = 0,
    this.thumbnail,
    this.isUploaded,
  });

  // 格式化文件大小
  String get formattedSize {
    if (size == 0) return '';

    if (size < 1024) {
      return '${size}B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)}KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
    }
  }

  // 获取文件扩展名
  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  /// 创建带有更新字段的副本
  FileItem copyWith({
    String? name,
    String? path,
    FileItemType? type,
    int? size,
    String? thumbnail,
    bool? isUploaded,
  }) {
    return FileItem(
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      size: size ?? this.size,
      thumbnail: thumbnail ?? this.thumbnail,
      isUploaded: isUploaded ?? this.isUploaded,
    );
  }
}