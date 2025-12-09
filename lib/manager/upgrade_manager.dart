// manager/upgrade_manager.dart
// 升级管理器单例 - 包含检查更新、下载、安装完整逻辑

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../eventbus/event_bus.dart';
import '../eventbus/upgrade_events.dart';
import '../user/models/upgrade_info_model.dart';
import '../user/provider/mine_provider.dart';

/// 下载状态枚举
enum DownloadStatus {
  idle,        // 空闲
  downloading, // 下载中
  paused,      // 暂停
  completed,   // 完成
  failed,      // 失败
  installing,  // 安装中
}

/// 下载进度信息
class DownloadProgress {
  final DownloadStatus status;
  final double progress;      // 0.0 - 1.0
  final int downloadedBytes;
  final int totalBytes;
  final String? errorMessage;
  final String? filePath;     // 下载完成后的文件路径

  DownloadProgress({
    required this.status,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
    this.filePath,
  });

  String get progressText {
    if (totalBytes > 0) {
      final downloadedMB = downloadedBytes / (1024 * 1024);
      final totalMB = totalBytes / (1024 * 1024);
      return '${downloadedMB.toStringAsFixed(1)}MB / ${totalMB.toStringAsFixed(1)}MB';
    }
    return '${(downloadedBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String get percentText => '${(progress * 100).toStringAsFixed(1)}%';
}

class UpgradeManager {
  static final UpgradeManager _instance = UpgradeManager._internal();
  factory UpgradeManager() => _instance;
  UpgradeManager._internal();

  // 升级信息
  UpgradeInfoModel? _upgradeInfo;
  bool _hasUpdate = false;
  String _currentVersion = '';
  int _currentVersionCode = 0;
  bool _isInitialized = false;

  // 下载状态
  DownloadProgress _downloadProgress = DownloadProgress(status: DownloadStatus.idle);
  http.Client? _httpClient;
  bool _cancelRequested = false;

  // Getters
  bool get hasUpdate => _hasUpdate;
  UpgradeInfoModel? get upgradeInfo => _upgradeInfo;
  String get currentVersion => _currentVersion;
  int get currentVersionCode => _currentVersionCode;
  DownloadProgress get downloadProgress => _downloadProgress;
  bool get isDownloading => _downloadProgress.status == DownloadStatus.downloading;

  /// 初始化
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;
      _currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      _isInitialized = true;
      debugPrint('UpgradeManager: version=$_currentVersion, buildNumber=$_currentVersionCode');
    } catch (e) {
      debugPrint('UpgradeManager 初始化失败: $e');
    }
  }

  /// 静默检查更新（启动时调用）
  Future<bool> checkUpgradeSilently() async {
    await initialize();

    try {
      final provider = MyNetworkProvider();
      final response = await provider.getUpGradeInfo();

      if (response.isSuccess && response.model != null) {
        _upgradeInfo = response.model;
        final serverVersionCode = response.model!.versionCode;
        _hasUpdate = serverVersionCode > _currentVersionCode;

        debugPrint('检查更新: 服务器versionCode=$serverVersionCode, 本地buildNumber=$_currentVersionCode, hasUpdate=$_hasUpdate');

        MCEventBus.fire(UpgradeCheckEvent(
          hasUpdate: _hasUpdate,
          upgradeInfo: _upgradeInfo,
        ));

        return _hasUpdate;
      } else {
        debugPrint('检查更新失败: ${response.message}');
        _hasUpdate = false;
        return false;
      }
    } catch (e) {
      debugPrint('检查更新异常: $e');
      _hasUpdate = false;
      return false;
    }
  }

  /// 手动检查更新
  Future<UpgradeCheckResult> checkUpgradeManually() async {
    await initialize();

    try {
      final provider = MyNetworkProvider();
      final response = await provider.getUpGradeInfo();

      if (response.isSuccess && response.model != null) {
        _upgradeInfo = response.model;
        final serverVersionCode = response.model!.versionCode;
        _hasUpdate = serverVersionCode > _currentVersionCode;

        MCEventBus.fire(UpgradeCheckEvent(
          hasUpdate: _hasUpdate,
          upgradeInfo: _upgradeInfo,
        ));

        return UpgradeCheckResult(
          success: true,
          hasUpdate: _hasUpdate,
          currentVersion: _currentVersion,
          targetVersion: _upgradeInfo?.targetVersion,
          upgradeInfo: _upgradeInfo,
        );
      } else {
        return UpgradeCheckResult(
          success: false,
          hasUpdate: false,
          currentVersion: _currentVersion,
          errorMessage: response.message ?? '检查更新失败',
        );
      }
    } catch (e) {
      return UpgradeCheckResult(
        success: false,
        hasUpdate: false,
        currentVersion: _currentVersion,
        errorMessage: '网络异常，请稍后重试',
      );
    }
  }

  /// 开始下载更新
  Future<DownloadResult> startDownload({
    required Function(DownloadProgress) onProgress,
  }) async {
    if (_upgradeInfo == null || _upgradeInfo!.packageUrl.isEmpty) {
      return DownloadResult(
        success: false,
        errorMessage: '下载地址无效',
      );
    }

    // 如果已经在下载中，返回
    if (_downloadProgress.status == DownloadStatus.downloading) {
      return DownloadResult(
        success: false,
        errorMessage: '已有下载任务进行中',
      );
    }

    _cancelRequested = false;
    _httpClient = http.Client();

    try {
      final downloadUrl = 'http://joykee-oss.joykee.com/${_upgradeInfo!.packageUrl}';
      debugPrint('开始下载: $downloadUrl');

      // 获取下载目录
      final downloadDir = await _getDownloadDirectory();
      final fileName = _getFileNameFromUrl(downloadUrl);
      final filePath = '${downloadDir.path}${Platform.pathSeparator}$fileName';
      debugPrint('download filePath: $filePath');
      // 检查文件是否已存在
      final file = File(filePath);
      if (await file.exists()) {
        // 如果文件已存在且完整，直接返回成功
        final existingSize = await file.length();
        if (_upgradeInfo!.packageSize > 0 &&
            existingSize >= (_upgradeInfo!.packageSize * 1024 * 1024 * 0.99)) {
          debugPrint('文件已存在且完整: $filePath');
          _updateProgress(DownloadProgress(
            status: DownloadStatus.completed,
            progress: 1.0,
            downloadedBytes: existingSize,
            totalBytes: existingSize,
            filePath: filePath,
          ));
          onProgress(_downloadProgress);
          return DownloadResult(success: true, filePath: filePath);
        }
        // 删除不完整的文件
        await file.delete();
      }

      // 发起 HTTP 请求
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await _httpClient!.send(request);

      if (response.statusCode != 200) {
        throw Exception('下载失败，状态码: ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      var downloadedBytes = 0;

      // 创建文件写入流
      final sink = file.openWrite();

      // 更新状态为下载中
      _updateProgress(DownloadProgress(
        status: DownloadStatus.downloading,
        progress: 0.0,
        downloadedBytes: 0,
        totalBytes: totalBytes,
      ));
      onProgress(_downloadProgress);

      // 读取数据流
      await for (final chunk in response.stream) {
        if (_cancelRequested) {
          await sink.close();
          await file.delete();
          _updateProgress(DownloadProgress(status: DownloadStatus.idle));
          onProgress(_downloadProgress);
          return DownloadResult(
            success: false,
            errorMessage: '下载已取消',
          );
        }

        sink.add(chunk);
        downloadedBytes += chunk.length;

        final progress = totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;
        _updateProgress(DownloadProgress(
          status: DownloadStatus.downloading,
          progress: progress,
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes,
        ));
        onProgress(_downloadProgress);
      }

      await sink.close();

      // 验证文件完整性
      final downloadedFile = File(filePath);
      if (!await downloadedFile.exists()) {
        throw Exception('下载文件不存在');
      }

      final fileSize = await downloadedFile.length();
      if (totalBytes > 0 && fileSize < totalBytes * 0.99) {
        await downloadedFile.delete();
        throw Exception('文件下载不完整');
      }

      // 下载完成
      _updateProgress(DownloadProgress(
        status: DownloadStatus.completed,
        progress: 1.0,
        downloadedBytes: fileSize,
        totalBytes: fileSize,
        filePath: filePath,
      ));
      onProgress(_downloadProgress);

      debugPrint('下载完成: $filePath');
      return DownloadResult(success: true, filePath: filePath);

    } catch (e) {
      debugPrint('下载失败: $e');
      _updateProgress(DownloadProgress(
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      ));
      onProgress(_downloadProgress);
      return DownloadResult(
        success: false,
        errorMessage: '下载失败: $e',
      );
    } finally {
      _httpClient?.close();
      _httpClient = null;
    }
  }

  /// 取消下载
  void cancelDownload() {
    _cancelRequested = true;
    _httpClient?.close();
    _updateProgress(DownloadProgress(status: DownloadStatus.idle));
  }

  /// 安装更新
  Future<InstallResult> installUpdate(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return InstallResult(
          success: false,
          errorMessage: '安装文件不存在',
        );
      }

      _updateProgress(DownloadProgress(
        status: DownloadStatus.installing,
        progress: 1.0,
        filePath: filePath,
      ));

      // Windows 平台执行安装
      if (Platform.isWindows) {
        final ext = filePath.split('.').last.toLowerCase();

        if (ext == 'exe') {
          // 直接运行 exe 安装程序
          debugPrint('启动安装程序: $filePath');
          await Process.start(filePath, [], mode: ProcessStartMode.detached);
        } else if (ext == 'msi') {
          // 使用 msiexec 安装 msi
          debugPrint('启动 MSI 安装: $filePath');
          await Process.start('msiexec', ['/i', filePath], mode: ProcessStartMode.detached);
        } else if (ext == 'zip') {
          // 如果是 zip 文件，提示用户手动解压安装
          return InstallResult(
            success: false,
            errorMessage: '请手动解压安装包进行安装',
            filePath: filePath,
          );
        } else {
          return InstallResult(
            success: false,
            errorMessage: '不支持的安装包格式: $ext',
          );
        }

        // 安装程序已启动，返回成功
        return InstallResult(
          success: true,
          filePath: filePath,
          message: '安装程序已启动，请按提示完成安装',
        );
      } else {
        return InstallResult(
          success: false,
          errorMessage: '当前平台不支持自动安装',
        );
      }
    } catch (e) {
      debugPrint('安装失败: $e');
      _updateProgress(DownloadProgress(
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      ));
      return InstallResult(
        success: false,
        errorMessage: '安装失败: $e',
      );
    }
  }

  /// 打开文件所在目录
  Future<void> openDownloadDirectory(String filePath) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', filePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', filePath]);
      } else if (Platform.isLinux) {
        final directory = File(filePath).parent.path;
        await Process.run('xdg-open', [directory]);
      }
    } catch (e) {
      debugPrint('打开目录失败: $e');
    }
  }

  /// 获取下载目录
  Future<Directory> _getDownloadDirectory() async {
    Directory? downloadDir;

    if (Platform.isWindows) {
      // Windows 优先使用下载文件夹
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        downloadDir = Directory('$userProfile\\Downloads');
      }
    }

    // 备用：使用应用临时目录
    downloadDir ??= await getTemporaryDirectory();
    downloadDir = Directory('${downloadDir.path}${Platform.pathSeparator}qinxuan_updates');

    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    return downloadDir;
  }

  /// 从 URL 提取文件名
  String _getFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final fileName = pathSegments.last;
        if (fileName.contains('.')) {
          return fileName;
        }
      }
    } catch (e) {
      debugPrint('解析文件名失败: $e');
    }

    // 默认文件名
    final version = _upgradeInfo?.targetVersion ?? 'latest';
    return 'qinxuan_album_$version.exe';
  }

  void _updateProgress(DownloadProgress progress) {
    _downloadProgress = progress;
    // 发送下载进度事件
    MCEventBus.fire(DownloadProgressEvent(progress: progress));
  }

  /// 重置下载状态
  void resetDownloadStatus() {
    _downloadProgress = DownloadProgress(status: DownloadStatus.idle);
  }

  /// 清除缓存
  void clearCache() {
    _upgradeInfo = null;
    _hasUpdate = false;
    _isInitialized = false;
    _downloadProgress = DownloadProgress(status: DownloadStatus.idle);
  }
}

/// 升级检查结果
class UpgradeCheckResult {
  final bool success;
  final bool hasUpdate;
  final String currentVersion;
  final String? targetVersion;
  final UpgradeInfoModel? upgradeInfo;
  final String? errorMessage;

  UpgradeCheckResult({
    required this.success,
    required this.hasUpdate,
    required this.currentVersion,
    this.targetVersion,
    this.upgradeInfo,
    this.errorMessage,
  });
}

/// 下载结果
class DownloadResult {
  final bool success;
  final String? filePath;
  final String? errorMessage;

  DownloadResult({
    required this.success,
    this.filePath,
    this.errorMessage,
  });
}

/// 安装结果
class InstallResult {
  final bool success;
  final String? filePath;
  final String? message;
  final String? errorMessage;

  InstallResult({
    required this.success,
    this.filePath,
    this.message,
    this.errorMessage,
  });
}