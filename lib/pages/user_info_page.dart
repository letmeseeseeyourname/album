// pages/user_info_page.dart
import 'package:flutter/material.dart';
import 'package:ablumwin/user/my_instance.dart';
import 'package:ablumwin/services/login_service.dart';
import 'package:ablumwin/network/constant_sign.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../album/database/download_task_db_helper.dart';  // ✅ 新增
import '../album/manager/download_queue_manager.dart';    // ✅ 新增
import '../album/database/database_helper.dart';
import '../album/database/upload_task_db_helper.dart';
import '../album/provider/album_provider.dart';
import '../services/folder_manager.dart';
import 'local_album/controllers/upload_coordinator.dart';
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

  // ✅ 修改：获取用户信息（按设计图调整字段）
  Map<String, String> _getUserInfo() {
    final user = MyInstance().user?.user;
    final group = MyInstance().group;
    final deviceInfo = MyInstance().p6deviceInfoModel;

    return {
      '昵称': user?.nickName ?? '未知',
      '手机号': user?.mobile ?? '未知',
      '当前家庭': group?.groupName ?? '未选择',
      '当前设备': MyInstance().deviceCode.isNotEmpty
          ? MyInstance().deviceCode
          : '未绑定',
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

  // ✅ 修改：显示退出登录确认对话框（按设计图样式）
  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              const Center(
                child: Text(
                  '退出登录',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 提示内容
              const Text(
                '退出后，将清除所有本地数据，包括：',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 12),

              // 列表项
              _buildListItem('1. 用户信息'),
              _buildListItem('2. 文件记录'),
              _buildListItem('3. 上传/下载任务'),
              _buildListItem('4. 文件夹列表'),
              _buildListItem('5. 缓存数据'),

              const SizedBox(height: 20),

              // 确认文字
              const Text(
                '确定要退出登录？',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),

              const SizedBox(height: 24),

              // 按钮行
              Row(
                children: [
                  // 取消按钮
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 确定按钮
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleLogout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C2C2C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '确定',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ 构建列表项
  Widget _buildListItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  // 处理退出登录
  Future<void> _handleLogout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      // 0. 取消所有正在进行的上传任务（优先执行）
      await _cancelAllUploads();

      // 1. 断开P2P连接（优先执行）
      await _disconnectP2pConnection();

      // 2. 调用登出接口
      await LoginService.logout();

      // 3. 清除数据库数据
      await _clearDatabaseData();

      // 4. 清除文件夹列表
      await _clearFolderData();

      // 5. 清除网络缓存
      await _clearNetworkCache();

      // 6. 清除 MyInstance 中的数据
      await _clearMyInstanceData();

      // 7. 清除上传任务记录
      await _clearUploadTasks();

      // 8. 清除上传任务记录
      await _clearUploadTasks();

      await _cancelAllDownloads();
      // 9. 清除下载任务状态
      await _clearDownloadTasks();


      // 10. 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('退出登录成功'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // 11. 延迟后跳转到登录页
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

  // 断开P2P连接
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
    }
  }

  // 清除数据库数据
  Future<void> _clearDatabaseData() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;
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
      await folderManager.clearLocalFolders();
      await folderManager.clearCloudFolders();
      debugPrint('✅ 文件夹列表已清除');
    } catch (e) {
      debugPrint('❌ 清除文件夹列表失败: $e');
    }
  }

  // 清除网络缓存
  Future<void> _clearNetworkCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/diocache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        debugPrint('✅ 网络缓存已清除');
      }
    } catch (e) {
      debugPrint('❌ 清除网络缓存失败: $e');
    }
  }

  // 取消所有正在进行的上传任务
  Future<void> _cancelAllUploads() async {
    try {
      debugPrint('⏹️ 开始取消所有上传任务...');

      final userId = MyInstance().user?.user?.id ?? 0;
      final groupId = MyInstance().group?.groupId ?? 0;
      final taskManager = UploadFileTaskManager.instance;
      final albumProvider = AlbumProvider();

      try {
        final coordinator = UploadCoordinator.instance;

        if (coordinator.isUploading) {
          debugPrint('📤 发现 ${coordinator.activeTaskCount} 个正在进行的上传任务');

          final activeTaskIds = coordinator.activeDbTaskIds;
          await coordinator.cancelAllUploads();
          debugPrint('✅ 内存中的上传任务已取消');

          for (final taskId in activeTaskIds) {
            try {
              debugPrint('📡 调用 revokeSyncTask: taskId=$taskId');
              final response = await albumProvider.revokeSyncTask(taskId);
              debugPrint('📡 Server revoke result: ${response.message}');
            } catch (e) {
              debugPrint('⚠️ revokeSyncTask 失败 (taskId=$taskId): $e');
            }

            if (userId > 0 && groupId > 0) {
              try {
                await taskManager.updateStatusForKey(
                  taskId: taskId,
                  userId: userId,
                  groupId: groupId,
                  status: UploadTaskStatus.canceled,
                );
                debugPrint('✅ 数据库状态已更新: taskId=$taskId -> canceled');
              } catch (e) {
                debugPrint('⚠️ 更新数据库状态失败 (taskId=$taskId): $e');
              }
            }
          }

          debugPrint('✅ 所有上传任务已取消并更新状态');
        } else {
          debugPrint('ℹ️ 没有正在进行的上传任务');
        }
      } catch (e) {
        debugPrint('ℹ️ UploadCoordinator 未初始化，跳过取消上传: $e');
      }
    } catch (e) {
      debugPrint('❌ 取消上传任务失败: $e');
    }
  }

  // 只重置内存状态，不删除数据库记录
  Future<void> _clearUploadTasks() async {
    try {
      try {
        UploadCoordinator.reset();
        debugPrint('✅ UploadCoordinator 已重置');
      } catch (e) {
        debugPrint('ℹ️ UploadCoordinator 重置跳过: $e');
      }
      debugPrint('✅ 上传任务状态已清理（保留数据库记录）');
    } catch (e) {
      debugPrint('❌ 清理上传任务状态失败: $e');
    }
  }

  // 清除 MyInstance 数据
  Future<void> _clearMyInstanceData() async {
    try {
      await MyInstance().mineProvider.doLogout();
      debugPrint('✅ 用户数据已清除');
    } catch (e) {
      debugPrint('❌ 清除用户数据失败: $e');
    }
  }

  // ✅ 新增：取消所有正在进行的下载任务
  Future<void> _cancelAllDownloads() async {
    try {
      debugPrint('⏹️ 开始取消所有下载任务...');

      final userId = MyInstance().user?.user?.id ?? 0;
      final groupId = MyInstance().group?.groupId ?? 0;
      final downloadDbHelper = DownloadTaskDbHelper.instance;

      // 检查 DownloadQueueManager 是否有活跃任务
      try {
        final downloadManager = DownloadQueueManager.instance;

        // 获取所有正在下载或等待中的任务
        final activeTasks = downloadManager.downloadTasks.where(
                (t) => t.status == DownloadTaskStatus.downloading ||
                t.status == DownloadTaskStatus.pending
        ).toList();

        if (activeTasks.isNotEmpty) {
          debugPrint('📥 发现 ${activeTasks.length} 个正在进行的下载任务');

          // 遍历取消每个任务
          for (final task in activeTasks) {
            try {
              // 1. 取消下载（停止下载、删除临时文件、更新状态）
              await downloadManager.cancelDownload(task.taskId);
              debugPrint('✅ 已取消下载: ${task.fileName}');
            } catch (e) {
              debugPrint('⚠️ 取消下载失败 (${task.fileName}): $e');

              // 即使取消失败，也尝试更新数据库状态
              if (userId > 0 && groupId > 0) {
                try {
                  await downloadDbHelper.updateStatus(
                    taskId: task.taskId,
                    userId: userId,
                    groupId: groupId,
                    status: DownloadTaskStatus.canceled,
                  );
                } catch (e2) {
                  debugPrint('⚠️ 更新数据库状态失败: $e2');
                }
              }
            }
          }

          debugPrint('✅ 所有下载任务已取消');
        } else {
          debugPrint('ℹ️ 没有正在进行的下载任务');
        }
      } catch (e) {
        debugPrint('ℹ️ DownloadQueueManager 未初始化，跳过取消下载: $e');
      }
    } catch (e) {
      debugPrint('❌ 取消下载任务失败: $e');
      // 不抛出异常，继续执行后续清理操作
    }
  }

  // ✅ 新增：清除下载任务状态（只重置内存，保留数据库记录）
  Future<void> _clearDownloadTasks() async {
    try {
      try {
        final downloadManager = DownloadQueueManager.instance;
        downloadManager.clearAllState();
        debugPrint('✅ DownloadQueueManager 已重置');
      } catch (e) {
        debugPrint('ℹ️ DownloadQueueManager 重置跳过: $e');
      }

      debugPrint('✅ 下载任务状态已清理（保留数据库记录）');
    } catch (e) {
      debugPrint('❌ 清理下载任务状态失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userInfo = _getUserInfo();

    // ✅ 使用 PopScope 阻止 loading 时关闭弹窗
    return PopScope(
      canPop: !_isLoggingOut,  // loading 时不允许关闭
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 380,
          constraints: const BoxConstraints(maxHeight: 600),
          decoration: const BoxDecoration(
            color: Colors.white,  // ✅ 纯白色背景
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    const Text(
                      '个人信息',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // loading时隐藏关闭按钮
                    if (!_isLoggingOut)
                      IconButton(
                        icon: const Icon(Icons.close, size: 22),
                        onPressed: () => Navigator.pop(context),
                        splashRadius: 20,
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),

              // 内容区域
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    children: [
                      // 用户头像
                      _buildAvatar(),
                      const SizedBox(height: 28),

                      // 用户信息列表
                      ...userInfo.entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),

                      const SizedBox(height: 16),

                      // ✅ 退出登录按钮（使用 #F5F5F5）
                      SizedBox(
                        width: double.infinity,
                        height: 45,  // ✅ 直接设置高度
                        child: TextButton(
                          onPressed: _isLoggingOut ? null : _showLogoutConfirmDialog,
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFF5F5F5),  // ✅ #F5F5F5
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoggingOut
                              ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.red,
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '正在退出...',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            ],
                          )
                              : const Text(
                            '退出登录',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
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
      ),
    );
  }
}