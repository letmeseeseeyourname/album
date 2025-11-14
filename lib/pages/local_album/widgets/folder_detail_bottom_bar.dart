// widgets/folder_detail_bottom_bar.dart - 修复后的完整代码
import 'package:flutter/material.dart';
import '../../../album/manager/local_folder_upload_manager.dart';

/// 文件夹详情页底部工具栏
/// ✅ 已修复: 同步按钮在上传时仍可点击,支持多任务并发
class FolderDetailBottomBar extends StatelessWidget {
  final int selectedCount;
  final double selectedTotalSizeMB;
  final int selectedImageCount;
  final int selectedVideoCount;
  final double deviceStorageUsedPercent;
  final bool isUploading;
  final LocalUploadProgress? uploadProgress;
  final VoidCallback onSyncPressed;

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
            Text(
              '已选：${selectedTotalSizeMB.toStringAsFixed(2)}MB · $selectedImageCount张照片/$selectedVideoCount条视频',
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
              isUploading ? '继续同步' : '同步',  // ✅ 动态文字提示
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