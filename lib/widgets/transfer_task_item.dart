// widgets/transfer_task_item.dart
import 'package:flutter/material.dart';
import '../models/transfer_task_model.dart';

/// 传输任务项组件
class TransferTaskItem extends StatelessWidget {
  final TransferTaskModel task;
  final VoidCallback onTap;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  const TransferTaskItem({
    super.key,
    required this.task,
    required this.onTap,
    required this.onPause,
    required this.onResume,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Column(
        children: [
          // 主任务行
          _buildMainTaskRow(context),

          // 展开的子列表
          if (task.isExpanded) _buildExpandedContent(context),
        ],
      ),
    );
  }

  /// 构建主任务行
  Widget _buildMainTaskRow(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // 展开图标
            Icon(
              task.isExpanded ? Icons.expand_more : Icons.chevron_right,
              size: 20,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 12),

            // 时间
            Expanded(
              flex: 3,
              child: Text(
                task.timeText,
                style: const TextStyle(fontSize: 14),
              ),
            ),

            // 数量
            Expanded(
              flex: 2,
              child: Text(
                '${task.totalCount}',
                style: const TextStyle(fontSize: 14),
              ),
            ),

            // 大小
            Expanded(
              flex: 2,
              child: Text(
                task.totalSizeText,
                style: const TextStyle(fontSize: 14),
              ),
            ),

            // 状态
            Expanded(
              flex: 2,
              child: _buildStatusWidget(),
            ),

            // 操作
            Expanded(
              flex: 2,
              child: _buildActionsWidget(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建状态组件
  Widget _buildStatusWidget() {
    Color statusColor;
    switch (task.status) {
      case TransferTaskStatus.uploading:
        statusColor = Colors.green;
        break;
      case TransferTaskStatus.paused:
        statusColor = Colors.grey;
        break;
      case TransferTaskStatus.completed:
        statusColor = Colors.black87;
        break;
      case TransferTaskStatus.failed:
        statusColor = Colors.red;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (task.status == TransferTaskStatus.uploading)
          Container(
            width: 80,
            height: 4,
            margin: const EdgeInsets.only(right: 8),
            child: LinearProgressIndicator(
              value: task.progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
        Text(
          task.status.displayName,
          style: TextStyle(
            fontSize: 13,
            color: statusColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 构建操作组件
  Widget _buildActionsWidget(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 暂停/继续按钮
        if (task.status.canPause)
          TextButton(
            onPressed: onPause,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              '取消同步',
              style: TextStyle(fontSize: 12),
            ),
          )
        else if (task.status.canResume)
          TextButton(
            onPressed: onResume,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              '继续',
              style: TextStyle(fontSize: 12),
            ),
          ),

        const SizedBox(width: 8),

        // 删除按钮
        if (task.status.canDelete)
          TextButton(
            onPressed: onDelete,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: Colors.red,
            ),
            child: const Text(
              '删除',
              style: TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }

  /// 构建展开内容
  Widget _buildExpandedContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 52, right: 20, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 子列表表头
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Expanded(
                  flex: 4,
                  child: Text(
                    '文件名',
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
                    '进度',
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
              ],
            ),
          ),

          const SizedBox(height: 4),

          // 文件列表
          ...task.fileItems.map((fileItem) => _buildFileItem(fileItem)),
        ],
      ),
    );
  }

  /// 构建文件项
  Widget _buildFileItem(TransferFileItem fileItem) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),

          // 文件名
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Icon(
                  _getFileIcon(fileItem.fileName),
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileItem.fileName,
                    style: const TextStyle(fontSize: 13),
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
              fileItem.fileSizeText,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),

          // 进度
          Expanded(
            flex: 2,
            child: _buildFileProgress(fileItem),
          ),

          // 状态
          Expanded(
            flex: 2,
            child: Text(
              fileItem.status.displayName,
              style: TextStyle(
                fontSize: 13,
                color: _getFileStatusColor(fileItem.status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建文件进度
  Widget _buildFileProgress(TransferFileItem fileItem) {
    if (fileItem.status == TransferTaskStatus.uploading) {
      return Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(
              value: fileItem.progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(fileItem.progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 11),
          ),
        ],
      );
    } else if (fileItem.status == TransferTaskStatus.completed) {
      return const Text(
        '100%',
        style: TextStyle(fontSize: 13),
      );
    } else {
      return Text(
        '${(fileItem.progress * 100).toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade600,
        ),
      );
    }
  }

  /// 获取文件图标
  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) {
      return Icons.image;
    } else if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) {
      return Icons.videocam;
    }
    return Icons.insert_drive_file;
  }

  /// 获取文件状态颜色
  Color _getFileStatusColor(TransferTaskStatus status) {
    switch (status) {
      case TransferTaskStatus.uploading:
        return Colors.orange;
      case TransferTaskStatus.paused:
        return Colors.grey;
      case TransferTaskStatus.completed:
        return Colors.green;
      case TransferTaskStatus.failed:
        return Colors.red;
    }
  }
}