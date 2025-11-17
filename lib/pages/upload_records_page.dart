// pages/upload_records_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../album/database/upload_task_db_helper.dart';
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

  List<UploadTaskRecord> _uploadTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUploadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 加载上传任务列表
  Future<void> _loadUploadTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = MyInstance().user?.user?.id ?? 0;
      final groupId = MyInstance().group?.groupId ?? 0;

      if (userId > 0 && groupId > 0) {
        // 加载所有任务，不限制状态
        final tasks = await _taskManager.listTasks(
          userId: userId,
          groupId: groupId,
          limit: 100, // 限制最多显示100条记录
        );

        setState(() {
          _uploadTasks = tasks;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('加载上传任务失败: $e');
      setState(() {
        _isLoading = false;
      });
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
          const SnackBar(content: Text('已取消同步')),
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
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
      ),
    );
  }

  /// 构建标题栏
  Widget _buildTitleBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 24),
            onPressed: () => Navigator.pop(context),
            tooltip: '返回',
          ),

          const SizedBox(width: 12),

          // 标题
          const Text(
            '传输记录',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const Spacer(),

          // 窗口控制按钮区域（占位，保持与主窗口一致）
          Row(
            children: [
              // 设置按钮
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 20),
                onPressed: () {},
                tooltip: '设置',
              ),
              // 排序按钮
              IconButton(
                icon: const Icon(Icons.sort, size: 20),
                onPressed: () {},
                tooltip: '排序',
              ),
              // 最小化按钮（占位）
              Container(
                width: 46,
                height: 56,
                color: Colors.transparent,
                child: const Icon(Icons.minimize, size: 16),
              ),
              // 最大化按钮（占位）
              Container(
                width: 46,
                height: 56,
                color: Colors.transparent,
                child: const Icon(Icons.crop_square, size: 16),
              ),
              // 关闭按钮
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 46,
                    height: 56,
                    color: Colors.transparent,
                    child: const Icon(Icons.close, size: 16),
                  ),
                ),
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
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.black,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.orange,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: '同步'),
          Tab(text: '下载'),
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
          '暂无同步记录',
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: _uploadTasks.length,
            itemBuilder: (context, index) {
              return _buildUploadTaskItem(_uploadTasks[index]);
            },
          ),
        ),

        // 底部分页信息
        _buildPaginationFooter(),
      ],
    );
  }

  /// 构建下载Tab（暂未实现）
  Widget _buildDownloadTab() {
    return const Center(
      child: Text(
        '下载功能开发中...',
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey,
        ),
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
  Widget _buildUploadTaskItem(UploadTaskRecord task) {
    final dateTime =
    DateTime.fromMillisecondsSinceEpoch(task.createdAt);
    final formattedDate =
    DateFormat('yyyy.M.d HH:mm:ss').format(dateTime);

    return Container(
      height: 60,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
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

          // 数量（这里使用taskId作为占位，实际应该从其他地方获取）
          Expanded(
            flex: 2,
            child: Text(
              '${task.fileCount}', // ✅ 显示实际文件数量
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // 大小
          Expanded(
            flex: 2,
            child: Text(
              task.formattedSize, // ✅ 显示格式化的实际大小
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
        text = '正在同步';
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
              '取消同步',
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
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '第1/3页，共20条',
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