// widgets/folder_detail_bottom_bar.dart - 修复后的完整代码
import 'package:flutter/material.dart';
import '../../../album/manager/local_folder_upload_manager.dart';

/// 文件夹详情页底部工具栏
/// ✅ 已修复:
/// 1. 同步按钮在上传时仍可点击,支持多任务并发
/// 2. 支持显示文件夹递归统计结果
/// 3. 支持显示统计中状态
class FolderDetailBottomBar extends StatelessWidget {
  final int selectedCount;
  final double selectedTotalSizeMB;
  final int selectedImageCount;
  final int selectedVideoCount;
  final double deviceStorageUsedPercent;
  final bool isUploading;
  final LocalUploadProgress? uploadProgress;
  final VoidCallback onSyncPressed;
  final bool isCountingFiles; // 新增：是否正在统计文件

  const FolderDetailBottomBar({
    super.key,
    required this.selectedCount,
    required this.selectedTotalSizeMB,
    required this.selectedImageCount,
    required this.selectedVideoCount,
    required this.deviceStorageUsedPercent,
    required this.isUploading,
    required this.uploadProgress,
    required this.onSyncPressed,
    this.isCountingFiles = false, // 默认不在统计中
  });

  @override
  Widget build(BuildContext context) {
    if (selectedCount == 0 && !isUploading) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          // 左侧信息
          if (selectedCount > 0) ...[
            // 显示统计中状态或统计结果
            isCountingFiles
                ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '正在统计文件...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            )
                : Text(
              '已选：${_formatFileSize(selectedTotalSizeMB)} · ${selectedImageCount}张照片/${selectedVideoCount}条视频',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],

          // 上传进度
          if (isUploading && uploadProgress != null) ...[
            const SizedBox(width: 20),
            Expanded(
              child: _buildUploadProgress(uploadProgress!),
            ),
          ],

          const Spacer(),

          // 右侧按钮
          Text(
            '设备剩余空间：${deviceStorageUsedPercent.toStringAsFixed(2)}G',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 30),

          // ✅ 修复后的同步按钮
          ElevatedButton(
            onPressed: onSyncPressed,  // ✅ 始终可用,不再检查 isUploading
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C2C2C),
              // ✅ 删除 disabledBackgroundColor (不再需要)
              padding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isUploading ? '继续上传' : '上传',  // ✅ 动态文字提示
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化文件大小
  String _formatFileSize(double sizeMB) {
    if (sizeMB >= 1024) {
      return '${(sizeMB / 1024).toStringAsFixed(2)}GB';
    }
    return '${sizeMB.toStringAsFixed(2)}MB';
  }

  Widget _buildUploadProgress(LocalUploadProgress progress) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: progress.progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(progress.progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${progress.uploadedFiles}/${progress.totalFiles} · ${progress.currentFileName ?? ""}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}