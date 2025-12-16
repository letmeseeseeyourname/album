import 'package:flutter/material.dart';
import '../main.dart';

class GlobalSnackBar{
  /// 显示成功消息的 SnackBar
  static void showSuccess(String message, {Duration duration = const Duration(seconds: 2)}) {
    _showSnackBar(
      message,
      Colors.green,
      duration: duration,
      icon: Icons.check_circle_outline,
    );
  }

  /// 显示失败/错误消息的 SnackBar
  static void showError(String message, {Duration duration = const Duration(seconds: 3)}) {
    _showSnackBar(
      message,
      Colors.red,
      duration: duration,
      icon: Icons.error_outline,
    );
  }

  /// 显示普通信息的 SnackBar (例如正在处理中)
  static void showInfo(String message, {Duration duration = const Duration(seconds: 2)}) {
    _showSnackBar(
      message,
      Colors.blueGrey,
      duration: duration,
      icon: Icons.info_outline,
    );
  }

  /// 核心私有方法：处理 SnackBar 显示逻辑
  static void _showSnackBar(
      String message,
      Color backgroundColor, {
        Duration duration = const Duration(seconds: 2),
        IconData? icon,
      }) {
    // 1. 通过全局 key 获取 ScaffoldMessengerState
    final messenger = snackBarKey.currentState;

    if (messenger != null) {
      // 2. 清除当前 SnackBar，确保新消息能立刻显示
      messenger.hideCurrentSnackBar();

      // 3. 显示新的 SnackBar
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 12),
              ],
              // 使用 Flexible 防止文本过长溢出
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          duration: duration,
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating, // 桌面应用推荐使用浮动模式
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        ),
      );
    }
  }
}