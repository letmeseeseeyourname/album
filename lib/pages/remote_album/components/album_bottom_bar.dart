// album/components/album_bottom_bar.dart (优化版 - 新样式)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../user/my_instance.dart';
import '../../../album/database/download_task_db_helper.dart';
import '../../../album/manager/download_queue_manager.dart';
import '../../../eventbus/event_bus.dart';
import '../../../eventbus/download_events.dart'; // 新增：导入下载事件
import '../managers/selection_manager.dart';
import '../managers/album_data_manager.dart';

/// 相册底部栏组件
/// 显示选中信息、磁盘空间、下载路径和下载按钮
class AlbumBottomBar extends StatefulWidget {
  final SelectionManager selectionManager;
  final AlbumDataManager dataManager;
  final int? userId;
  final int? groupId;

  const AlbumBottomBar({
    super.key,
    required this.selectionManager,
    required this.dataManager,
    this.userId,
    this.groupId,
  });

  @override
  State<AlbumBottomBar> createState() => _AlbumBottomBarState();
}

class _AlbumBottomBarState extends State<AlbumBottomBar> {
  final DownloadQueueManager _downloadManager = DownloadQueueManager.instance;
  bool _isInitialized = false;
  String _downloadPath = '';
  String _freeSpace = '计算中...';

  // 事件订阅
  StreamSubscription? _downloadPathSubscription;

  @override
  void initState() {
    super.initState();
    _initializeDownloadManager();
    _loadDownloadPath();
    _subscribeToEvents();
  }

  // 订阅事件
  void _subscribeToEvents() {
    // 监听下载路径变更事件
    _downloadPathSubscription = MCEventBus.on<DownloadPathChangedEvent>().listen((event) {
      if (mounted) {
        _loadDownloadPath();
      }
    });
  }

  @override
  void dispose() {
    _downloadPathSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeDownloadManager() async {
    debugPrint('=== 初始化底部栏下载管理器 ===');
    debugPrint('widget.userId: ${widget.userId}');
    debugPrint('widget.groupId: ${widget.groupId}');

    // 确保有有效的用户ID和群组ID
    final userId = widget.userId ?? 1; // 默认用户ID
    final groupId = widget.groupId ?? 1; // 默认群组ID

    debugPrint('使用的userId: $userId, groupId: $groupId');

    try {
      final downloadPath = await MyInstance().getDownloadPath();
      await _downloadManager.initialize(
        userId: userId,
        groupId: groupId,
        downloadPath: downloadPath,
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        debugPrint('下载管理器初始化成功');
      }
    } catch (e) {
      debugPrint('下载管理器初始化失败: $e');
    }
  }

  Future<void> _loadDownloadPath() async {
    try {
      final path = await MyInstance().getDownloadPath();
      final freeSpace = await _getDiskFreeSpace(path);

      if (mounted) {
        setState(() {
          _downloadPath = path;
          _freeSpace = freeSpace;
        });
      }
    } catch (e) {
      debugPrint('加载下载路径失败: $e');
    }
  }

  /// 获取磁盘剩余空间
  Future<String> _getDiskFreeSpace(String path) async {
    try {
      if (Platform.isWindows) {
        // 获取盘符
        final driveLetter = path.substring(0, 2); // 例如 "D:"

        final result = await Process.run(
          'wmic',
          ['logicaldisk', 'where', 'DeviceID="$driveLetter"', 'get', 'FreeSpace'],
          runInShell: true,
        );

        if (result.exitCode == 0) {
          final output = result.stdout.toString().trim();
          final lines = output.split('\n');
          if (lines.length >= 2) {
            final freeBytes = int.tryParse(lines[1].trim());
            if (freeBytes != null) {
              return _formatBytes(freeBytes);
            }
          }
        }
      }
      return '未知';
    } catch (e) {
      debugPrint('获取磁盘空间失败: $e');
      return '未知';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(0)}GB';
  }

  /// 修改下载路径
  Future<void> _changeDownloadPath() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      await MyInstance().setDownloadPath(selectedDirectory);

      // 重新加载路径和空间信息
      await _loadDownloadPath();

      // 重新初始化下载管理器
      if (_isInitialized) {
        final userId = widget.userId ?? 1;
        final groupId = widget.groupId ?? 1;

        await _downloadManager.initialize(
          userId: userId,
          groupId: groupId,
          downloadPath: selectedDirectory,
        );
      }

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
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.selectionManager,
        widget.dataManager,
        _downloadManager,
      ]),
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              // 左侧信息区域
              Expanded(
                child: _buildInfoSection(),
              ),
              // 右侧下载按钮
              _buildDownloadButton(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoSection() {
    final selectedIds = widget.selectionManager.selectedResIds;
    final hasSelection = selectedIds.isNotEmpty;

    // 计算选中信息
    String selectionInfo = '';
    if (hasSelection) {
      int totalSize = 0;
      int imageCount = 0;
      int videoCount = 0;

      for (var id in selectedIds) {
        final resources = widget.dataManager.getResourcesByIds({id});
        if (resources.isNotEmpty) {
          final resource = resources.first;
          totalSize += resource.fileSize ?? 0;
          if (resource.fileType == 'V') {
            videoCount++;
          } else {
            imageCount++;
          }
        }
      }

      final sizeStr = _formatFileSize(totalSize);

      // 构建选择信息字符串
      List<String> parts = [];
      if (imageCount > 0) {
        parts.add('${imageCount}张照片');
      }
      if (videoCount > 0) {
        parts.add('${videoCount}条视频');
      }

      selectionInfo = '已选：$sizeStr · ${parts.join('/')}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 第一行：选中信息
        Text(
          hasSelection ? selectionInfo : '共 ${widget.dataManager.allResources.length} 项',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        // 第二行：磁盘空间和下载路径
        Row(
          children: [
            Text(
              '硬盘剩余空间：$_freeSpace',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(width: 24),
            // 使用Flexible包裹下载路径，防止溢出
            Flexible(
              child: Text(
                '下载位置：$_downloadPath',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 12),
            // 修改按钮
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _changeDownloadPath,
                child: Text(
                  '修改',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }

  Widget _buildDownloadButton(BuildContext context) {
    final hasSelection = widget.selectionManager.hasSelection;

    return ElevatedButton(
      onPressed: hasSelection ? () => _handleDownload(context) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        disabledForegroundColor: Colors.grey.shade500,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
      child: const Text(
        '下载',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _handleDownload(BuildContext context) async {
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('下载服务正在初始化，请稍候...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedIds = widget.selectionManager.selectedResIds;

    debugPrint('=== 处理下载 ===');
    debugPrint('选中的资源ID数量: ${selectedIds.length}');

    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先选择要下载的文件'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 获取选中的资源
    final selectedResources = widget.dataManager.getResourcesByIds(selectedIds);

    debugPrint('找到的资源数量: ${selectedResources.length}');
    for (var res in selectedResources) {
      debugPrint('资源: ${res.fileName}');
      debugPrint('  resId: ${res.resId}');
      debugPrint('  filePath: ${res.originPath}');
      debugPrint('  fileSize: ${res.fileSize}');
    }

    if (selectedResources.isEmpty) {
      debugPrint('错误: 没有找到对应的资源对象');

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('没有找到要下载的资源'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // 添加到下载队列
      await _downloadManager.addDownloadTasks(selectedResources);

      // 清除选择
      widget.selectionManager.clearSelection();

      if (!context.mounted) return;

      // 获取实际添加的任务数量
      final addedCount = _downloadManager.downloadTasks
          .where((t) => selectedIds.contains(t.taskId))
          .length;

      debugPrint('实际添加的任务数量: $addedCount');

      // 显示成功提示
      if (addedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已添加 $addedCount 个文件到下载队列'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: '',//查看队列
              textColor: Colors.white,
              onPressed: () => _showDownloadQueue(context),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('所选文件可能已在队列中或无法下载'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('添加到队列失败: $e');

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('添加失败: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDownloadQueue(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => DownloadQueueDialog(
        downloadManager: _downloadManager,
        onContinueSelection: () {
          Navigator.pop(context);
          // 用户可以继续选择更多文件
        },
      ),
    );
  }
}

/// 下载队列对话框
class DownloadQueueDialog extends StatelessWidget {
  final DownloadQueueManager downloadManager;
  final VoidCallback onContinueSelection;

  const DownloadQueueDialog({
    super.key,
    required this.downloadManager,
    required this.onContinueSelection,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: downloadManager,
      builder: (context, child) {
        final tasks = downloadManager.downloadTasks;

        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('下载队列'),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            height: 400,
            child: tasks.isEmpty
                ? const Center(
              child: Text('暂无下载任务'),
            )
                : ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _buildTaskItem(context, task);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                downloadManager.clearCompletedTasks();
              },
              child: const Text('清除已完成'),
            ),
            TextButton(
              onPressed: onContinueSelection,
              child: const Text('继续选择'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTaskItem(BuildContext context, DownloadTaskRecord task) {
    IconData statusIcon;
    Color statusColor;

    switch (task.status) {
      case DownloadTaskStatus.pending:
        statusIcon = Icons.schedule;
        statusColor = Colors.orange;
        break;
      case DownloadTaskStatus.downloading:
        statusIcon = Icons.download;
        statusColor = Colors.blue;
        break;
      case DownloadTaskStatus.paused:
        statusIcon = Icons.pause_circle;
        statusColor = Colors.grey;
        break;
      case DownloadTaskStatus.completed:
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        break;
      case DownloadTaskStatus.failed:
        statusIcon = Icons.error;
        statusColor = Colors.red;
        break;
      case DownloadTaskStatus.canceled:
        statusIcon = Icons.cancel;
        statusColor = Colors.grey;
        break;
    }

    return ListTile(
      leading: Icon(statusIcon, color: statusColor),
      title: Text(
        task.fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.status == DownloadTaskStatus.downloading)
            LinearProgressIndicator(
              value: task.progress,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          Text(
            _formatFileSize(task.downloadedSize) +
                ' / ' +
                _formatFileSize(task.fileSize) +
                ' (${(task.progress * 100).toStringAsFixed(1)}%)',
            style: const TextStyle(fontSize: 12),
          ),
          if (task.errorMessage != null)
            Text(
              task.errorMessage!,
              style: const TextStyle(fontSize: 11, color: Colors.red),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: _buildTaskActions(task),
    );
  }

  Widget _buildTaskActions(DownloadTaskRecord task) {
    switch (task.status) {
      case DownloadTaskStatus.downloading:
        return IconButton(
          icon: const Icon(Icons.pause, size: 20),
          onPressed: () => downloadManager.pauseDownload(task.taskId),
          tooltip: '暂停',
        );
      case DownloadTaskStatus.paused:
      case DownloadTaskStatus.pending:
        return IconButton(
          icon: const Icon(Icons.play_arrow, size: 20),
          onPressed: () => downloadManager.startDownload(task.taskId),
          tooltip: '开始',
        );
      case DownloadTaskStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () => downloadManager.retryDownload(task.taskId),
              tooltip: '重试',
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              onPressed: () => downloadManager.cancelDownload(task.taskId),
              tooltip: '删除',
            ),
          ],
        );
      case DownloadTaskStatus.completed:
        return const Icon(Icons.done, size: 20, color: Colors.green);
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}