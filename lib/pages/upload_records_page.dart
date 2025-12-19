// pages/upload_records_page.dart
// ✅ 修改版：
// 1. 监听 UploadCoordinator 实时更新上传状态
// 2. 取消上传时调用 delSyncTask API 并同步取消实际上传任务

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';
import '../album/database/upload_task_db_helper.dart';
import '../album/database/download_task_db_helper.dart';
import '../album/provider/album_provider.dart';
import '../user/my_instance.dart';
// ✅ 新增：导入 UploadCoordinator
import 'local_album/controllers/upload_coordinator.dart';

/// 传输记录页面
class UploadRecordsPage extends StatefulWidget {
  const UploadRecordsPage({super.key});

  @override
  State<UploadRecordsPage> createState() => _UploadRecordsPageState();
}

class _UploadRecordsPageState extends State<UploadRecordsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UploadFileTaskManager _taskManager = UploadFileTaskManager.instance;
  final DownloadTaskDbHelper _downloadDbHelper = DownloadTaskDbHelper.instance;
  final AlbumProvider _albumProvider = AlbumProvider();  // ✅ 新增

  List<UploadTaskRecord> _uploadTasks = [];
  List<DownloadTaskRecord> _downloadTasks = [];
  List<DownloadBatchRecord> _downloadBatches = [];

  bool _isLoading = true;
  bool _isCancelling = false;  // ✅ 新增：取消中状态

  // ✅ 新增：UploadCoordinator 引用
  late final UploadCoordinator _uploadCoordinator;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // ✅ 监听 UploadCoordinator 状态变化
    _uploadCoordinator = UploadCoordinator.instance;
    _uploadCoordinator.addListener(_onUploadStateChanged);

    _loadAllTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    // ✅ 移除监听
    _uploadCoordinator.removeListener(_onUploadStateChanged);
    super.dispose();
  }

  /// ✅ 新增：上传状态变化回调
  void _onUploadStateChanged() {
    if (mounted) {
      // 当上传状态变化时，重新加载任务列表
      _loadUploadTasks().then((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  /// 加载所有任务（上传和下载）
  Future<void> _loadAllTasks() async {
    setState(() {
      _isLoading = true;
    });

    await Future.wait([
      _loadUploadTasks(),
      _loadDownloadTasks(),
    ]);

    setState(() {
      _isLoading = false;
    });
  }

  /// 加载上传任务列表
  Future<void> _loadUploadTasks() async {
    try {
      final userId = MyInstance().user?.user?.id ?? 0;
      final groupId = MyInstance().group?.groupId ?? 0;

      if (userId > 0 && groupId > 0) {
        final tasks = await _taskManager.listTasks(
          userId: userId,
          groupId: groupId,
          limit: 100,
        );
        _uploadTasks = tasks;
      }
    } catch (e) {
      print('加载上传任务失败: $e');
    }
  }

  /// 加载下载任务列表
  Future<void> _loadDownloadTasks() async {
    try {
      final userId = MyInstance().user?.user?.id ?? 0;
      final groupId = MyInstance().group?.groupId ?? 0;

      if (userId > 0 && groupId > 0) {
        final tasks = await _downloadDbHelper.listTasks(
          userId: userId,
          groupId: groupId,
          limit: 500,
        );
        _downloadTasks = tasks;
        _downloadBatches = _aggregateDownloadTasks(tasks);
      }
    } catch (e) {
      print('加载下载任务失败: $e');
    }
  }

  /// 将下载任务按时间聚合为批次
  List<DownloadBatchRecord> _aggregateDownloadTasks(List<DownloadTaskRecord> tasks) {
    if (tasks.isEmpty) return [];

    final sortedTasks = List<DownloadTaskRecord>.from(tasks)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final batches = <DownloadBatchRecord>[];
    List<DownloadTaskRecord> currentBatch = [];
    int? currentBatchMinute;

    for (final task in sortedTasks) {
      final taskMinute = task.createdAt ~/ 60000;

      if (currentBatchMinute == null || taskMinute == currentBatchMinute) {
        currentBatch.add(task);
        currentBatchMinute = taskMinute;
      } else {
        if (currentBatch.isNotEmpty) {
          batches.add(DownloadBatchRecord.fromTasks(currentBatch));
        }
        currentBatch = [task];
        currentBatchMinute = taskMinute;
      }
    }

    if (currentBatch.isNotEmpty) {
      batches.add(DownloadBatchRecord.fromTasks(currentBatch));
    }

    return batches;
  }

  /// ✅ 修改：取消上传任务
  /// 1. 调用 delSyncTask API
  /// 2. 取消实际上传任务
  /// 3. 更新数据库状态
  Future<void> _cancelUploadTask(UploadTaskRecord task) async {
    if (_isCancelling) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      // 1. ✅ 先取消 UploadCoordinator 中的实际上传任务
      //    这会调用 McService.cancelTask() 终止上传进程
      final cancelResult = await _uploadCoordinator.cancelTaskById(task.taskId);
      debugPrint('[UploadRecords] Cancel result: ${cancelResult.message}');

      // 2. 调用服务端 API 取消同步任务
      final response = await _albumProvider.revokeSyncTask(task.taskId);
      if (!response.isSuccess) {
        debugPrint('[UploadRecords] Server cancel failed: ${response.message}');
        // 服务端取消失败不影响本地取消
      }

      // 3. 更新数据库状态
      await _taskManager.updateStatusForKey(
        taskId: task.taskId,
        userId: task.userId,
        groupId: task.groupId,
        status: UploadTaskStatus.canceled,
      );

      // 4. 重新加载任务列表
      await _loadUploadTasks();

      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消上传')),
        );
      }
    } catch (e) {
      debugPrint('[UploadRecords] Cancel error: $e');
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('取消失败: $e')),
        );
      }
    }
  }

  /// 删除上传任务记录
  Future<void> _deleteUploadTask(UploadTaskRecord task) async {
    try {
      // 如果任务正在上传中，先取消
      if (task.status == UploadTaskStatus.uploading) {
        await _cancelUploadTask(task);
      }

      await _taskManager.deleteTaskForKey(
        taskId: task.taskId,
        userId: task.userId,
        groupId: task.groupId,
      );

      await _loadUploadTasks();

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除记录')),
        );
      }
    } catch (e) {
      print('删除任务失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  /// 删除下载批次记录
  Future<void> _deleteDownloadBatch(DownloadBatchRecord batch) async {
    try {
      final userId = MyInstance().user?.user?.id ?? 0;
      final groupId = MyInstance().group?.groupId ?? 0;

      for (final task in batch.tasks) {
        await _downloadDbHelper.deleteTask(
          taskId: task.taskId,
          userId: userId,
          groupId: groupId,
        );
      }

      await _loadDownloadTasks();

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除记录')),
        );
      }
    } catch (e) {
      print('删除下载批次失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildTitleBar(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUploadTab(),
                _buildDownloadTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建标题栏
  Widget _buildTitleBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 24),
                      onPressed: () => Navigator.pop(context),
                      tooltip: '返回',
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '传输记录',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WindowButton(
                icon: Icons.close,
                isClose: true,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建Tab栏
  Widget _buildTabBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: EdgeInsets.zero,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              dividerColor: Colors.transparent,
              labelPadding: const EdgeInsets.symmetric(horizontal: 20),
              tabs: const [
                Tab(text: '上传'),
                Tab(text: '下载'),
              ],
            ),
          ),
          const Spacer(),
          // ✅ 新增：刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadAllTasks,
            tooltip: '刷新',
          ),
        ],
      ),
    );
  }

  /// 构建上传Tab
  Widget _buildUploadTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_uploadTasks.isEmpty) {
      return const Center(
        child: Text(
          '暂无上传记录',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        _buildTableHeader(isUpload: true),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _uploadTasks.length,
            itemBuilder: (context, index) {
              return _buildUploadTaskItem(_uploadTasks[index], index);
            },
          ),
        ),
        _buildPaginationFooter(_uploadTasks.length),
      ],
    );
  }

  /// 构建下载Tab
  Widget _buildDownloadTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_downloadBatches.isEmpty) {
      return const Center(
        child: Text(
          '暂无下载记录',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        _buildTableHeader(isUpload: false),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _downloadBatches.length,
            itemBuilder: (context, index) {
              return _buildDownloadBatchItem(_downloadBatches[index], index);
            },
          ),
        ),
        _buildPaginationFooter(_downloadBatches.length),
      ],
    );
  }

  /// 统一的表头构建
  Widget _buildTableHeader({required bool isUpload}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          _buildHeaderCell('时间', flex: 3),
          _buildHeaderCell('数量', flex: 2),
          _buildHeaderCell('大小', flex: 2),
          _buildHeaderCell('状态', flex: 2),
          _buildHeaderCell('操作', flex: 2),
        ],
      ),
    );
  }

  /// 构建表头单元格
  Widget _buildHeaderCell(String title, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  /// 构建上传任务项
  Widget _buildUploadTaskItem(UploadTaskRecord task, int index) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(task.createdAt);
    final formattedDate = DateFormat('yyyy.M.d HH:mm:ss').format(dateTime);
    final isEvenRow = index % 2 == 0;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isEvenRow ? Colors.white : const Color(0xFFFAFAFA),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // 时间
          Expanded(
            flex: 3,
            child: Text(formattedDate, style: const TextStyle(fontSize: 14)),
          ),
          // 数量
          Expanded(
            flex: 2,
            child: Text('${task.fileCount}', style: const TextStyle(fontSize: 14)),
          ),
          // 大小
          Expanded(
            flex: 2,
            child: Text(task.formattedSize, style: const TextStyle(fontSize: 14)),
          ),
          // 状态
          Expanded(
            flex: 2,
            child: _buildUploadStatusWidget(task),
          ),
          // 操作
          Expanded(
            flex: 2,
            child: _buildUploadActionButtons(task),
          ),
        ],
      ),
    );
  }

  /// 构建下载批次项
  Widget _buildDownloadBatchItem(DownloadBatchRecord batch, int index) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(batch.createdAt);
    final formattedDate = DateFormat('yyyy.M.d HH:mm:ss').format(dateTime);
    final isEvenRow = index % 2 == 0;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isEvenRow ? Colors.white : const Color(0xFFFAFAFA),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // 时间
          Expanded(
            flex: 3,
            child: Text(formattedDate, style: const TextStyle(fontSize: 14)),
          ),
          // 数量
          Expanded(
            flex: 2,
            child: Text('${batch.fileCount}', style: const TextStyle(fontSize: 14)),
          ),
          // 大小
          Expanded(
            flex: 2,
            child: Text(batch.formattedSize, style: const TextStyle(fontSize: 14)),
          ),
          // 状态
          Expanded(
            flex: 2,
            child: _buildDownloadBatchStatusWidget(batch),
          ),
          // 操作
          Expanded(
            flex: 2,
            child: _buildDownloadBatchActionButtons(batch),
          ),
        ],
      ),
    );
  }

  /// ✅ 修改：构建上传状态显示（支持实时进度）
  Widget _buildUploadStatusWidget(UploadTaskRecord task) {
    // 检查是否是当前正在上传的任务
    if (task.status == UploadTaskStatus.uploading) {
      final activeTask = _uploadCoordinator.getActiveTaskByDbTaskId(task.taskId);
      if (activeTask != null && activeTask.progress != null) {
        final progress = activeTask.progress!;
        return Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                value: progress.bytesProgress,
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(progress.bytesProgress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 14, color: Colors.orange),
            ),
          ],
        );
      }
      // 没有实时进度，显示默认状态
      return Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade300),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '正在上传',
            style: TextStyle(fontSize: 14, color: Colors.orange),
          ),
        ],
      );
    }

    String text;
    Color color;

    switch (task.status) {
      case UploadTaskStatus.pending:
        text = '待上传';
        color = Colors.grey;
        break;
      case UploadTaskStatus.uploading:
        text = '正在上传';
        color = Colors.orange;
        break;
      case UploadTaskStatus.success:
        text = '已完成';
        color = Colors.black;
        break;
      case UploadTaskStatus.failed:
        text = '失败';
        color = Colors.red;
        break;
      case UploadTaskStatus.canceled:
        text = '已取消';
        color = Colors.grey;
        break;
    }

    return Text(text, style: TextStyle(fontSize: 14, color: color));
  }

  /// 构建下载批次状态显示
  Widget _buildDownloadBatchStatusWidget(DownloadBatchRecord batch) {
    String text;
    Color color;

    switch (batch.status) {
      case DownloadBatchStatus.pending:
        text = '待下载';
        color = Colors.grey;
        break;
      case DownloadBatchStatus.downloading:
        text = '正在下载';
        color = Colors.orange;
        break;
      case DownloadBatchStatus.completed:
        text = '已完成';
        color = Colors.black;
        break;
      case DownloadBatchStatus.partialCompleted:
        text = '部分完成 (${batch.completedCount}/${batch.fileCount})';
        color = Colors.orange;
        break;
      case DownloadBatchStatus.failed:
        text = '失败';
        color = Colors.red;
        break;
      case DownloadBatchStatus.canceled:
        text = '已取消';
        color = Colors.grey;
        break;
    }

    return Text(text, style: TextStyle(fontSize: 14, color: color));
  }

  /// ✅ 修改：构建上传操作按钮
  Widget _buildUploadActionButtons(UploadTaskRecord task) {
    return Row(
      children: [
        if (task.status == UploadTaskStatus.uploading)
          TextButton(
            onPressed: _isCancelling ? null : () => _cancelUploadTask(task),
            child: Text(
              _isCancelling ? '取消中...' : '取消上传',
              style: TextStyle(
                fontSize: 13,
                color: _isCancelling ? Colors.grey.shade400 : Colors.grey,
              ),
            ),
          ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () => _showDeleteUploadConfirmDialog(task),
          child: const Text(
            '删除',
            style: TextStyle(fontSize: 13, color: Colors.red),
          ),
        ),
      ],
    );
  }

  /// 构建下载批次操作按钮
  Widget _buildDownloadBatchActionButtons(DownloadBatchRecord batch) {
    return Row(
      children: [
        TextButton(
          onPressed: () => _showDeleteDownloadBatchConfirmDialog(batch),
          child: const Text(
            '删除',
            style: TextStyle(fontSize: 13, color: Colors.red),
          ),
        ),
      ],
    );
  }

  /// 显示删除上传记录确认对话框
  void _showDeleteUploadConfirmDialog(UploadTaskRecord task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteUploadTask(task);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 显示删除下载批次确认对话框
  void _showDeleteDownloadBatchConfirmDialog(DownloadBatchRecord batch) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除这 ${batch.fileCount} 个文件的下载记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteDownloadBatch(batch);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 构建分页信息
  Widget _buildPaginationFooter(int totalCount) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '共 $totalCount 条记录',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// 下载批次状态枚举
// ============================================================
enum DownloadBatchStatus {
  pending,
  downloading,
  completed,
  partialCompleted,
  failed,
  canceled,
}


// ============================================================
// 下载批次记录模型
// ============================================================
class DownloadBatchRecord {
  final List<DownloadTaskRecord> tasks;
  final int createdAt;
  final int fileCount;
  final int totalSize;
  final int completedCount;
  final int failedCount;

  DownloadBatchRecord({
    required this.tasks,
    required this.createdAt,
    required this.fileCount,
    required this.totalSize,
    required this.completedCount,
    required this.failedCount,
  });

  factory DownloadBatchRecord.fromTasks(List<DownloadTaskRecord> tasks) {
    if (tasks.isEmpty) {
      return DownloadBatchRecord(
        tasks: [],
        createdAt: 0,
        fileCount: 0,
        totalSize: 0,
        completedCount: 0,
        failedCount: 0,
      );
    }

    final completedCount = tasks.where((t) =>
    t.status == DownloadTaskStatus.completed).length;
    final failedCount = tasks.where((t) =>
    t.status == DownloadTaskStatus.failed).length;
    final totalSize = tasks.fold<int>(0, (sum, t) => sum + t.fileSize);

    return DownloadBatchRecord(
      tasks: tasks,
      createdAt: tasks.first.createdAt,
      fileCount: tasks.length,
      totalSize: totalSize,
      completedCount: completedCount,
      failedCount: failedCount,
    );
  }

  DownloadBatchStatus get status {
    if (tasks.isEmpty) return DownloadBatchStatus.pending;

    final hasDownloading = tasks.any((t) =>
    t.status == DownloadTaskStatus.downloading);
    final hasPending = tasks.any((t) =>
    t.status == DownloadTaskStatus.pending);
    final allCompleted = tasks.every((t) =>
    t.status == DownloadTaskStatus.completed);
    final allFailed = tasks.every((t) =>
    t.status == DownloadTaskStatus.failed);
    final allCanceled = tasks.every((t) =>
    t.status == DownloadTaskStatus.canceled);
    final hasCompleted = tasks.any((t) =>
    t.status == DownloadTaskStatus.completed);

    if (allCompleted) return DownloadBatchStatus.completed;
    if (allFailed) return DownloadBatchStatus.failed;
    if (allCanceled) return DownloadBatchStatus.canceled;
    if (hasDownloading) return DownloadBatchStatus.downloading;
    if (hasPending) return DownloadBatchStatus.pending;
    if (hasCompleted) return DownloadBatchStatus.partialCompleted;

    return DownloadBatchStatus.failed;
  }

  String get formattedSize {
    if (totalSize < 1024) {
      return '${totalSize}B';
    } else if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)}KB';
    } else if (totalSize < 1024 * 1024 * 1024) {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    } else {
      return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
    }
  }
}


// ============================================================
// 窗口控制按钮
// ============================================================
class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 56,
          alignment: Alignment.center,
          color: _isHovered
              ? (widget.isClose ? Colors.red : Colors.grey.shade200)
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 18,
            color: _isHovered && widget.isClose ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }
}