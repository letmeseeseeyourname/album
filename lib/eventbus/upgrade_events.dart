// eventbus/upgrade_events.dart
// 升级相关事件

import '../user/models/upgrade_info_model.dart';
import '../manager/upgrade_manager.dart';

/// 升级检查完成事件
class UpgradeCheckEvent {
  final bool hasUpdate;
  final UpgradeInfoModel? upgradeInfo;

  UpgradeCheckEvent({
    required this.hasUpdate,
    this.upgradeInfo,
  });
}

/// 下载进度事件
class DownloadProgressEvent {
  final DownloadProgress progress;

  DownloadProgressEvent({required this.progress});
}