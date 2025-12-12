// eventbus/download_events.dart
// 下载相关事件定义

/// 下载路径变更事件
class DownloadPathChangedEvent {
  final String newPath;

  DownloadPathChangedEvent(this.newPath);

  @override
  String toString() => 'DownloadPathChangedEvent(newPath: $newPath)';
}

/// 下载完成事件
class DownloadCompleteEvent {
  final String taskId;
  final String fileName;
  final String? savePath;

  DownloadCompleteEvent({
    required this.taskId,
    required this.fileName,
    this.savePath,
  });

  @override
  String toString() => 'DownloadCompleteEvent(taskId: $taskId, fileName: $fileName)';
}

/// 下载失败事件
class DownloadFailedEvent {
  final String taskId;
  final String fileName;
  final String? errorMessage;

  DownloadFailedEvent({
    required this.taskId,
    required this.fileName,
    this.errorMessage,
  });

  @override
  String toString() => 'DownloadFailedEvent(taskId: $taskId, fileName: $fileName, error: $errorMessage)';
}

/// 下载进度事件
class DownloadProgressEvent {
  final String taskId;
  final String fileName;
  final int downloadedSize;
  final int totalSize;
  final double progress;

  DownloadProgressEvent({
    required this.taskId,
    required this.fileName,
    required this.downloadedSize,
    required this.totalSize,
  }) : progress = totalSize > 0 ? downloadedSize / totalSize : 0.0;

  @override
  String toString() => 'DownloadProgressEvent(taskId: $taskId, progress: ${(progress * 100).toStringAsFixed(1)}%)';
}