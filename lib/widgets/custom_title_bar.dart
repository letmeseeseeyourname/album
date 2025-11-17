// widgets/custom_title_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:window_manager/window_manager.dart';
import 'package:ablumwin/user/my_instance.dart';
import '../network/constant_sign.dart';
import '../pages/settings_page.dart';  // 新增导入
import '../pages/upload_records_page.dart';  // 新增导入传输记录页面

class CustomTitleBar extends StatefulWidget {
  final Widget? child;
  final bool showToolbar; // 是否显示工具栏内容
  final VoidCallback? onAddFolder; // 添加文件夹回调
  final Color? backgroundColor;
  final Color? rightTitleBgColor;

  const CustomTitleBar({
    super.key,
    this.child,
    this.showToolbar = false,
    this.onAddFolder,
    this.backgroundColor = Colors.white,
    this.rightTitleBgColor = Colors.white,
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

  // 获取用户头像URL
  String? _getUserAvatarUrl() {
    final user = MyInstance().user?.user;
    if (user?.headUrl != null && user!.headUrl!.isNotEmpty) {
      return '${AppConfig.avatarURL()}/${user.headUrl}';
    }
    return null;
  }

  // 构建头像Widget
  Widget _buildAvatar() {
    final avatarUrl = _getUserAvatarUrl();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20), // 圆形头像
      child: avatarUrl != null
          ? Image.network(
        avatarUrl,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // 加载失败时显示默认头像
          return Image.asset(
            'assets/images/avatar.png',
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          // 加载中显示默认头像
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

  // 🆕 打开设置对话框
  void _openSettings() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => const SettingsPage(),
    );
  }

  // 🆕 打开传输记录页面
  void _openUploadRecords() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => const UploadRecordsPage(),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 自定义标题栏
        Container(
          height: widget.showToolbar ? 80 : 40,
          decoration: BoxDecoration(color: widget.backgroundColor), //0xFFF5E8DC
          child: Row(
            children: [
              // 左侧区域 - 与侧边栏同宽，背景色相同
              Container(
                width: 170,
                color: Colors.transparent, //0xFFF5E8DC
                child: widget.showToolbar
                    ? GestureDetector(
                  onPanStart: (details) {
                    // 启动窗口拖动
                    windowManager.startDragging();
                  },
                  child: Container(
                    //如果 Container 没有设置 color 或 decoration，它会尝试将自身缩小到其子组件，所以会导致拖动事件只在子元素上，元素以外的区域不会响应
                    color: Colors.transparent,
                    height: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // 应用名称
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
                        // Logo/用户头像
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: _buildAvatar(),
                        ),
                      ],
                    ),
                  ),
                )
                    : GestureDetector(
                  onPanStart: (details) {
                    // 启动窗口拖动
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
              // 右侧区域 - 可拖动区域和功能按钮
              Expanded(
                child: Container(
                  color: widget.rightTitleBgColor, //Colors.white
                  child: Row(
                    children: [
                      // 可拖动区域或工具栏内容
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
                                // 添加文件夹按钮
                                ElevatedButton.icon(
                                  onPressed: widget.onAddFolder,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('添加文件夹'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                    side: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                const SizedBox(width: 16),
                                // 设置按钮 - 🆕 添加点击事件
                                IconButton(
                                  icon: SvgPicture.asset(
                                    'assets/icons/setting_icon.svg',
                                    width: 20,
                                    height: 20,
                                  ),
                                  onPressed: _openSettings,  // 🆕 打开设置
                                  iconSize: 24,
                                  tooltip: '设置',
                                ),
                                const SizedBox(width: 8),
                                // 传输按钮
                                IconButton(
                                  icon: SvgPicture.asset(
                                    'assets/icons/transmission_icon.svg',
                                    width: 20,
                                    height: 20,
                                  ),
                                  onPressed: _openUploadRecords,  // 🆕 打开传输记录
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
                          // 🆕 根据设置决定是最小化还是关闭
                          final minimizeOnClose = await MyInstance().getMinimizeOnClose();
                          if (minimizeOnClose) {
                            // 最小化到托盘
                            await windowManager.hide();
                          } else {
                            // 退出程序
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

        // 内容区域
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
          color: isHovered
              ? (widget.isClose ? Colors.red : Colors.grey.shade200)
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 16,
            color: isHovered && widget.isClose ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}