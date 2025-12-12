// pages/settings_page.dart (完善升级功能 - 包含下载进度和安装)
import 'dart:async';
import 'package:ablumwin/network/constant_sign.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../eventbus/event_bus.dart';
import '../eventbus/upgrade_events.dart' hide DownloadProgressEvent;
import '../eventbus/download_events.dart'; // 新增：导入下载事件
import '../manager/upgrade_manager.dart';
import '../user/my_instance.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends StatefulWidget {
  final bool hasUpdate;

  const SettingsPage({
    super.key,
    this.hasUpdate = false,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _selectedMenuIndex = 0;
  String _downloadPath = '';
  bool _minimizeOnClose = true;
  String _currentVersion = '';
  bool _isLoadingPath = true;

  bool _hasUpdate = false;
  StreamSubscription? _upgradeSubscription;

  final List<_MenuItem> _menuItems = [
    _MenuItem('常用设置', Icons.settings),
    _MenuItem('检查更新', Icons.system_update),
    _MenuItem('关于', Icons.info_outline),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadVersion();

    _hasUpdate = widget.hasUpdate || UpgradeManager().hasUpdate;

    _upgradeSubscription = MCEventBus.on<UpgradeCheckEvent>().listen((event) {
      if (mounted) {
        setState(() {
          _hasUpdate = event.hasUpdate;
        });
      }
    });
  }

  @override
  void dispose() {
    _upgradeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoadingPath = true;
    });

    try {
      final downloadPath = await MyInstance().getDownloadPath();
      final minimizeOnClose = await MyInstance().getMinimizeOnClose();

      setState(() {
        _downloadPath = downloadPath;
        _minimizeOnClose = minimizeOnClose;
        _isLoadingPath = false;
      });
    } catch (e) {
      debugPrint('加载设置失败: $e');
      setState(() {
        _isLoadingPath = false;
      });
    }
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _currentVersion = packageInfo.version;
    });
  }

  Future<void> _selectDownloadPath() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      setState(() {
        _downloadPath = selectedDirectory;
      });
      await MyInstance().setDownloadPath(selectedDirectory);

      // 发送下载路径变更事件
      MCEventBus.fire(DownloadPathChangedEvent(selectedDirectory));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载路径已更改为: $selectedDirectory'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 900,
        height: 600,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _buildTitleBar(),
            Expanded(
              child: Row(
                children: [
                  _buildLeftMenu(),
                  Expanded(
                    child: _buildContent(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          const Text(
            '设置',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftMenu() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          right: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: _menuItems.length,
        itemBuilder: (context, index) {
          final item = _menuItems[index];
          final isSelected = _selectedMenuIndex == index;
          final showBadge = index == 1 && _hasUpdate;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: Icon(
                item.icon,
                color: isSelected ? Colors.black : Colors.grey,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.grey.shade700,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (showBadge)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              selected: isSelected,
              onTap: () {
                setState(() {
                  _selectedMenuIndex = index;
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedMenuIndex) {
      case 0:
        return _buildGeneralSettings();
      case 1:
        return _buildUpdateCheck();
      case 2:
        return _buildAbout();
      default:
        return const SizedBox();
    }
  }

  Widget _buildGeneralSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingRow(
            '语言',
            DropdownButton<String>(
              value: '中文',
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: '中文', child: Text('中文')),
                DropdownMenuItem(value: 'English', child: Text('English')),
              ],
              onChanged: (value) {},
            ),
          ),

          const SizedBox(height: 32),

          const Text(
            '下载位置',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _isLoadingPath
                    ? const Text(
                  '加载中...',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                )
                    : Text(
                  _downloadPath,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: _selectDownloadPath,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('浏览'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            '如果没有设置，将默认保存到系统下载文件夹中的"亲选相册"目录',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),

          const SizedBox(height: 32),

          const Text(
            '关闭主面板时',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          RadioListTile<bool>(
            value: true,
            groupValue: _minimizeOnClose,
            title: const Text('最小化系统托盘，不退出程序'),
            onChanged: (value) async {
              setState(() {
                _minimizeOnClose = true;
              });
              await MyInstance().setMinimizeOnClose(true);
            },
          ),

          RadioListTile<bool>(
            value: false,
            groupValue: _minimizeOnClose,
            title: const Text('退出程序'),
            onChanged: (value) async {
              setState(() {
                _minimizeOnClose = false;
              });
              await MyInstance().setMinimizeOnClose(false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateCheck() {
    return UpdateCheckContent(
      hasUpdate: _hasUpdate,
      onUpdateChecked: (hasUpdate) {
        setState(() {
          _hasUpdate = hasUpdate;
        });
      },
    );
  }

  Widget _buildAbout() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.home,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '亲选相册',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '当前版本：$_currentVersion',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 48),
          Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: const Text(
              '通过智能管理，无感分享与AI创作，让家庭相册更安全有序、回忆更精彩动人\n创造更智慧幸福的家庭生活',
              style: TextStyle(
                fontSize: 14,
                height: 1.8,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, Widget trailing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 32),
        Expanded(child: trailing),
      ],
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;

  _MenuItem(this.title, this.icon);
}

// 检查更新内容组件 - 包含下载进度和安装（保留原有文案）
class UpdateCheckContent extends StatefulWidget {
  final bool hasUpdate;
  final Function(bool)? onUpdateChecked;

  const UpdateCheckContent({
    super.key,
    this.hasUpdate = false,
    this.onUpdateChecked,
  });

  @override
  State<UpdateCheckContent> createState() => _UpdateCheckContentState();
}

class _UpdateCheckContentState extends State<UpdateCheckContent> {
  bool _isChecking = false;
  bool _hasUpdate = false;
  String _currentVersion = '';
  String _targetVersion = '';
  String _releaseNotes = '';
  String? _downloadUrl;
  String? _errorMessage;
  bool _hasChecked = false;

  DownloadProgress _downloadProgress = DownloadProgress(status: DownloadStatus.idle);
  StreamSubscription? _downloadSubscription;

  @override
  void initState() {
    super.initState();
    _hasUpdate = widget.hasUpdate;
    _loadCachedInfo();

    _downloadSubscription = MCEventBus.on<DownloadProgressEvent>().listen((event) {
      if (mounted) {
        setState(() {
          _downloadProgress = event.progress as DownloadProgress;
        });
      }
    });

    _downloadProgress = UpgradeManager().downloadProgress;
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  void _loadCachedInfo() {
    final manager = UpgradeManager();
    _currentVersion = manager.currentVersion;
    if (_currentVersion.isEmpty) {
      PackageInfo.fromPlatform().then((info) {
        if (mounted) {
          setState(() {
            _currentVersion = info.version;
          });
        }
      });
    }
    if (manager.upgradeInfo != null) {
      _hasChecked = true;
      _hasUpdate = manager.hasUpdate;
      _targetVersion = manager.upgradeInfo!.targetVersion;
      _releaseNotes = manager.upgradeInfo!.releaseNotes;
      _downloadUrl = 'http://joykee-oss.joykee.com/${manager.upgradeInfo!.packageUrl}';
    }
  }

  Future<void> _checkUpdate() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    try {
      final result = await UpgradeManager().checkUpgradeManually();

      if (mounted) {
        setState(() {
          _isChecking = false;
          _hasChecked = true;
          _hasUpdate = result.hasUpdate;
          _currentVersion = result.currentVersion;
          _targetVersion = result.targetVersion ?? '';
          _releaseNotes = result.upgradeInfo?.releaseNotes ?? '';
          _downloadUrl = 'http://joykee-oss.joykee.com/${result.upgradeInfo!.packageUrl}';
          _errorMessage = result.success ? null : result.errorMessage;
        });

        widget.onUpdateChecked?.call(result.hasUpdate);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _hasChecked = true;
          _errorMessage = '检查更新失败，请稍后重试';
        });
      }
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _errorMessage = null;
    });

    final result = await UpgradeManager().startDownload(
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
          });
        }
      },
    );

    if (!result.success && mounted) {
      setState(() {
        _errorMessage = result.errorMessage;
      });
    } else if (result.success && result.filePath != null) {
      _startInstall(result.filePath!);
    }
  }

  void _cancelDownload() {
    UpgradeManager().cancelDownload();
    setState(() {
      _downloadProgress = DownloadProgress(status: DownloadStatus.idle);
    });
  }

  Future<void> _startInstall(String filePath) async {
    final result = await UpgradeManager().installUpdate(filePath);

    if (mounted) {
      if (result.success) {
        _showInstallStartedDialog(result.message ?? '安装程序已启动');
      } else {
        _showInstallFailedDialog(result.errorMessage ?? '安装失败', filePath);
      }
    }
  }

  void _showInstallStartedDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('安装已启动'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            const Text(
              '安装完成后，请重新启动应用以使用新版本。',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showInstallFailedDialog(String errorMessage, String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('无法自动安装'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage),
            const SizedBox(height: 16),
            const Text(
              '您可以手动打开下载目录进行安装。',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              UpgradeManager().openDownloadDirectory(filePath);
            },
            child: const Text('打开目录'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),

            // 根据状态显示不同内容
            if (_isChecking) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text('正在检查更新...'),
            ] else if (_downloadProgress.status == DownloadStatus.downloading) ...[
              _buildDownloadingView(),
            ] else if (_downloadProgress.status == DownloadStatus.completed) ...[
              _buildDownloadCompletedView(),
            ] else if (_downloadProgress.status == DownloadStatus.installing) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text('正在启动安装程序...'),
            ] else if (_downloadProgress.status == DownloadStatus.failed) ...[
              _buildDownloadFailedView(),
            ] else if (_hasUpdate) ...[
              // 有更新 - 保留原有文案
              const Text(
                '发现新版本',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '更新版本：$_targetVersion',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '发现新版本，建议立即更新以获得更好的体验',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),

              if (_releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  constraints: const BoxConstraints(maxWidth: 500, maxHeight: 120),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      '更新内容：\n$_releaseNotes',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              OutlinedButton(
                onPressed: _startDownload,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  side: const BorderSide(color: Colors.blue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '下载更新',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
              ),
            ] else ...[
              // 没有更新 - 保留原有文案
              const Text(
                '当前没有更新需要安装',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '当前版本：$_currentVersion',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '你使用的是最新版本的亲选相册，当前没有更新需要安装\n感谢你的使用！',
                style: TextStyle(fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              OutlinedButton(
                onPressed: _checkUpdate,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '检测更新',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.red,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadingView() {
    return Column(
      children: [
        const Text(
          '正在下载更新',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '更新版本：$_targetVersion',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 32),

        Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _downloadProgress.progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _downloadProgress.progressText,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    _downloadProgress.percentText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        OutlinedButton(
          onPressed: _cancelDownload,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            side: BorderSide(color: Colors.grey.shade400),
          ),
          child: Text(
            '取消下载',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),

        const SizedBox(height: 16),
        Text(
          '下载过程中请勿关闭应用',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadCompletedView() {
    return Column(
      children: [
        const Icon(
          Icons.check_circle,
          size: 64,
          color: Colors.green,
        ),
        const SizedBox(height: 24),
        const Text(
          '下载完成',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '版本 $_targetVersion 已准备就绪',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 32),

        OutlinedButton(
          onPressed: () {
            if (_downloadProgress.filePath != null) {
              _startInstall(_downloadProgress.filePath!);
            }
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 48,
              vertical: 16,
            ),
            side: const BorderSide(color: Colors.blue),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            '立即安装',
            style: TextStyle(
              fontSize: 16,
              color: Colors.blue,
            ),
          ),
        ),

        const SizedBox(height: 16),

        TextButton(
          onPressed: () {
            if (_downloadProgress.filePath != null) {
              UpgradeManager().openDownloadDirectory(_downloadProgress.filePath!);
            }
          },
          child: Text(
            '打开下载目录',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadFailedView() {
    return Column(
      children: [
        Icon(
          Icons.error_outline,
          size: 64,
          color: Colors.red.shade400,
        ),
        const SizedBox(height: 24),
        const Text(
          '下载失败',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _downloadProgress.errorMessage ?? '请检查网络连接后重试',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: () {
                UpgradeManager().resetDownloadStatus();
                setState(() {
                  _downloadProgress = DownloadProgress(status: DownloadStatus.idle);
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              child: Text(
                '返回',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            const SizedBox(width: 16),
            OutlinedButton(
              onPressed: _startDownload,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                side: const BorderSide(color: Colors.blue),
              ),
              child: const Text(
                '重试',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
      ],
    );
  }
}