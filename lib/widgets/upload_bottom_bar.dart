// widgets/upload_bottom_bar.dart
// 通用上传底部工具栏组件
// ✅ 保留进度条和大小显示，速度显示采用新样式居中

import 'package:flutter/material.dart';
import '../album/manager/local_folder_upload_manager.dart';
import '../album/upload/models/local_upload_progress.dart';

/// 通用上传底部工具栏
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

  /// 上传进度
  final LocalUploadProgress? uploadProgress;

  /// 上传按钮点击回调
  final VoidCallback onUploadPressed;

  /// 是否正在统计文件
  final bool isCountingFiles;

  /// 是否显示选中信息（默认true）
  final bool showSelectionInfo;

  /// 上传按钮文字（可自定义）
  final String? uploadButtonText;

  /// 上传中按钮文字（可自定义）
  final String? uploadingButtonText;

  /// 活跃任务数量
  final int activeTaskCount;

  /// 是否使用字节进度（默认 true）
  final bool useBytesProgress;

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
    this.activeTaskCount = 1,
    this.useBytesProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    // 显示逻辑：有上传任务时始终显示，无选中且无上传时隐藏
    if (selectedCount == 0 && !isUploading) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          // 左侧：选中统计信息（非上传时显示）或进度信息（上传时显示）
          if (selectedCount > 0 && showSelectionInfo && !isUploading)
            _buildSelectionInfo(),

          // 上传中时显示进度信息
          if (isUploading && uploadProgress != null)
            _buildUploadProgressSection(uploadProgress!),

          // 中间：速度显示（上传中时居中显示）
          if (isUploading && uploadProgress != null)
            Expanded(child: _buildSpeedIndicator(uploadProgress!)),

          // 非上传时的 Spacer
          if (!isUploading) const Spacer(),

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

  /// ✅ 构建上传进度区域（包含进度条、大小、文件数）
  Widget _buildUploadProgressSection(LocalUploadProgress progress) {
    // 根据配置选择进度值
    final double progressValue = useBytesProgress
        ? progress.bytesProgress
        : progress.progress;

    return SizedBox(
      width: 280,  // 固定宽度
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：进度条 + 百分比
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progressValue.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress.failedFiles > 0 ? Colors.orange.shade700 : Colors.orange,
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(progressValue * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 第二行：已下载大小/总大小 · 文件进度
          Row(
            children: [
              // 大小进度
              Text(
                '${progress.formattedTransferred} / ${progress.formattedTotal}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 12),
              // 文件进度
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.insert_drive_file_outlined,
                      size: 12,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${progress.uploadedFiles}/${progress.totalFiles}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // 多任务徽章
              if (activeTaskCount > 1) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '×$activeTaskCount',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// ✅ 构建速度指示器（居中显示，新样式）
  Widget _buildSpeedIndicator(LocalUploadProgress progress) {
    final speed = progress.speed;
    final formattedSpeed = _formatSpeed(speed);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 上传图标
            Icon(
              Icons.upload,
              size: 18,
              color: Colors.green.shade600,
            ),
            const SizedBox(width: 8),
            // 速度文字
            Text(
              formattedSpeed,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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

  /// 格式化速度
  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond}B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)}KB/s';
    } else if (bytesPerSecond < 1024 * 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)}MB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB/s';
    }
  }
}