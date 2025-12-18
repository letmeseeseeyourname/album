import 'package:flutter/cupertino.dart';

import '../../services/transfer_speed_service.dart';

/// 实时上传进度追踪器
/// 用于追踪多个并发上传文件的实时进度
class UploadProgressTracker {
  /// 已确认完成上传的字节数
  int _confirmedBytes = 0;

  /// 当前正在上传的各文件的实时进度
  /// key: 文件唯一标识（如 md5Hash_original, md5Hash_thumbnail）
  /// value: 当前文件已上传的字节数
  final Map<String, int> _currentFileProgress = {};

  /// 重置追踪器
  void reset() {
    _confirmedBytes = 0;
    _currentFileProgress.clear();
  }

  /// 更新单个文件的上传进度（实时调用）
  void updateFileProgress(String fileKey, int uploadedBytes) {
    // debugPrint('updateFileProgress: $fileKey, $uploadedBytes');
    _currentFileProgress[fileKey] = uploadedBytes;
    _notifySpeedService();
  }

  /// 标记文件上传完成
  void confirmFileComplete(String fileKey, int totalFileSize) {
    debugPrint('confirmFileComplete: $fileKey, $totalFileSize');
    _confirmedBytes += totalFileSize;
    _currentFileProgress.remove(fileKey);
    _notifySpeedService();
  }

  /// 移除文件进度（上传失败时）
  void removeFileProgress(String fileKey) {
    _currentFileProgress.remove(fileKey);
    _notifySpeedService();
  }

  /// 计算总已上传字节数
  int get totalUploadedBytes {
    int currentProgress = _currentFileProgress.values.fold(0, (a, b) => a + b);
    return _confirmedBytes + currentProgress;
  }

  /// 通知速度服务更新
  void _notifySpeedService() {
    TransferSpeedService.instance.updateUploadProgress(totalUploadedBytes);
  }
}