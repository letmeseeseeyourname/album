// pages/transfer_record_page_fixed.dart
// 修复版本: 从数据库加载历史任务并正确显示

import 'package:flutter/material.dart';
import '../album/database/upload_task_db_helper.dart';
import '../manager/transfer_manager.dart';
import '../models/transfer_task_model.dart';
import '../widgets/transfer_task_item.dart';

/// 传输记录页面 (修复版)
///
/// 主要修复:
/// 1. 在 initState 中从数据库加载历史任务
/// 2. 将数据库任务记录转换为 TransferTaskModel
/// 3. 提供刷新功能
class TransferRecordPage extends StatefulWidget {
  const TransferRecordPage({super.key});

  @override
  State<TransferRecordPage> createState() => _TransferRecordPageState();
}

class _TransferRecordPageState extends State<TransferRecordPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TransferManager _transferManager = TransferManager();
  final UploadFileTaskManager _taskDbManager = UploadFileTaskManager.instance;

  // 🔥 新增: 加载状态
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _transferManager.addListener(_onTransferUpdate);

    // 🔥 加载历史任务
    _loadHistoryTasks();
  }

  @override
  void dispose() {
    _transferManager.removeListener(_onTransferUpdate);
    _tabController.dispose();
    super.dispose();
  }

  void _onTransferUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  /// 🔥 从数据库加载历史任务
  Future<void> _loadHistoryTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 获取用户信息 (实际项目中从 MyInstance 获取)
      // final userId = MyInstance().user?.user?.id ?? 0;
      // final groupId = MyInstance().group?.groupId ?? 0;

      // 示例数据
      final userId = 1;
      final groupId = 1;

      if (userId == 0) {
        throw Exception("用户未登录");
      }

      // 从数据库查询任务记录
      final taskRecords = await _taskDbManager.listTasks(
        userId: userId,
        groupId: groupId,
        limit: 100, // 最多加载100条记录
      );

      debugPrint('🔥 Loaded ${taskRecords.length} history tasks from database');

      // 🔥 清空现有任务 (避免重复)
      _transferManager.clearAllTasks();

      // 🔥 转换为 TransferTaskModel 并添加到管理器
      for (var record in taskRecords) {
        final task = _convertDbRecordToTransferTask(record);
        _transferManager.addTask(task);
      }

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      debugPrint('Error loading history tasks: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '加载失败: ${e.toString()}';
      });
    }
  }

  /// 🔥 将数据库记录转换为传输任务模型
  TransferTaskModel _convertDbRecordToTransferTask(UploadTaskRecord record) {
    // 将数据库状态映射到UI状态
    TransferTaskStatus uiStatus;
    switch (record.status) {
      case UploadTaskStatus.uploading:
        uiStatus = TransferTaskStatus.uploading;
        break;
      case UploadTaskStatus.success:
        uiStatus = TransferTaskStatus.completed;
        break;
      case UploadTaskStatus.failed:
        uiStatus = TransferTaskStatus.failed;
        break;
      case UploadTaskStatus.canceled:
        uiStatus = TransferTaskStatus.paused;
        break;
      default:
        uiStatus = TransferTaskStatus.paused;
    }

    // 🔥 注意: 从数据库恢复时,我们没有文件详细信息
    // 理想情况下,应该有一个 upload_task_files 表来存储文件列表
    // 这里我们创建一个基本的任务记录

    // 🔥 可以从其他地方获取文件信息,例如:
    // 1. 从 database_helper 的 files 表查询 (通过 taskId 关联)
    // 2. 创建额外的 upload_task_files 表
    // 3. 在上传时将文件信息序列化存储

    return TransferTaskModel(
      taskId: record.taskId,
      createTime: DateTime.fromMillisecondsSinceEpoch(record.createdAt),
      totalCount: 0, // 🔥 需要从文件表获取
      totalSize: 0,  // 🔥 需要从文件表获取
      completedCount: uiStatus == TransferTaskStatus.completed ? 0 : 0,
      uploadedSize: uiStatus == TransferTaskStatus.completed ? 0 : 0,
      status: uiStatus,
      fileItems: [], // 🔥 文件列表需要从其他地方获取
      isExpanded: false,
    );
  }

  /// 🔥 刷新任务列表
  Future<void> _refreshTasks() async {
    await _loadHistoryTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _buildTitleBar(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSyncList(),
                  _buildDownloadList(),
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
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => Navigator.pop(context),
            tooltip: '返回',
          ),
          const SizedBox(width: 8),
          const Text(
            '传输记录',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),

          // 🔥 新增: 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _isLoading ? null : _refreshTasks,
            tooltip: '刷新',
          ),
          const SizedBox(width: 4),

          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () {
              // TODO: 打开传输设置
            },
            tooltip: '设置',
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.sort, size: 20),
            onPressed: () {
              // TODO: 排序选项
            },
            tooltip: '排序',
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.minimize, size: 20),
            onPressed: () => Navigator.pop(context),
            tooltip: '最小化',
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  /// 构建标签栏
  Widget _buildTabBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.black,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        indicatorColor: Colors.orange,
        indicatorSize: TabBarIndicatorSize.label,
        tabs: const [
          Tab(text: '同步'),
          Tab(text: '下载'),
        ],
      ),
    );
  }

  /// 构建同步列表
  Widget _buildSyncList() {
    // 🔥 显示加载状态
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载任务记录...'),
          ],
        ),
      );
    }

    // 🔥 显示错误信息
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 14, color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshTasks,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final tasks = _transferManager.tasks;

    // 🔥 显示空状态
    if (tasks.isEmpty) {
      return _buildEmptyState('暂无同步记录');
    }

    return Column(
      children: [
        _buildListHeader(),
        Expanded(
          child: ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              return TransferTaskItem(
                task: tasks[index],
                onTap: () {
                  _transferManager.toggleTaskExpanded(tasks[index].taskId);
                },
                onPause: () {
                  _transferManager.pauseTask(tasks[index].taskId);
                },
                onResume: () {
                  _transferManager.resumeTask(tasks[index].taskId);
                },
                onDelete: () {
                  _showDeleteConfirmDialog(tasks[index].taskId);
                },
              );
            },
          ),
        ),
        _buildBottomStats(tasks),
      ],
    );
  }

  /// 构建下载列表 (后续实现)
  Widget _buildDownloadList() {
    return _buildEmptyState('暂无下载记录');
  }

  /// 构建空状态
  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建列表表头
  Widget _buildListHeader() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            flex: 3,
            child: Text(
              '时间',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              '数量',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              '大小',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              '状态',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              '操作',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建底部统计
  Widget _buildBottomStats(List<TransferTaskModel> tasks) {
    final totalTasks = tasks.length;
    final completedTasks = tasks.where((t) => t.status == TransferTaskStatus.completed).length;

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
        children: [
          Text(
            '第1/${tasks.isEmpty ? 0 : 1}页,共${totalTasks}条',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const Spacer(),
          if (completedTasks > 0)
            TextButton(
              onPressed: () {
                _transferManager.clearCompletedTasks();
              },
              child: const Text(
                '清空已完成',
                style: TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  /// 显示删除确认对话框
  Future<void> _showDeleteConfirmDialog(int taskId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个传输记录吗?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 🔥 从数据库和内存中删除
      try {
        // 获取用户信息
        final userId = 1; // 实际项目中从 MyInstance 获取
        final groupId = 1;

        await _taskDbManager.deleteTaskForKey(
          taskId: taskId,
          userId: userId,
          groupId: groupId,
        );

        _transferManager.deleteTask(taskId);
      } catch (e) {
        debugPrint('Error deleting task: $e');
        // 显示错误提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: ${e.toString()}')),
          );
        }
      }
    }
  }
}