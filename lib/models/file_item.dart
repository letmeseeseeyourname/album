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

  FileItem({
    required this.name,
    required this.path,
    required this.type,
    this.size = 0,
    this.thumbnail,
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
}