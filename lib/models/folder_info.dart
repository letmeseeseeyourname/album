// models/folder_info.dart
class FolderInfo {
  final String name;
  final String path;
  final int fileCount;
  final int totalSize;

  FolderInfo({
    required this.name,
    required this.path,
    this.fileCount = 0,
    this.totalSize = 0,
  });

  /// 格式化文件大小
  String get formattedSize {
    if (totalSize <= 0) return '';

    const int kb = 1024;
    const int mb = kb * 1024;
    const int gb = mb * 1024;

    if (totalSize >= gb) {
      return '${(totalSize / gb).toStringAsFixed(2)} GB';
    } else if (totalSize >= mb) {
      return '${(totalSize / mb).toStringAsFixed(2)} MB';
    } else if (totalSize >= kb) {
      return '${(totalSize / kb).toStringAsFixed(2)} KB';
    } else {
      return '$totalSize B';
    }
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'fileCount': fileCount,
      'totalSize': totalSize,
    };
  }

  /// 从 JSON 创建
  factory FolderInfo.fromJson(Map<String, dynamic> json) {
    return FolderInfo(
      name: json['name'] as String,
      path: json['path'] as String,
      fileCount: json['fileCount'] as int? ?? 0,
      totalSize: json['totalSize'] as int? ?? 0,
    );
  }

  /// 复制并修改部分属性
  FolderInfo copyWith({
    String? name,
    String? path,
    int? fileCount,
    int? totalSize,
  }) {
    return FolderInfo(
      name: name ?? this.name,
      path: path ?? this.path,
      fileCount: fileCount ?? this.fileCount,
      totalSize: totalSize ?? this.totalSize,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FolderInfo && other.path == path;
  }

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() {
    return 'FolderInfo(name: $name, path: $path, fileCount: $fileCount, totalSize: $totalSize)';
  }
}