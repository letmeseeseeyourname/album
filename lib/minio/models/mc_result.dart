/// ============================================================
/// 传输结果
/// ============================================================
class McResult {
  final bool success;
  final String message;
  final String? taskId;
  final String? localPath;
  final String? remotePath;
  final int? size;
  final Duration? duration;
  final bool isCancelled;

  McResult({
    required this.success,
    required this.message,
    this.taskId,
    this.localPath,
    this.remotePath,
    this.size,
    this.duration,
    this.isCancelled = false,
  });

  @override
  String toString() => 'McResult(success: $success, message: $message, isCancelled: $isCancelled)';
}