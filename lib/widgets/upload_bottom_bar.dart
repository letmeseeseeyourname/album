// widgets/upload_bottom_bar.dart
// 通用上传底部工具栏组件
// 用于 MainFolderPage 和 FolderDetailPage

import 'package:flutter/material.dart';
import '../album/manager/local_folder_upload_manager.dart';

/// 通用上传底部工具栏
///
/// 特性：
/// - 上传任务进行中时始终显示（即使切换页面再回来）
/// - 支持显示选中文件统计
/// - 支持显示上传进度
/// - 支持显示设备剩余空间
/// - 支持统计中状态
///
/// 使用示例：
/// ```dart
/// UploadBottomBar(
///   selectedCount: selectedIndices.length,
///   selectedTotalSizeMB: totalSizeMB,
///   selectedImageCount: imageCount,
///   selectedVideoCount: videoCount,
///   deviceStorageSurplusGB: 128.5,
///   isUploading: uploadCoordinator.isUploading,
///   uploadProgress: uploadCoordinator.uploadProgress,
///   onUploadPressed: _handleSync,
///   isCountingFiles: isCountingFiles,
/// )
/// ```
class UploadBottomBar extends StatelessWidget {
  /// 选中数量
  final int selectedCount;

  /// 选中文件总大小（MB）
  final double selectedTotalSizeMB;

  /// 选中的图片数量
  final int selectedImageCount;

  /// 选中的视频数量
  final int selectedVideoCount;

  /// 设备剩余存储空间（GB）
  final double deviceStorageSurplusGB;

  /// 是否正在上传
  final bool isUploading;

  /// 上传进度（可为空）
  final LocalUploadProgress? uploadProgress;

  /// 上传按钮点击回调
  final VoidCallback onUploadPressed;

  /// 是否正在统计文件
  final bool isCountingFiles;

  /// 是否显示选中信息（默认true）
  /// 设为 false 时，即使有选中也不显示统计信息（仅显示上传进度）
  final bool showSelectionInfo;

  /// 上传按钮文字（可自定义）
  final String? uploadButtonText;

  /// 上传中按钮文字（可自定义）
  final String? uploadingButtonText;

  const UploadBottomBar({
    super.key,
    required this.selectedCount,
    required this.selectedTotalSizeMB,
    required this.selectedImageCount,
    required this.selectedVideoCount,
    required this.deviceStorageSurplusGB,
    required this.isUploading,
    required this.uploadProgress,
    required this.onUploadPressed,
    this.isCountingFiles = false,
    this.showSelectionInfo = true,
    this.uploadButtonText,
    this.uploadingButtonText,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ 显示逻辑：有上传任务时始终显示，无选中且无上传时隐藏
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
          // 左侧：选中统计信息（仅在有选中且允许显示时）
          if (selectedCount > 0 && showSelectionInfo) _buildSelectionInfo(),

          // 中间：上传进度（上传中时显示）
          if (isUploading && uploadProgress != null) ...[
            if (selectedCount > 0 && showSelectionInfo)
              const SizedBox(width: 20),
            Expanded(child: _buildUploadProgress(uploadProgress!)),
          ],

          const Spacer(),

          // 右侧：设备空间 + 上传按钮
          _buildRightSection(),
        ],
      ),
    );
  }

  /// 构建选中信息区域
  Widget _buildSelectionInfo() {
    if (isCountingFiles) {
      return Row(
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
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      );
    }

    return Text(
      '已选：${_formatFileSize(selectedTotalSizeMB)} · '
          '${selectedImageCount}张照片/${selectedVideoCount}条视频',
      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
    );
  }

  /// 构建上传进度区域
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
          '${progress.uploadedFiles}/${progress.totalFiles} · '
              '${progress.currentFileName ?? ""}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// 构建右侧区域（设备空间 + 按钮）
  Widget _buildRightSection() {
    final buttonText = isUploading
        ? (uploadingButtonText ?? '继续上传')
        : (uploadButtonText ?? '上传');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '设备剩余空间：${deviceStorageSurplusGB.toStringAsFixed(2)}G',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 30),
        ElevatedButton(
          onPressed: onUploadPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2C2C2C),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            buttonText,
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }

  /// 格式化文件大小
  String _formatFileSize(double sizeMB) {
    if (sizeMB >= 1024) {
      return '${(sizeMB / 1024).toStringAsFixed(2)}GB';
    }
    return '${sizeMB.toStringAsFixed(2)}MB';
  }
}