// services/transfer_speed_service.dart
// 传输速率服务（优化版 - 滑动窗口平均，更平滑的速度显示）

import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';

/// 传输速率服务（单例）
/// 监控上传和下载的实时速率
class TransferSpeedService extends ChangeNotifier {
  static final TransferSpeedService instance = TransferSpeedService._init();
  TransferSpeedService._init();

  // ============================================================
  // 配置参数
  // ============================================================

  /// 采样间隔（毫秒）- 越短更新越频繁
  static const int _sampleIntervalMs = 500;

  /// 滑动窗口大小 - 保留最近几次采样用于平均
  static const int _windowSize = 5;

  /// 速度变化平滑因子 (0-1)，越大越平滑但响应越慢
  static const double _smoothingFactor = 0.3;

  // ============================================================
  // 状态变量
  // ============================================================

  // 平滑后的速率（字节/秒）
  double _smoothedUploadSpeed = 0;
  double _smoothedDownloadSpeed = 0;

  // 累计传输量
  int _lastUploadBytes = 0;
  int _lastDownloadBytes = 0;
  int _currentUploadBytes = 0;
  int _currentDownloadBytes = 0;

  // 传输状态
  bool _isUploading = false;
  bool _isDownloading = false;

  // 定时器
  Timer? _speedTimer;

  // 滑动窗口历史记录
  final Queue<double> _uploadSpeedHistory = Queue<double>();
  final Queue<double> _downloadSpeedHistory = Queue<double>();

  // ============================================================
  // Getters
  // ============================================================

  int get uploadSpeed => _smoothedUploadSpeed.round();
  int get downloadSpeed => _smoothedDownloadSpeed.round();
  bool get isUploading => _isUploading;
  bool get isDownloading => _isDownloading;
  bool get hasActiveTransfer => _isUploading || _isDownloading;

  /// 格式化速率显示
  String get formattedUploadSpeed => _formatSpeed(_smoothedUploadSpeed.round());
  String get formattedDownloadSpeed => _formatSpeed(_smoothedDownloadSpeed.round());

  // ============================================================
  // 公共方法
  // ============================================================

  /// 开始监控
  void startMonitoring() {
    _speedTimer?.cancel();

    // 重置状态
    _uploadSpeedHistory.clear();
    _downloadSpeedHistory.clear();
    _smoothedUploadSpeed = 0;
    _smoothedDownloadSpeed = 0;
    _lastUploadBytes = _currentUploadBytes;
    _lastDownloadBytes = _currentDownloadBytes;

    // 启动定时采样
    _speedTimer = Timer.periodic(
      const Duration(milliseconds: _sampleIntervalMs),
          (_) => _calculateSpeed(),
    );
  }

  /// 停止监控
  void stopMonitoring() {
    _speedTimer?.cancel();
    _speedTimer = null;
    _smoothedUploadSpeed = 0;
    _smoothedDownloadSpeed = 0;
    _uploadSpeedHistory.clear();
    _downloadSpeedHistory.clear();
    notifyListeners();
  }

  /// 更新上传进度（实时调用）
  void updateUploadProgress(int totalBytes) {
    _currentUploadBytes = totalBytes;
    if (!_isUploading) {
      _isUploading = true;
      _lastUploadBytes = totalBytes; // 避免首次计算出巨大速度
    }
  }

  /// 更新下载进度（实时调用）
  void updateDownloadProgress(int totalBytes) {
    _currentDownloadBytes = totalBytes;
    if (!_isDownloading) {
      _isDownloading = true;
      _lastDownloadBytes = totalBytes;
    }
  }

  /// 上传完成
  void onUploadComplete() {
    _isUploading = false;
    _smoothedUploadSpeed = 0;
    _currentUploadBytes = 0;
    _lastUploadBytes = 0;
    _uploadSpeedHistory.clear();
    notifyListeners();
  }

  /// 下载完成
  void onDownloadComplete() {
    _isDownloading = false;
    _smoothedDownloadSpeed = 0;
    _currentDownloadBytes = 0;
    _lastDownloadBytes = 0;
    _downloadSpeedHistory.clear();
    notifyListeners();
  }

  // ============================================================
  // 私有方法
  // ============================================================

  /// 计算速率（核心算法）
  void _calculateSpeed() {
    // 计算上传速率
    if (_isUploading) {
      _smoothedUploadSpeed = _calculateSmoothedSpeed(
        currentBytes: _currentUploadBytes,
        lastBytes: _lastUploadBytes,
        history: _uploadSpeedHistory,
        previousSmoothed: _smoothedUploadSpeed,
      );
      _lastUploadBytes = _currentUploadBytes;
    } else {
      _smoothedUploadSpeed = 0;
      _uploadSpeedHistory.clear();
    }

    // 计算下载速率
    if (_isDownloading) {
      _smoothedDownloadSpeed = _calculateSmoothedSpeed(
        currentBytes: _currentDownloadBytes,
        lastBytes: _lastDownloadBytes,
        history: _downloadSpeedHistory,
        previousSmoothed: _smoothedDownloadSpeed,
      );
      _lastDownloadBytes = _currentDownloadBytes;
    } else {
      _smoothedDownloadSpeed = 0;
      _downloadSpeedHistory.clear();
    }

    notifyListeners();
  }

  /// 计算平滑后的速度
  /// 结合滑动窗口平均 + 指数移动平均（EMA）
  double _calculateSmoothedSpeed({
    required int currentBytes,
    required int lastBytes,
    required Queue<double> history,
    required double previousSmoothed,
  }) {
    // 1. 计算瞬时速度
    final bytesDelta = currentBytes - lastBytes;
    final instantSpeed = (bytesDelta * 1000.0) / _sampleIntervalMs;

    // 忽略负值（可能是重置导致）
    if (instantSpeed < 0) return previousSmoothed;

    // 2. 添加到滑动窗口
    history.addLast(instantSpeed);
    if (history.length > _windowSize) {
      history.removeFirst();
    }

    // 3. 计算滑动窗口平均
    double windowAverage = 0;
    if (history.isNotEmpty) {
      windowAverage = history.reduce((a, b) => a + b) / history.length;
    }

    // 4. 应用指数移动平均（EMA）进一步平滑
    // 新值 = α * 当前平均 + (1-α) * 旧值
    final smoothed = _smoothingFactor * windowAverage +
        (1 - _smoothingFactor) * previousSmoothed;

    return smoothed;
  }

  /// 格式化速率显示
  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond}B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)}KB/s';
    } else if (bytesPerSecond < 1024 * 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)}MB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB/s';
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