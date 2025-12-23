/// ============================================================
/// 对象信息
/// ============================================================
class McObjectInfo {
  final String key;
  final int size;
  final DateTime? lastModified;
  final bool isDir;

  McObjectInfo({
    required this.key,
    required this.size,
    this.lastModified,
    this.isDir = false,
  });

  String get readableSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  String toString() => 'McObjectInfo(key: $key, size: $readableSize, isDir: $isDir)';
}