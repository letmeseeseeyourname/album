// services/transfer_speed_service.dart
// 传输速率服务（优化版 - 支持 mc.exe 输出解析）

import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';

import '../minio/mc_output_parser.dart';


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

  // 直接设置的速率（来自 mc 输出）- 单任务模式
  int _directUploadSpeed = 0;
  int _directDownloadSpeed = 0;

  // 是否使用直接设置的速率
  bool _useDirectUploadSpeed = false;
  bool _useDirectDownloadSpeed = false;

  // ✅ 多任务速度追踪
  // key: taskId, value: 该任务当前速度（字节/秒）
  final Map<String, int> _uploadTaskSpeeds = {};
  final Map<String, int> _downloadTaskSpeeds = {};

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

  /// 获取上传速度（优先使用多任务累加速度）
  int get uploadSpeed {
    // 多任务模式：累加所有任务的速度
    if (_uploadTaskSpeeds.isNotEmpty) {
      return _uploadTaskSpeeds.values.fold(0, (sum, speed) => sum + speed);
    }
    // 单任务模式
    if (_useDirectUploadSpeed && _directUploadSpeed > 0) {
      return _directUploadSpeed;
    }
    return _smoothedUploadSpeed.round();
  }

  /// 获取下载速度（优先使用多任务累加速度）
  int get downloadSpeed {
    // 多任务模式：累加所有任务的速度
    if (_downloadTaskSpeeds.isNotEmpty) {
      return _downloadTaskSpeeds.values.fold(0, (sum, speed) => sum + speed);
    }
    // 单任务模式
    if (_useDirectDownloadSpeed && _directDownloadSpeed > 0) {
      return _directDownloadSpeed;
    }
    return _smoothedDownloadSpeed.round();
  }

  bool get isUploading => _isUploading;
  bool get isDownloading => _isDownloading;
  bool get hasActiveTransfer => _isUploading || _isDownloading;

  /// 格式化速率显示
  String get formattedUploadSpeed => _formatSpeed(uploadSpeed);
  String get formattedDownloadSpeed => _formatSpeed(downloadSpeed);

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
    _directUploadSpeed = 0;
    _directDownloadSpeed = 0;
    _useDirectUploadSpeed = false;
    _useDirectDownloadSpeed = false;
    _uploadTaskSpeeds.clear();
    _downloadTaskSpeeds.clear();
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
    _directUploadSpeed = 0;
    _directDownloadSpeed = 0;
    _useDirectUploadSpeed = false;
    _useDirectDownloadSpeed = false;
    _uploadTaskSpeeds.clear();
    _downloadTaskSpeeds.clear();
    _uploadSpeedHistory.clear();
    _downloadSpeedHistory.clear();
    notifyListeners();
  }

  /// 更新上传进度（实时调用）
  void updateUploadProgress(int totalBytes) {
    _currentUploadBytes = totalBytes;
    _useDirectUploadSpeed = false; // 使用字节计算模式
    if (!_isUploading) {
      _isUploading = true;
      _lastUploadBytes = totalBytes;
    }
  }

  /// 更新下载进度（实时调用）
  void updateDownloadProgress(int totalBytes) {
    _currentDownloadBytes = totalBytes;
    _useDirectDownloadSpeed = false; // 使用字节计算模式
    if (!_isDownloading) {
      _isDownloading = true;
      _lastDownloadBytes = totalBytes;
    }
  }

  // ============================================================
  // ✅ 新增：直接设置速度（用于 mc.exe 输出）
  // ============================================================

  /// 直接设置上传速度（字节/秒）- 单任务模式
  /// 用于从 mc.exe 输出解析的速度
  void setUploadSpeed(int bytesPerSecond) {
    _directUploadSpeed = bytesPerSecond;
    _useDirectUploadSpeed = true;
    if (!_isUploading) {
      _isUploading = true;
    }
    notifyListeners();
  }

  /// 直接设置下载速度（字节/秒）- 单任务模式
  void setDownloadSpeed(int bytesPerSecond) {
    _directDownloadSpeed = bytesPerSecond;
    _useDirectDownloadSpeed = true;
    if (!_isDownloading) {
      _isDownloading = true;
    }
    notifyListeners();
  }

  // ============================================================
  // ✅ 多任务模式：支持并发任务速度累加
  // ============================================================

  /// 更新指定任务的上传速度（多任务模式）
  /// [taskId] 任务唯一标识
  /// [bytesPerSecond] 该任务当前速度
  void setUploadSpeedForTask(String taskId, int bytesPerSecond) {
    _uploadTaskSpeeds[taskId] = bytesPerSecond;
    if (!_isUploading) {
      _isUploading = true;
    }
    notifyListeners();
  }

  /// 更新指定任务的下载速度（多任务模式）
  void setDownloadSpeedForTask(String taskId, int bytesPerSecond) {
    _downloadTaskSpeeds[taskId] = bytesPerSecond;
    if (!_isDownloading) {
      _isDownloading = true;
    }
    notifyListeners();
  }

  /// 从 mc 输出更新指定任务的上传速度
  void updateUploadSpeedForTaskFromMcOutput(String taskId, String output) {
    final speed = McOutputParser.parseSpeed(output);
    if (speed > 0) {
      setUploadSpeedForTask(taskId, speed);
    }
  }

  /// 从 mc 输出更新指定任务的下载速度
  void updateDownloadSpeedForTaskFromMcOutput(String taskId, String output) {
    final speed = McOutputParser.parseSpeed(output);
    if (speed > 0) {
      setDownloadSpeedForTask(taskId, speed);
    }
  }

  /// 移除指定任务的上传速度（任务完成时调用）
  void removeUploadTask(String taskId) {
    _uploadTaskSpeeds.remove(taskId);
    if (_uploadTaskSpeeds.isEmpty) {
      _isUploading = false;
    }
    notifyListeners();
  }

  /// 移除指定任务的下载速度（任务完成时调用）
  void removeDownloadTask(String taskId) {
    _downloadTaskSpeeds.remove(taskId);
    if (_downloadTaskSpeeds.isEmpty) {
      _isDownloading = false;
    }
    notifyListeners();
  }

  /// 获取当前活跃的上传任务数
  int get activeUploadTaskCount => _uploadTaskSpeeds.length;

  /// 获取当前活跃的下载任务数
  int get activeDownloadTaskCount => _downloadTaskSpeeds.length;

  /// 从 mc 输出字符串更新上传速度（单任务模式）
  /// 示例输入: "D:\image\photo.jpg: 192.00 KiB / 2.42 MiB  9.74 KiB/s"
  void updateUploadSpeedFromMcOutput(String output) {
    final speed = McOutputParser.parseSpeed(output);
    if (speed > 0) {
      setUploadSpeed(speed);
    }
  }

  /// 从 mc 输出字符串更新下载速度（单任务模式）
  void updateDownloadSpeedFromMcOutput(String output) {
    final speed = McOutputParser.parseSpeed(output);
    if (speed > 0) {
      setDownloadSpeed(speed);
    }
  }

  /// 从 mc 输出解析完整进度信息并更新上传状态
  McProgressInfo updateUploadFromMcOutput(String output) {
    final info = McOutputParser.parse(output);
    if (info.speed > 0) {
      setUploadSpeed(info.speed);
    }
    return info;
  }

  /// 从 mc 输出解析完整进度信息并更新下载状态
  McProgressInfo updateDownloadFromMcOutput(String output) {
    final info = McOutputParser.parse(output);
    if (info.speed > 0) {
      setDownloadSpeed(info.speed);
    }
    return info;
  }

  /// 标记上传开始（使用 mc 模式）
  void startUpload() {
    _isUploading = true;
    _useDirectUploadSpeed = true;
    _directUploadSpeed = 0;
    notifyListeners();
  }

  /// 标记下载开始（使用 mc 模式）
  void startDownload() {
    _isDownloading = true;
    _useDirectDownloadSpeed = true;
    _directDownloadSpeed = 0;
    notifyListeners();
  }

  /// 上传完成（清理所有上传状态）
  void onUploadComplete() {
    _isUploading = false;
    _smoothedUploadSpeed = 0;
    _directUploadSpeed = 0;
    _useDirectUploadSpeed = false;
    _currentUploadBytes = 0;
    _lastUploadBytes = 0;
    _uploadSpeedHistory.clear();
    _uploadTaskSpeeds.clear();  // ✅ 清理多任务数据
    notifyListeners();
  }

  /// 下载完成（清理所有下载状态）
  void onDownloadComplete() {
    _isDownloading = false;
    _smoothedDownloadSpeed = 0;
    _directDownloadSpeed = 0;
    _useDirectDownloadSpeed = false;
    _currentDownloadBytes = 0;
    _lastDownloadBytes = 0;
    _downloadSpeedHistory.clear();
    _downloadTaskSpeeds.clear();  // ✅ 清理多任务数据
    notifyListeners();
  }

  // ============================================================
  // 私有方法
  // ============================================================

  /// 计算速率（核心算法）
  void _calculateSpeed() {
    // 计算上传速率（仅在非直接模式下）
    if (_isUploading && !_useDirectUploadSpeed) {
      _smoothedUploadSpeed = _calculateSmoothedSpeed(
        currentBytes: _currentUploadBytes,
        lastBytes: _lastUploadBytes,
        history: _uploadSpeedHistory,
        previousSmoothed: _smoothedUploadSpeed,
      );
      _lastUploadBytes = _currentUploadBytes;
    } else if (!_isUploading) {
      _smoothedUploadSpeed = 0;
      _uploadSpeedHistory.clear();
    }

    // 计算下载速率（仅在非直接模式下）
    if (_isDownloading && !_useDirectDownloadSpeed) {
      _smoothedDownloadSpeed = _calculateSmoothedSpeed(
        currentBytes: _currentDownloadBytes,
        lastBytes: _lastDownloadBytes,
        history: _downloadSpeedHistory,
        previousSmoothed: _smoothedDownloadSpeed,
      );
      _lastDownloadBytes = _currentDownloadBytes;
    } else if (!_isDownloading) {
      _smoothedDownloadSpeed = 0;
      _downloadSpeedHistory.clear();
    }

    notifyListeners();
  }

  /// 计算平滑后的速度
  double _calculateSmoothedSpeed({
    required int currentBytes,
    required int lastBytes,
    required Queue<double> history,
    required double previousSmoothed,
  }) {
    // 1. 计算瞬时速度
    final bytesDelta = currentBytes - lastBytes;
    final instantSpeed = (bytesDelta * 1000.0) / _sampleIntervalMs;

    // 忽略负值
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

    // 4. 应用指数移动平均（EMA）
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
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)}MB/s';
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