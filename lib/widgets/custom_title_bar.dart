// widgets/custom_title_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:window_manager/window_manager.dart';

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
    this.backgroundColor =  Colors.white,
    this.rightTitleBgColor =  Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 自定义标题栏
        Container(
          height: widget.showToolbar ? 80 : 40,
          decoration:  BoxDecoration(color: widget.backgroundColor),//0xFFF5E8DC
          child: Row(
            children: [
              // 左侧区域 - 与侧边栏同宽，背景色相同
              Container(
                width: 220,
                color: Colors.transparent,//0xFFF5E8DC
                child: widget.showToolbar
                    ? Padding(
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
                      // Logo
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: Image.asset('assets/images/avatar.png'),
                      ),
                    ],
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

              // 右侧区域 - 可拖动区域和功能按钮
              Expanded(
                child: Container(
                  color: widget.rightTitleBgColor,//Colors.white
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
                                // 设置按钮
                                IconButton(
                                  icon: SvgPicture.asset(
                                    'assets/icons/setting_icon.svg',
                                    width: 20,
                                    height: 20,
                                  ),
                                  onPressed: () {},
                                  iconSize: 24,
                                ),
                                const SizedBox(width: 8),
                                // 传输按钮
                                IconButton(
                                  icon: SvgPicture.asset(
                                    'assets/icons/transmission_icon.svg',
                                    width: 20,
                                    height: 20,
                                  ),
                                  onPressed: () {},
                                  iconSize: 24,
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
                          await windowManager.close();
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