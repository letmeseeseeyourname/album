/// 上传进度信息（增强版）
class LocalUploadProgress {
  final int totalFiles;
  final int uploadedFiles;
  final int failedFiles;
  final int retryRound;
  final int maxRetryRounds;
  final String? currentFileName;
  final String? statusMessage;

  // ✅ 新增：字节级进度
  final int transferredBytes;      // 当前文件已传输字节
  final int totalBytes;            // 当前文件总字节
  final int speed;                 // 当前传输速度（字节/秒）
  final int globalTransferredBytes; // 全局已传输字节（已完成 + 当前）
  final int globalTotalBytes;      // 全局总字节

  LocalUploadProgress({
    required this.totalFiles,
    required this.uploadedFiles,
    required this.failedFiles,
    this.retryRound = 0,
    this.maxRetryRounds = 3,
    this.currentFileName,
    this.statusMessage,
    this.transferredBytes = 0,
    this.totalBytes = 0,
    this.speed = 0,
    this.globalTransferredBytes = 0,
    this.globalTotalBytes = 0,
  });

  /// 文件数量进度 (0.0 - 1.0)
  double get progress => totalFiles > 0 ? uploadedFiles / totalFiles : 0.0;

  /// ✅ 字节进度 (0.0 - 1.0)
  double get bytesProgress {
    if (globalTotalBytes > 0) {
      return globalTransferredBytes / globalTotalBytes;
    }
    return progress;
  }

  /// 当前文件传输进度
  double get currentFileProgress => totalBytes > 0 ? transferredBytes / totalBytes : 0.0;

  bool get isRetrying => retryRound > 0;

  String get displayStatus {
    if (statusMessage != null) return statusMessage!;
    if (isRetrying) return '重试第 $retryRound/$maxRetryRounds 轮...';
    return '上传中...';
  }

  /// ✅ 格式化速度
  String get formattedSpeed => _formatSpeed(speed);

  /// ✅ 格式化已传输
  String get formattedTransferred => _formatBytes(
      globalTransferredBytes > 0 ? globalTransferredBytes : transferredBytes);

  /// ✅ 格式化总大小
  String get formattedTotal => _formatBytes(
      globalTotalBytes > 0 ? globalTotalBytes : totalBytes);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }

  static String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond}B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)}KB/s';
    if (bytesPerSecond < 1024 * 1024 * 1024) return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)}MB/s';
    return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB/s';
  }

  /// ✅ 创建副本并更新字节进度
  LocalUploadProgress copyWithBytesProgress({
    int? transferredBytes,
    int? totalBytes,
    int? speed,
    int? globalTransferredBytes,
    int? globalTotalBytes,
    String? currentFileName,
  }) {
    return LocalUploadProgress(
      totalFiles: this.totalFiles,
      uploadedFiles: this.uploadedFiles,
      failedFiles: this.failedFiles,
      retryRound: this.retryRound,
      maxRetryRounds: this.maxRetryRounds,
      currentFileName: currentFileName ?? this.currentFileName,
      statusMessage: this.statusMessage,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      speed: speed ?? this.speed,
      globalTransferredBytes: globalTransferredBytes ?? this.globalTransferredBytes,
      globalTotalBytes: globalTotalBytes ?? this.globalTotalBytes,
    );
  }
}