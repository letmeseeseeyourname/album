// pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../user/my_instance.dart';
import 'package:package_info_plus/package_info_plus.dart';
// import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _selectedMenuIndex = 0;
  String _downloadPath = '';
  bool _minimizeOnClose = true;
  String _currentVersion = '';
  bool _isCheckingUpdate = false;
  UpdateInfo? _updateInfo;
  bool _isLoadingPath = true;

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
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoadingPath = true;
    });

    try {
      // 使用 MyInstance 获取下载路径（会自动返回默认路径如果没有设置）
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

  Future<void> _checkForUpdates() async {
    setState(() {
      _isCheckingUpdate = true;
      _updateInfo = null;
    });

    try {
      // TODO: 调用实际的更新检查 API
      // 这里是模拟实现
      await Future.delayed(const Duration(seconds: 2));

      // 模拟获取更新信息
      final hasUpdate = false; // 从服务器获取

      setState(() {
        _updateInfo = UpdateInfo(
          hasUpdate: hasUpdate,
          version: hasUpdate ? 'v1.1.2' : _currentVersion,
          size: '485 MB',
          description: '本更新引入了8个全新功能和分类，增强了照片功能以便更好地整理和筛选图库，以及包括对相册的其他功能、错误修复和安全更新',
          downloadUrl: 'https://example.com/download',
        );
        _isCheckingUpdate = false;
      });
    } catch (e) {
      setState(() {
        _isCheckingUpdate = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查更新失败: $e')),
        );
      }
    }
  }

  Future<void> _downloadUpdate() async {
    // if (_updateInfo?.downloadUrl != null) {
    //   final uri = Uri.parse(_updateInfo!.downloadUrl);
    //   if (await canLaunchUrl(uri)) {
    //     await launchUrl(uri);
    //   }
    // }
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
            // 标题栏
            _buildTitleBar(),
            // 主内容
            Expanded(
              child: Row(
                children: [
                  // 左侧菜单
                  _buildLeftMenu(),
                  // 右侧内容
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
              title: Text(
                item.title,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
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
              onChanged: (value) {
                // TODO: 实现语言切换
              },
            ),
          ),

          const SizedBox(height: 24),

          // 下载位置
          _buildSettingRow(
            '下载位置',
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
          ),

          const SizedBox(height: 8),

          // 提示信息
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

  Widget _buildUpdateCheck() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isCheckingUpdate) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text('正在检查更新...'),
            ] else if (_updateInfo == null) ...[
              ElevatedButton(
                onPressed: _checkForUpdates,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                ),
                child: const Text('检查更新'),
              ),
            ] else if (_updateInfo!.hasUpdate) ...[
              const Text(
                '检测到可更新版本',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _updateInfo!.version,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _updateInfo!.size,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Text(
                  _updateInfo!.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _downloadUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 64,
                    vertical: 16,
                  ),
                ),
                child: const Text('立即更新'),
              ),
            ] else ...[
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
              const SizedBox(height: 32),
              const Text(
                '你使用的是最新版本的亲选相册，当前没有更新需要安装\n感谢你的使用！',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAbout() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo
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

class UpdateInfo {
  final bool hasUpdate;
  final String version;
  final String size;
  final String description;
  final String downloadUrl;

  UpdateInfo({
    required this.hasUpdate,
    required this.version,
    required this.size,
    required this.description,
    required this.downloadUrl,
  });
}