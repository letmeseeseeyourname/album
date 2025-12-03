// pages/upload_records_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';
import '../album/database/upload_task_db_helper.dart';
import '../album/database/download_task_db_helper.dart';
import '../user/my_instance.dart';

/// 传输记录页面
/// 显示同步和下载任务的历史记录
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

  List<UploadTaskRecord> _uploadTasks = [];
  List<DownloadTaskRecord> _downloadTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          limit: 100,
        );
        _downloadTasks = tasks;
      }
    } catch (e) {
      print('加载下载任务失败: $e');
    }
  }

  /// 取消同步任务
  Future<void> _cancelUploadTask(UploadTaskRecord task) async {
    try {
      await _taskManager.updateStatusForKey(
        taskId: task.taskId,
        userId: task.userId,
        groupId: task.groupId,
        status: UploadTaskStatus.canceled,
      );

      // 刷新列表
      await _loadUploadTasks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消上传')),
        );
      }
    } catch (e) {
      print('取消任务失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('取消失败: $e')),
        );
      }
    }
  }

  /// 删除任务记录
  Future<void> _deleteUploadTask(UploadTaskRecord task) async {
    try {
      await _taskManager.deleteTaskForKey(
        taskId: task.taskId,
        userId: task.userId,
        groupId: task.groupId,
      );

      // 刷新列表
      await _loadUploadTasks();

      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 顶部标题栏
          _buildTitleBar(),

          // Tab栏
          _buildTabBar(),

          // 内容区域
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
          // 左侧：返回按钮和标题（可拖拽区域）
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
                    // 返回按钮
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 24),
                      onPressed: () => Navigator.pop(context),
                      tooltip: '返回',
                    ),
                    const SizedBox(width: 8),
                    // 标题
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

          // 右侧：工具按钮和窗口控制
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 关闭按钮
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
          // 左对齐的 Tab 按钮组
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
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
        ],
      ),
    );
  }

  /// 构建上传（同步）Tab
  Widget _buildUploadTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_uploadTasks.isEmpty) {
      return const Center(
        child: Text(
          '暂无上传记录',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Column(
      children: [
        // 表头
        _buildTableHeader(),

        // 任务列表
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _uploadTasks.length,
            itemBuilder: (context, index) {
              return _buildUploadTaskItem(_uploadTasks[index], index);
            },
          ),
        ),

        // 底部分页信息
        _buildPaginationFooter(),
      ],
    );
  }

  /// 构建下载Tab
  Widget _buildDownloadTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_downloadTasks.isEmpty) {
      return const Center(
        child: Text(
          '暂无下载记录',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Column(
      children: [
        // 表头
        _buildDownloadTableHeader(),

        // 任务列表
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _downloadTasks.length,
            itemBuilder: (context, index) {
              return _buildDownloadTaskItem(_downloadTasks[index], index);
            },
          ),
        ),

        // 底部分页信息
        _buildDownloadPaginationFooter(),
      ],
    );
  }

  /// 构建下载表头
  Widget _buildDownloadTableHeader() {
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
          _buildHeaderCell('文件名', flex: 3),
          _buildHeaderCell('大小', flex: 2),
          _buildHeaderCell('进度', flex: 2),
          _buildHeaderCell('状态', flex: 2),
          _buildHeaderCell('操作', flex: 2),
        ],
      ),
    );
  }

  /// 构建下载任务项
  Widget _buildDownloadTaskItem(DownloadTaskRecord task, int index) {
    // 奇偶行不同背景色
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
          // 文件名
          Expanded(
            flex: 3,
            child: Row(
              children: [
                // 文件类型图标
                Icon(
                  task.fileType == 'V' ? Icons.videocam : Icons.image,
                  size: 20,
                  color: task.fileType == 'V' ? Colors.blue : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.fileName,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // 大小
          Expanded(
            flex: 2,
            child: Text(
              _formatFileSize(task.fileSize),
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // 进度
          Expanded(
            flex: 2,
            child: _buildProgressWidget(task),
          ),

          // 状态
          Expanded(
            flex: 2,
            child: _buildDownloadStatusWidget(task.status),
          ),

          // 操作
          Expanded(
            flex: 2,
            child: _buildDownloadActionButtons(task),
          ),
        ],
      ),
    );
  }

  /// 构建进度显示
  Widget _buildProgressWidget(DownloadTaskRecord task) {
    if (task.status == DownloadTaskStatus.completed) {
      return const Text(
        '100%',
        style: TextStyle(fontSize: 14, color: Colors.green),
      );
    }

    if (task.status == DownloadTaskStatus.downloading) {
      final progress = (task.progress * 100).toStringAsFixed(1);
      return Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(
              value: task.progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$progress%',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      );
    }

    return Text(
      '${(task.progress * 100).toStringAsFixed(0)}%',
      style: const TextStyle(fontSize: 14, color: Colors.grey),
    );
  }

  /// 构建下载状态显示
  Widget _buildDownloadStatusWidget(DownloadTaskStatus status) {
    String text;
    Color color;

    switch (status) {
      case DownloadTaskStatus.pending:
        text = '等待中';
        color = Colors.grey;
        break;
      case DownloadTaskStatus.downloading:
        text = '下载中';
        color = Colors.orange;
        break;
      case DownloadTaskStatus.paused:
        text = '已暂停';
        color = Colors.blue;
        break;
      case DownloadTaskStatus.completed:
        text = '已完成';
        color = Colors.green;
        break;
      case DownloadTaskStatus.failed:
        text = '失败';
        color = Colors.red;
        break;
      case DownloadTaskStatus.canceled:
        text = '已取消';
        color = Colors.grey;
        break;
    }

    return Text(
      text,
      style: TextStyle(fontSize: 14, color: color),
    );
  }

  /// 构建下载操作按钮
  Widget _buildDownloadActionButtons(DownloadTaskRecord task) {
    return Row(
      children: [
        // 删除按钮
        TextButton(
          onPressed: () => _showDeleteDownloadConfirmDialog(task),
          child: const Text(
            '删除',
            style: TextStyle(fontSize: 13, color: Colors.red),
          ),
        ),
      ],
    );
  }

  /// 显示删除下载记录确认对话框
  void _showDeleteDownloadConfirmDialog(DownloadTaskRecord task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${task.fileName}" 的下载记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteDownloadTask(task);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 删除下载任务记录
  Future<void> _deleteDownloadTask(DownloadTaskRecord task) async {
    try {
      await _downloadDbHelper.deleteTask(
        taskId: task.taskId,
        userId: task.userId,
        groupId: task.groupId,
      );

      // 刷新列表
      await _loadAllTasks();
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除记录')),
        );
      }
    } catch (e) {
      print('删除下载任务失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
    }
  }

  /// 构建下载分页信息
  Widget _buildDownloadPaginationFooter() {
    final totalCount = _downloadTasks.length;

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
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建表头
  Widget _buildTableHeader() {
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
    final dateTime =
    DateTime.fromMillisecondsSinceEpoch(task.createdAt);
    final formattedDate =
    DateFormat('yyyy.M.d HH:mm:ss').format(dateTime);

    // 奇偶行不同背景色
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
            child: Text(
              formattedDate,
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // 数量
          Expanded(
            flex: 2,
            child: Text(
              '${task.fileCount}',
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // 大小
          Expanded(
            flex: 2,
            child: Text(
              task.formattedSize,
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // 状态
          Expanded(
            flex: 2,
            child: _buildStatusWidget(task.status),
          ),

          // 操作
          Expanded(
            flex: 2,
            child: _buildActionButtons(task),
          ),
        ],
      ),
    );
  }

  /// 构建状态显示组件
  Widget _buildStatusWidget(UploadTaskStatus status) {
    String text;
    Color color;

    switch (status) {
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

    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: color,
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButtons(UploadTaskRecord task) {
    return Row(
      children: [
        // 取消同步按钮（仅在上传中时显示）
        if (task.status == UploadTaskStatus.uploading)
          TextButton(
            onPressed: () => _cancelUploadTask(task),
            child: const Text(
              '取消上传',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ),

        const SizedBox(width: 8),

        // 删除按钮
        TextButton(
          onPressed: () => _showDeleteConfirmDialog(task),
          child: const Text(
            '删除',
            style: TextStyle(
              fontSize: 13,
              color: Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmDialog(UploadTaskRecord task) {
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
            child: const Text(
              '删除',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分页信息
  Widget _buildPaginationFooter() {
    final totalCount = _uploadTasks.length;

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
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 窗口控制按钮
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