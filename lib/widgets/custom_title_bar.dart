// widgets/custom_title_bar.dart (修改版 - 支持Tab栏和传输速率显示)
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:window_manager/window_manager.dart';
import 'package:ablumwin/user/my_instance.dart';
import '../network/constant_sign.dart';
import '../pages/settings_page.dart';
import '../pages/upload_records_page.dart';
import '../pages/user_info_page.dart';
import '../services/transfer_speed_service.dart';

class CustomTitleBar extends StatefulWidget {
  final Widget? child;
  final bool showToolbar;
  final VoidCallback? onAddFolder;
  final Color? backgroundColor;
  final Color? rightTitleBgColor;

  // 🆕 Tab相关参数
  final bool showTabs; // 是否显示Tab栏（true=Tab栏, false=添加文件夹）
  final int? currentTabIndex; // 当前Tab索引
  final Function(int)? onTabChanged; // Tab切换回调

  const CustomTitleBar({
    super.key,
    this.child,
    this.showToolbar = false,
    this.onAddFolder,
    this.backgroundColor = Colors.white,
    this.rightTitleBgColor = Colors.white,
    this.showTabs = false,  // 默认不显示Tab栏
    this.currentTabIndex = 0,  // 默认选中第一个Tab
    this.onTabChanged,
  });

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> {
  bool isMaximized = false;

  @override
  void initState() {
    super.initState();
    _checkMaximized();
  }

  Future<void> _checkMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (mounted) {
      setState(() {
        isMaximized = maximized;
      });
    }
  }

  String? _getUserAvatarUrl() {
    final user = MyInstance().user?.user;
    if (user?.headUrl != null && user!.headUrl!.isNotEmpty) {
      return '${AppConfig.avatarURL()}/${user.headUrl}';
    }
    return null;
  }

  Widget _buildAvatar() {
    final avatarUrl = _getUserAvatarUrl();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: avatarUrl != null
          ? Image.network(
        avatarUrl,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/images/avatar.png',
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Image.asset(
            'assets/images/avatar.png',
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          );
        },
      )
          : Image.asset(
        'assets/images/avatar.png',
        width: 40,
        height: 40,
        fit: BoxFit.cover,
      ),
    );
  }

  void _openSettings() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => const SettingsPage(),
    );
  }

  void _openUploadRecords() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UploadRecordsPage(),
      ),
    );
  }

  void _openUserInfo() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => const UserInfoPage(),
    );
  }

  // 🆕 构建Tab栏
  Widget _buildTabBar() {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabButton(
            label: '个人',
            isSelected: widget.currentTabIndex == 0,
            onTap: () => widget.onTabChanged?.call(0),
          ),
          const SizedBox(width: 2),
          _buildTabButton(
            label: '家庭',
            isSelected: widget.currentTabIndex == 1,
            onTap: () => widget.onTabChanged?.call(1),
          ),
        ],
      ),
    );
  }

  // 🆕 构建单个Tab按钮
  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: widget.showToolbar ? 80 : 40,
          decoration: BoxDecoration(color: widget.backgroundColor),
          child: Row(
            children: [
              // 左侧区域
              Container(
                width: 170,
                color: Colors.transparent,
                child: widget.showToolbar
                    ? GestureDetector(
                  onPanStart: (details) {
                    windowManager.startDragging();
                  },
                  child: Container(
                    color: Colors.transparent,
                    height: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '亲选相册',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: _openUserInfo,
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: _buildAvatar(),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    : GestureDetector(
                  onPanStart: (details) {
                    windowManager.startDragging();
                  },
                  onDoubleTap: () async {
                    if (isMaximized) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                    await _checkMaximized();
                  },
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: SvgPicture.asset(
                            'assets/icons/home_icon.svg',
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '亲选相册',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 右侧区域
              Expanded(
                child: Container(
                  color: widget.rightTitleBgColor,
                  child: Row(
                    children: [
                      Expanded(
                        child: widget.showToolbar
                            ? GestureDetector(
                          onPanStart: (details) {
                            windowManager.startDragging();
                          },
                          onDoubleTap: () async {
                            if (isMaximized) {
                              await windowManager.unmaximize();
                            } else {
                              await windowManager.maximize();
                            }
                            await _checkMaximized();
                          },
                          child: Container(
                            height: 80,
                            color: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            child: Row(
                              children: [
                                // 🆕 根据showTabs显示Tab栏或添加文件夹按钮
                                if (widget.showTabs)
                                  _buildTabBar()
                                else
                                  ElevatedButton.icon(
                                    onPressed: widget.onAddFolder,
                                    icon: SvgPicture.asset(
                                      'assets/icons/add_folder.svg',
                                      width: 20,
                                      height: 20,
                                    ),
                                    label: const Text('添加文件夹'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF5F5F5),
                                      foregroundColor: Colors.black,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                const Spacer(),

                                // 传输速率显示
                                TransferSpeedIndicator(
                                  speedService: TransferSpeedService.instance,
                                ),

                                const SizedBox(width: 16),
                                IconButton(
                                  icon: SvgPicture.asset(
                                    'assets/icons/setting_icon.svg',
                                    width: 20,
                                    height: 20,
                                  ),
                                  onPressed: _openSettings,
                                  iconSize: 24,
                                  tooltip: '设置',
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: SvgPicture.asset(
                                    'assets/icons/transmission_icon.svg',
                                    width: 20,
                                    height: 20,
                                  ),
                                  onPressed: _openUploadRecords,
                                  iconSize: 24,
                                  tooltip: '传输',
                                ),
                              ],
                            ),
                          ),
                        )
                            : GestureDetector(
                          onPanStart: (details) {
                            windowManager.startDragging();
                          },
                          onDoubleTap: () async {
                            if (isMaximized) {
                              await windowManager.unmaximize();
                            } else {
                              await windowManager.maximize();
                            }
                            await _checkMaximized();
                          },
                          child: Container(color: Colors.transparent),
                        ),
                      ),

                      // 窗口控制按钮
                      WindowControlButton(
                        icon: Icons.minimize,
                        onPressed: () async {
                          await windowManager.minimize();
                        },
                      ),
                      WindowControlButton(
                        icon: isMaximized
                            ? Icons.fullscreen_exit
                            : Icons.crop_square,
                        onPressed: () async {
                          if (isMaximized) {
                            await windowManager.unmaximize();
                          } else {
                            await windowManager.maximize();
                          }
                          await _checkMaximized();
                        },
                      ),
                      WindowControlButton(
                        icon: Icons.close,
                        onPressed: () async {
                          final minimizeOnClose = await MyInstance().getMinimizeOnClose();
                          if (minimizeOnClose) {
                            await windowManager.hide();
                          } else {
                            await windowManager.close();
                          }
                        },
                        isClose: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        if (widget.child != null) Expanded(child: widget.child!),
      ],
    );
  }
}

class WindowControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  const WindowControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  State<WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<WindowControlButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 80,
          alignment: Alignment.center,
          color: isHovered
              ? (widget.isClose ? Colors.red : Colors.grey.shade200)
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 20,
            color: isHovered && widget.isClose ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}