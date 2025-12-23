import 'dart:io';

import '../configs/mc_task_status.dart';

/// ============================================================
/// 传输任务信息
/// ============================================================
class McTask {
  final String taskId;
  final String localPath;
  final String remotePath;
  final bool isUpload;
  final DateTime startTime;

  Process? process;
  int transferredBytes = 0;
  int totalBytes = 0;
  int speed = 0;
  McTaskStatus status = McTaskStatus.pending;
  String? errorMessage;

  McTask({
    required this.taskId,
    required this.localPath,
    required this.remotePath,
    required this.isUpload,
  }) : startTime = DateTime.now();

  double get progress => totalBytes > 0 ? transferredBytes / totalBytes : 0;

  String get formattedSpeed => _formatSize(speed) + '/s';

  String get formattedTransferred => _formatSize(transferredBytes);

  String get formattedTotal => _formatSize(totalBytes);

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
