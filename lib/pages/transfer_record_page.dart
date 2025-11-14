// pages/transfer_record_page.dart
import 'package:flutter/material.dart';
import '../manager/transfer_manager.dart';
import '../models/transfer_task_model.dart';
import '../widgets/transfer_task_item.dart';

/// 传输记录页面
class TransferRecordPage extends StatefulWidget {
  const TransferRecordPage({super.key});

  @override
  State<TransferRecordPage> createState() => _TransferRecordPageState();
}

class _TransferRecordPageState extends State<TransferRecordPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TransferManager _transferManager = TransferManager();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _transferManager.addListener(_onTransferUpdate);
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
            // 标题栏
            _buildTitleBar(),

            // 标签页
            _buildTabBar(),

            // 内容区域
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
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => Navigator.pop(context),
            tooltip: '返回',
          ),
          const SizedBox(width: 8),
          // 标题
          const Text(
            '传输记录',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          // 设置按钮
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () {
              // TODO: 打开传输设置
            },
            tooltip: '设置',
          ),
          const SizedBox(width: 4),
          // 排序按钮
          IconButton(
            icon: const Icon(Icons.sort, size: 20),
            onPressed: () {
              // TODO: 排序选项
            },
            tooltip: '排序',
          ),
          const SizedBox(width: 4),
          // 最小化按钮
          IconButton(
            icon: const Icon(Icons.minimize, size: 20),
            onPressed: () => Navigator.pop(context),
            tooltip: '最小化',
          ),
          // 关闭按钮
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
    final tasks = _transferManager.tasks;

    if (tasks.isEmpty) {
      return _buildEmptyState('暂无同步记录');
    }

    return Column(
      children: [
        // 表头
        _buildListHeader(),

        // 列表
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

        // 底部统计
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
            '第1/${tasks.isEmpty ? 0 : 1}页，共${totalTasks}条',
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
      _transferManager.deleteTask(taskId);
    }
  }
}