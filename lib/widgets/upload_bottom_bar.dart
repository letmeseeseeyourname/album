// widgets/upload_bottom_bar.dart
import 'package:flutter/material.dart';
import '../album/manager/local_folder_upload_manager.dart';
import '../controllers/selection_controller.dart';

/// 上传底部栏组件
class UploadBottomBar extends StatelessWidget {
  final SelectionController selectionController;
  final bool isUploading;
  final LocalUploadProgress? uploadProgress;
  final VoidCallback onSyncPressed;
  final String deviceStorageInfo;

  const UploadBottomBar({
    super.key,
    required this.selectionController,
    required this.isUploading,
    this.uploadProgress,
    required this.onSyncPressed,
    required this.deviceStorageInfo,
  });

  @override
  Widget build(BuildContext context) {
    if (selectionController.selectedIndices.isEmpty && !isUploading) {
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
          // 左侧选择信息
          if (selectionController.selectedIndices.isNotEmpty) ...[
            _SelectionInfo(controller: selectionController),
          ],

          // 上传进度
          if (isUploading && uploadProgress != null) ...[
            const SizedBox(width: 20),
            Expanded(
              child: _UploadProgress(progress: uploadProgress!),
            ),
          ],

          const Spacer(),

          // 右侧按钮区域
          Text(
            deviceStorageInfo,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 30),
          ElevatedButton(
            onPressed: isUploading ? null : onSyncPressed,
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
              isUploading ? '上传中...' : '同步',
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
}

/// 选择信息组件
class _SelectionInfo extends StatelessWidget {
  final SelectionController controller;

  const _SelectionInfo({required this.controller});

  @override
  Widget build(BuildContext context) {
    final imageCount = controller.getSelectedImageCount();
    final videoCount = controller.getSelectedVideoCount();
    final totalSizeMB = controller.getSelectedTotalSizeMB();

    return Text(
      '已选：${totalSizeMB.toStringAsFixed(2)}MB · ${imageCount}张照片/${videoCount}条视频',
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey.shade600,
      ),
    );
  }
}

/// 上传进度组件
class _UploadProgress extends StatelessWidget {
  final LocalUploadProgress progress;

  const _UploadProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
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