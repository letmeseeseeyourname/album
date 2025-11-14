// models/transfer_task_model.dart

/// 传输任务状态
enum TransferTaskStatus {
  uploading,    // 正在同步
  paused,       // 已取消
  completed,    // 已完成
  failed,       // 失败
}

extension TransferTaskStatusX on TransferTaskStatus {
  String get displayName {
    switch (this) {
      case TransferTaskStatus.uploading:
        return '正在同步';
      case TransferTaskStatus.paused:
        return '已取消';
      case TransferTaskStatus.completed:
        return '已完成';
      case TransferTaskStatus.failed:
        return '失败';
    }
  }

  bool get canPause => this == TransferTaskStatus.uploading;
  bool get canResume => this == TransferTaskStatus.paused;
  bool get canDelete => this != TransferTaskStatus.uploading;
}

/// 文件传输项
class TransferFileItem {
  final String fileName;
  final String filePath;
  final int fileSize; // 字节
  double progress; // 0.0 - 1.0
  TransferTaskStatus status;
  int uploadedSize; // 已上传字节数
  String? errorMessage;

  TransferFileItem({
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    this.progress = 0.0,
    this.status = TransferTaskStatus.uploading,
    this.uploadedSize = 0,
    this.errorMessage,
  });

  /// 获取文件大小显示文本
  String get fileSizeText {
    if (fileSize < 1024) {
      return '${fileSize}B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
    }
  }

  /// 获取已上传大小显示文本
  String get uploadedSizeText {
    if (uploadedSize < 1024) {
      return '${uploadedSize}B';
    } else if (uploadedSize < 1024 * 1024) {
      return '${(uploadedSize / 1024).toStringAsFixed(1)}KB';
    } else if (uploadedSize < 1024 * 1024 * 1024) {
      return '${(uploadedSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    } else {
      return '${(uploadedSize / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
    }
  }

  /// 复制并更新
  TransferFileItem copyWith({
    double? progress,
    TransferTaskStatus? status,
    int? uploadedSize,
    String? errorMessage,
  }) {
    return TransferFileItem(
      fileName: fileName,
      filePath: filePath,
      fileSize: fileSize,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      uploadedSize: uploadedSize ?? this.uploadedSize,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 传输任务模型
class TransferTaskModel {
  final int taskId;
  final DateTime createTime;
  final int totalCount; // 总文件数
  final int totalSize; // 总大小(字节)
  int completedCount; // 已完成数量
  int uploadedSize; // 已上传大小
  TransferTaskStatus status;
  List<TransferFileItem> fileItems; // 文件列表
  bool isExpanded; // 是否展开子列表

  TransferTaskModel({
    required this.taskId,
    required this.createTime,
    required this.totalCount,
    required this.totalSize,
    this.completedCount = 0,
    this.uploadedSize = 0,
    this.status = TransferTaskStatus.uploading,
    List<TransferFileItem>? fileItems,
    this.isExpanded = false,
  }) : fileItems = fileItems ?? [];

  /// 获取总进度 (0.0 - 1.0)
  double get progress {
    if (totalSize == 0) return 0.0;
    return uploadedSize / totalSize;
  }

  /// 获取进度百分比文本
  String get progressText {
    return '${(progress * 100).toStringAsFixed(0)}%';
  }

  /// 获取总大小显示文本
  String get totalSizeText {
    if (totalSize < 1024 * 1024 * 1024) {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(0)}MB';
    } else {
      return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
    }
  }

  /// 获取时间显示文本
  String get timeText {
    final now = DateTime.now();
    final diff = now.difference(createTime);

    if (diff.inDays > 0) {
      return '${createTime.year}.${createTime.month}.${createTime.day} ${createTime.hour.toString().padLeft(2, '0')}:${createTime.minute.toString().padLeft(2, '0')}:${createTime.second.toString().padLeft(2, '0')}';
    } else {
      return '${createTime.year}.${createTime.month}.${createTime.day} ${createTime.hour.toString().padLeft(2, '0')}:${createTime.minute.toString().padLeft(2, '0')}:${createTime.second.toString().padLeft(2, '0')}';
    }
  }

  /// 更新文件项进度
  void updateFileProgress(int index, double progress, int uploadedSize) {
    if (index >= 0 && index < fileItems.length) {
      final oldUploadedSize = fileItems[index].uploadedSize;
      fileItems[index].progress = progress;
      fileItems[index].uploadedSize = uploadedSize;

      // 更新总进度
      this.uploadedSize += (uploadedSize - oldUploadedSize);

      // 如果文件完成,更新完成计数
      if (progress >= 1.0 && fileItems[index].status != TransferTaskStatus.completed) {
        fileItems[index].status = TransferTaskStatus.completed;
        completedCount++;
      }

      // 检查整体任务状态
      _updateTaskStatus();
    }
  }

  /// 更新任务状态
  void _updateTaskStatus() {
    if (completedCount == totalCount) {
      status = TransferTaskStatus.completed;
    } else if (fileItems.any((item) => item.status == TransferTaskStatus.uploading)) {
      status = TransferTaskStatus.uploading;
    }
  }

  /// 暂停任务
  void pause() {
    if (status == TransferTaskStatus.uploading) {
      status = TransferTaskStatus.paused;
      for (var item in fileItems) {
        if (item.status == TransferTaskStatus.uploading) {
          item.status = TransferTaskStatus.paused;
        }
      }
    }
  }

  /// 恢复任务
  void resume() {
    if (status == TransferTaskStatus.paused) {
      status = TransferTaskStatus.uploading;
      for (var item in fileItems) {
        if (item.status == TransferTaskStatus.paused && item.progress < 1.0) {
          item.status = TransferTaskStatus.uploading;
        }
      }
    }
  }

  /// 切换展开状态
  void toggleExpanded() {
    isExpanded = !isExpanded;
  }

  /// 复制并更新
  TransferTaskModel copyWith({
    int? completedCount,
    int? uploadedSize,
    TransferTaskStatus? status,
    List<TransferFileItem>? fileItems,
    bool? isExpanded,
  }) {
    return TransferTaskModel(
      taskId: taskId,
      createTime: createTime,
      totalCount: totalCount,
      totalSize: totalSize,
      completedCount: completedCount ?? this.completedCount,
      uploadedSize: uploadedSize ?? this.uploadedSize,
      status: status ?? this.status,
      fileItems: fileItems ?? this.fileItems,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}