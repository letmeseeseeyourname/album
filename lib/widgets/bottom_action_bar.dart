import 'package:flutter/material.dart';
import '../album/upload/models/local_upload_progress.dart';

/// 底部栏组件 - 显示选择信息、上传进度和操作按钮
class BottomActionBar extends StatelessWidget {
  final int selectedCount;
  final double selectedTotalSize;
  final int selectedImageCount;
  final int selectedVideoCount;
  final bool isUploading;
  final LocalUploadProgress? uploadProgress;
  final String deviceStorageInfo;
  final VoidCallback? onSync;

  const BottomActionBar({
    super.key,
    required this.selectedCount,
    required this.selectedTotalSize,
    required this.selectedImageCount,
    required this.selectedVideoCount,
    required this.isUploading,
    required this.uploadProgress,
    required this.deviceStorageInfo,
    this.onSync,
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
          // 左侧：选择信息
          if (selectedCount > 0) ...[
            _buildSelectionInfo(),
          ],

          // 中间：上传进度
          if (isUploading && uploadProgress != null) ...[
            const SizedBox(width: 20),
            Expanded(
              child: _buildUploadProgress(),
            ),
          ],

          const Spacer(),

          // 右侧：存储信息和同步按钮
          _buildActionSection(),
        ],
      ),
    );
  }

  Widget _buildSelectionInfo() {
    return Text(
      '已选：${selectedTotalSize.toStringAsFixed(2)}MB · '
          '$selectedImageCount张照片/$selectedVideoCount条视频',
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey.shade600,
      ),
    );
  }

  Widget _buildUploadProgress() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: uploadProgress!.progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(uploadProgress!.progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${uploadProgress!.uploadedFiles}/${uploadProgress!.totalFiles} · '
              '${uploadProgress!.currentFileName ?? ""}',
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

  Widget _buildActionSection() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '设备剩余空间：$deviceStorageInfo',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 30),
        ElevatedButton(
          onPressed: isUploading ? null : onSync,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2C2C2C),
            disabledBackgroundColor: Colors.grey,
            padding: const EdgeInsets.symmetric(
              horizontal: 40,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            isUploading ? '上传中...' : '上传',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}