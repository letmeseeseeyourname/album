// pages/settings_page.dart (添加升级检查功能)
import 'dart:async';
import 'package:ablumwin/network/constant_sign.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../eventbus/event_bus.dart';
import '../eventbus/upgrade_events.dart';
import '../manager/upgrade_manager.dart';
import '../user/my_instance.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends StatefulWidget {
  final bool hasUpdate; // 🆕 新增

  const SettingsPage({
    super.key,
    this.hasUpdate = false, // 🆕 新增
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

  // 🆕 升级状态
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

    // 🆕 初始化升级状态
    _hasUpdate = widget.hasUpdate || UpgradeManager().hasUpdate;

    // 🆕 监听升级事件
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
    _upgradeSubscription?.cancel(); // 🆕 新增
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
          // 🆕 检查更新菜单项显示红点
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
                  // 🆕 红点
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
        return _buildUpdateCheck(); // 🆕 使用新的检查更新组件
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
          // 语言设置
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

          // 下载位置
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

          // 关闭主面板时
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

  // 🆕 重写的检查更新组件
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

// 🆕 检查更新内容组件
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
  bool _hasChecked = false; // 是否已检查过

  @override
  void initState() {
    super.initState();
    _hasUpdate = widget.hasUpdate;
    _loadCachedInfo();
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
      _targetVersion = manager.upgradeInfo!.targetVersion;
      _releaseNotes = manager.upgradeInfo!.releaseNotes;
      // _downloadUrl = '${AppConfig.userUrl()}/'+manager.upgradeInfo!.packageUrl;
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
          _downloadUrl = result.upgradeInfo?.packageUrl;
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

  Future<void> _downloadUpdate() async {
    if (_downloadUrl == null || _downloadUrl!.isEmpty) {
      setState(() => _errorMessage = '下载地址无效');
      return;
    }

    try {
      final uri = Uri.parse(_downloadUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        setState(() => _errorMessage = '无法打开下载链接');
      }
    } catch (e) {
      setState(() => _errorMessage = '打开下载链接失败: $e');
    }
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
            ] else if (_hasUpdate) ...[
              // 有更新
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

              // 更新说明
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

              // 下载更新按钮
              OutlinedButton(
                onPressed: _downloadUpdate,
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
              // 没有更新
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

              // 检测更新按钮
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

            // 错误提示
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
}