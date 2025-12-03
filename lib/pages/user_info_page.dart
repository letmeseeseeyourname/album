// pages/user_info_page.dart
import 'package:flutter/material.dart';
import 'package:ablumwin/user/my_instance.dart';
import 'package:ablumwin/services/login_service.dart';
import 'package:ablumwin/network/constant_sign.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../album/database/database_helper.dart';
import '../album/database/upload_task_db_helper.dart';
import '../services/folder_manager.dart';
import 'login_page.dart';

class UserInfoPage extends StatefulWidget {
  const UserInfoPage({super.key});

  @override
  State<UserInfoPage> createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {
  bool _isLoggingOut = false;

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
      borderRadius: BorderRadius.circular(50),
      child: avatarUrl != null
          ? Image.network(
        avatarUrl,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/images/avatar.png',
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Image.asset(
            'assets/images/avatar.png',
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          );
        },
      )
          : Image.asset(
        'assets/images/avatar.png',
        width: 100,
        height: 100,
        fit: BoxFit.cover,
      ),
    );
  }

  // 获取用户信息
  Map<String, String> _getUserInfo() {
    final user = MyInstance().user?.user;
    final group = MyInstance().group;
    final deviceInfo = MyInstance().p6deviceInfoModel;

    return {
      '用户名': user?.nickName ?? '未知',
      '手机号': user?.mobile ?? '未知',
      '用户ID': user?.id?.toString() ?? '未知',
      '当前设备': MyInstance().deviceCode.isNotEmpty
          ? MyInstance().deviceCode
          : '未绑定',
      '当前群组': group?.groupName ?? '未选择',
      '群组ID': group?.groupId?.toString() ?? '未知',
      '存储空间': deviceInfo != null
          ? '${_formatBytes(deviceInfo.ttlUsed?.toInt() ?? 0)} / ${_formatBytes(deviceInfo.ttlAll?.toInt() ?? 0)}'
          : '未知',
    };
  }

  // 格式化字节大小
  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '${bytes}GB';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
    }
  }

  // 显示退出登录确认对话框
  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('是否确认退出登录？\n\n退出后将清除所有本地数据，包括：\n• 用户信息\n• 文件记录\n• 上传/下载任务\n• 文件夹列表\n• 缓存数据\n• P2P连接'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认退出'),
          ),
        ],
      ),
    );
  }

  // 处理退出登录
  Future<void> _handleLogout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      // 🆕 0. 断开P2P连接（优先执行）
      await _disconnectP2pConnection();

      // 1. 调用登出接口
      await LoginService.logout();

      // 2. 清除数据库数据
      await _clearDatabaseData();

      // 3. 清除文件夹列表
      await _clearFolderData();

      // 4. 清除网络缓存
      await _clearNetworkCache();

      // 5. 清除 MyInstance 中的数据
      await _clearMyInstanceData();

      // 6. 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('退出登录成功'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // 7. 延迟后跳转到登录页
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        // 关闭用户信息对话框
        Navigator.of(context).pop();

        // 跳转到登录页，清除所有导航历史
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _isLoggingOut = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('退出登录失败：${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🆕 断开P2P连接
  Future<void> _disconnectP2pConnection() async {
    try {
      debugPrint('🔌 开始断开P2P连接...');
      final result = await MyInstance().mineProvider.disconnectP2p();
      if (result) {
        debugPrint('✅ P2P连接已断开');
      } else {
        debugPrint('⚠️ P2P连接断开返回失败');
      }
    } catch (e) {
      debugPrint('❌ 断开P2P连接异常: $e');
      // 不抛出异常，继续执行后续清理操作
    }
  }

  // 清除数据库数据
  Future<void> _clearDatabaseData() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;

      // 清空 files 表
      await db.delete('files');

      debugPrint('✅ 数据库文件记录已清除');
    } catch (e) {
      debugPrint('❌ 清除数据库失败: $e');
    }
  }

  // 清除文件夹数据
  Future<void> _clearFolderData() async {
    try {
      final folderManager = FolderManager();

      // 清空本地文件夹列表
      await folderManager.clearLocalFolders();

      // 清空云端文件夹列表
      await folderManager.clearCloudFolders();

      debugPrint('✅ 文件夹列表已清除');
    } catch (e) {
      debugPrint('❌ 清除文件夹列表失败: $e');
    }
  }

  // 清除网络缓存
  Future<void> _clearNetworkCache() async {
    try {
      // 获取缓存目录
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/diocache');

      if (await cacheDir.exists()) {
        // 删除缓存目录
        await cacheDir.delete(recursive: true);
        debugPrint('✅ 网络缓存已清除');
      }
    } catch (e) {
      debugPrint('❌ 清除网络缓存失败: $e');
    }
  }

  // 清除上传任务数据
  Future<void> _clearUploadTasks() async {
    try {
      final taskManager = UploadFileTaskManager.instance;
      final userId = MyInstance().user?.user?.id ?? 0;
      final groupId = MyInstance().group?.groupId ?? 0;

      if (userId > 0 && groupId > 0) {
        await taskManager.deleteByUserGroup(userId, groupId);
        debugPrint('✅ 上传任务已清除');
      }
    } catch (e) {
      debugPrint('❌ 清除上传任务失败: $e');
    }
  }

  // 清除 MyInstance 数据
  Future<void> _clearMyInstanceData() async {
    try {
      // 执行 MyNetworkProvider 的 doLogout
      await MyInstance().mineProvider.doLogout();

      debugPrint('✅ 用户数据已清除');
    } catch (e) {
      debugPrint('❌ 清除用户数据失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userInfo = _getUserInfo();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    '个人信息',
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
            ),

            // 内容区域
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // 用户头像
                    _buildAvatar(),
                    const SizedBox(height: 24),

                    // 用户信息列表
                    ...userInfo.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),

                    const SizedBox(height: 24),

                    // 退出登录按钮
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoggingOut ? null : _showLogoutConfirmDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoggingOut
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          '退出登录',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}