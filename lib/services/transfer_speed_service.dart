// services/transfer_speed_service.dart
import 'dart:async';
import 'package:flutter/material.dart';

/// 传输速率服务（单例）
/// 监控上传和下载的实时速率
class TransferSpeedService extends ChangeNotifier {
  static final TransferSpeedService instance = TransferSpeedService._init();
  TransferSpeedService._init();

  // 上传速率（字节/秒）
  int _uploadSpeed = 0;
  // 下载速率（字节/秒）
  int _downloadSpeed = 0;

  // 累计传输量（用于计算速率）
  int _lastUploadBytes = 0;
  int _lastDownloadBytes = 0;
  int _currentUploadBytes = 0;
  int _currentDownloadBytes = 0;

  // 是否正在传输
  bool _isUploading = false;
  bool _isDownloading = false;

  // 定时器
  Timer? _speedTimer;

  // Getters
  int get uploadSpeed => _uploadSpeed;
  int get downloadSpeed => _downloadSpeed;
  bool get isUploading => _isUploading;
  bool get isDownloading => _isDownloading;
  bool get hasActiveTransfer => _isUploading || _isDownloading;

  /// 格式化速率显示
  String get formattedUploadSpeed => _formatSpeed(_uploadSpeed);
  String get formattedDownloadSpeed => _formatSpeed(_downloadSpeed);

  /// 开始监控
  void startMonitoring() {
    _speedTimer?.cancel();
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _calculateSpeed();
    });
  }

  /// 停止监控
  void stopMonitoring() {
    _speedTimer?.cancel();
    _speedTimer = null;
    _uploadSpeed = 0;
    _downloadSpeed = 0;
    notifyListeners();
  }

  /// 更新上传进度
  void updateUploadProgress(int totalBytes) {
    _currentUploadBytes = totalBytes;
    _isUploading = true;
    notifyListeners();
  }

  /// 更新下载进度
  void updateDownloadProgress(int totalBytes) {
    _currentDownloadBytes = totalBytes;
    _isDownloading = true;
    notifyListeners();
  }

  /// 上传完成
  void onUploadComplete() {
    _isUploading = false;
    _uploadSpeed = 0;
    _currentUploadBytes = 0;
    _lastUploadBytes = 0;
    notifyListeners();
  }

  /// 下载完成
  void onDownloadComplete() {
    _isDownloading = false;
    _downloadSpeed = 0;
    _currentDownloadBytes = 0;
    _lastDownloadBytes = 0;
    notifyListeners();
  }

  /// 计算速率
  void _calculateSpeed() {
    // 计算上传速率
    if (_isUploading) {
      _uploadSpeed = _currentUploadBytes - _lastUploadBytes;
      _lastUploadBytes = _currentUploadBytes;
      if (_uploadSpeed < 0) _uploadSpeed = 0;
    } else {
      _uploadSpeed = 0;
    }

    // 计算下载速率
    if (_isDownloading) {
      _downloadSpeed = _currentDownloadBytes - _lastDownloadBytes;
      _lastDownloadBytes = _currentDownloadBytes;
      if (_downloadSpeed < 0) _downloadSpeed = 0;
    } else {
      _downloadSpeed = 0;
    }

    notifyListeners();
  }

  /// 格式化速率
  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond}B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)}KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)}MB/s';
    }
  }

  @override
  void dispose() {
    _speedTimer?.cancel();
    super.dispose();
  }
}

/// 传输速率显示组件
class TransferSpeedIndicator extends StatelessWidget {
  final TransferSpeedService speedService;

  const TransferSpeedIndicator({
    super.key,
    required this.speedService,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: speedService,
      builder: (context, child) {
        if (!speedService.hasActiveTransfer) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 上传速率
              if (speedService.isUploading) ...[
                const Icon(
                  Icons.upload,
                  size: 16,
                  color: Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  speedService.formattedUploadSpeed,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              // 分隔符
              if (speedService.isUploading && speedService.isDownloading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '|',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),

              // 下载速率
              if (speedService.isDownloading) ...[
                const Icon(
                  Icons.download,
                  size: 16,
                  color: Colors.blue,
                ),
                const SizedBox(width: 4),
                Text(
                  speedService.formattedDownloadSpeed,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}