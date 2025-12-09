// managers/upgrade_manager.dart
// 升级管理器单例

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../eventbus/event_bus.dart';
import '../eventbus/upgrade_events.dart';
import '../user/models/upgrade_info_model.dart';
import '../user/provider/mine_provider.dart';

class UpgradeManager {
  static final UpgradeManager _instance = UpgradeManager._internal();
  factory UpgradeManager() => _instance;
  UpgradeManager._internal();

  UpgradeInfoModel? _upgradeInfo;
  bool _hasUpdate = false;
  String _currentVersion = '';
  int _currentVersionCode = 0;
  bool _isInitialized = false;

  bool get hasUpdate => _hasUpdate;
  UpgradeInfoModel? get upgradeInfo => _upgradeInfo;
  String get currentVersion => _currentVersion;
  int get currentVersionCode => _currentVersionCode;

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

  void clearCache() {
    _upgradeInfo = null;
    _hasUpdate = false;
    _isInitialized = false;
  }
}

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