// album/components/album_bottom_bar.dart (集成下载队列管理器)
import 'package:flutter/material.dart';
import 'dart:io';
import '../../../album/database/download_task_db_helper.dart';
import '../../../album/manager/download_queue_manager.dart';
import '../managers/selection_manager.dart';
import '../managers/album_data_manager.dart';


/// 相册底部栏组件
/// 显示选中信息、下载按钮和下载队列状态
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

  @override
  void initState() {
    super.initState();
    _initializeDownloadManager();
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
      final downloadPath = await _getDefaultDownloadPath();
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

  Future<String> _getDefaultDownloadPath() async {
    // Windows 默认下载路径
    final userHome = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ?? '';
    final downloadDir = Directory('$userHome\\Downloads\\亲选相册');

    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    return downloadDir.path;
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(
              top: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            children: [
              // 左侧信息
              Expanded(
                child: _buildInfoSection(),
              ),
              // 中间下载队列状态
              if (_isInitialized) _buildQueueStatus(),
              const SizedBox(width: 16),
              // 右侧按钮组
              _buildActionButtons(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoSection() {
    final selectedSize = widget.dataManager.calculateSelectedSize(
      widget.selectionManager.selectedResIds,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          selectedSize,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '硬盘剩余空间：320GB',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildQueueStatus() {
    final activeCount = _downloadManager.activeDownloadCount;
    final pendingCount = _downloadManager.pendingCount;
    final completedCount = _downloadManager.completedCount;
    final failedCount = _downloadManager.failedCount;

    if (activeCount == 0 && pendingCount == 0 && failedCount == 0) {
      if (completedCount > 0) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
              const SizedBox(width: 6),
              Text(
                '已完成 $completedCount 个下载',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '下载中: $activeCount | 等待: $pendingCount',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (failedCount > 0)
                Text(
                  '失败: $failedCount',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red.shade700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final hasSelection = widget.selectionManager.hasSelection;
    final hasActiveTasks = _downloadManager.activeDownloadCount > 0 ||
        _downloadManager.pendingCount > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 查看队列按钮
        if (hasActiveTasks || _downloadManager.downloadTasks.isNotEmpty)
          TextButton.icon(
            onPressed: () => _showDownloadQueue(context),
            icon: const Icon(Icons.queue, size: 18),
            label: Text('队列(${_downloadManager.downloadTasks.length})'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue.shade700,
            ),
          ),
        const SizedBox(width: 8),
        // 添加到下载队列按钮
        ElevatedButton.icon(
          onPressed: hasSelection ? () => _handleAddToQueue(context) : null,
          icon: const Icon(Icons.add_to_queue, size: 20),
          label: Text(
            hasSelection
                ? '添加到队列 (${widget.selectionManager.selectionCount})'
                : '添加到队列',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  void _handleAddToQueue(BuildContext context) async {
    debugPrint('=== 处理添加到队列 ===');
    debugPrint('_isInitialized: $_isInitialized');

    if (!_isInitialized) {
      debugPrint('错误: 下载管理器未初始化');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('下载管理器正在初始化，请稍后再试'),
          backgroundColor: Colors.orange,
        ),
      );

      // 尝试重新初始化
      await _initializeDownloadManager();
      return;
    }

    // 获取选中的资源ID
    final selectedIds = widget.selectionManager.selectedResIds;

    debugPrint('选中的ID数量: ${selectedIds.length}');
    debugPrint('选中的ID列表: $selectedIds');

    if (selectedIds.isEmpty) {
      debugPrint('错误: 没有选中任何资源');
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先选择要下载的文件'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 通过ID获取资源对象
    final selectedResources = widget.dataManager.getResourcesByIds(selectedIds);

    debugPrint('获取到的资源数量: ${selectedResources.length}');

    for (int i = 0; i < selectedResources.length && i < 3; i++) {
      final res = selectedResources[i];
      debugPrint('资源${i+1}: ${res.fileName}');
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
              label: '查看队列',
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