// utils/transfer_data_generator.dart
import 'dart:math';
import '../models/transfer_task_model.dart';

/// 传输数据生成器 - 用于测试和演示
class TransferDataGenerator {
  static final _random = Random();

  /// 生成示例传输任务
  static TransferTaskModel generateSampleTask({
    int? taskId,
    TransferTaskStatus? status,
    int? fileCount,
  }) {
    final id = taskId ?? _random.nextInt(10000);
    final count = fileCount ?? _random.nextInt(500) + 50;
    final totalSize = count * (_random.nextInt(10) + 1) * 1024 * 1024; // MB

    final task = TransferTaskModel(
      taskId: id,
      createTime: DateTime.now().subtract(Duration(
        hours: _random.nextInt(24),
        minutes: _random.nextInt(60),
      )),
      totalCount: count,
      totalSize: totalSize,
      status: status ?? _randomStatus(),
    );

    // 生成文件列表
    task.fileItems = _generateFileItems(count, totalSize, task.status);

    // 计算已上传数量和大小
    if (task.status != TransferTaskStatus.uploading) {
      task.completedCount = task.status == TransferTaskStatus.completed ? count : _random.nextInt(count);
      task.uploadedSize = task.status == TransferTaskStatus.completed
          ? totalSize
          : (totalSize * task.completedCount / count).toInt();
    }

    return task;
  }

  /// 生成多个示例任务
  static List<TransferTaskModel> generateSampleTasks(int count) {
    return List.generate(count, (index) {
      // 第一个任务设置为正在上传
      if (index == 0) {
        return generateSampleTask(
          taskId: index + 1,
          status: TransferTaskStatus.uploading,
          fileCount: 480,
        );
      }
      // 其他任务随机状态
      return generateSampleTask(
        taskId: index + 1,
        fileCount: 480,
      );
    });
  }

  /// 生成文件列表
  static List<TransferFileItem> _generateFileItems(
      int count,
      int totalSize,
      TransferTaskStatus taskStatus,
      ) {
    final fileNames = [
      'IMG_0001.jpg', 'IMG_0002.jpg', 'IMG_0003.jpg', 'IMG_0004.jpg',
      'VID_0001.mp4', 'VID_0002.mp4', 'VID_0003.mp4',
      'photo_sunset.jpg', 'photo_beach.jpg', 'photo_mountain.jpg',
      'video_trip.mp4', 'video_party.mp4',
    ];

    return List.generate(min(count, 20), (index) {
      final fileName = index < fileNames.length
          ? fileNames[index]
          : 'FILE_${(index + 1).toString().padLeft(4, '0')}.jpg';

      final fileSize = totalSize ~/ count;

      TransferTaskStatus fileStatus;
      double progress;

      if (taskStatus == TransferTaskStatus.uploading) {
        // 正在上传的任务,部分文件完成,部分进行中
        if (index < count * 0.6) {
          fileStatus = TransferTaskStatus.completed;
          progress = 1.0;
        } else if (index < count * 0.8) {
          fileStatus = TransferTaskStatus.uploading;
          progress = _random.nextDouble() * 0.8 + 0.1;
        } else {
          fileStatus = TransferTaskStatus.uploading;
          progress = 0.0;
        }
      } else {
        // 其他状态的任务
        fileStatus = taskStatus;
        progress = taskStatus == TransferTaskStatus.completed ? 1.0 : 0.5;
      }

      return TransferFileItem(
        fileName: fileName,
        filePath: '/path/to/$fileName',
        fileSize: fileSize,
        progress: progress,
        status: fileStatus,
        uploadedSize: (fileSize * progress).toInt(),
      );
    });
  }

  /// 随机状态
  static TransferTaskStatus _randomStatus() {
    final statuses = [
      TransferTaskStatus.completed,
      TransferTaskStatus.completed,
      TransferTaskStatus.completed,
      TransferTaskStatus.paused,
    ];
    return statuses[_random.nextInt(statuses.length)];
  }

  /// 模拟进度更新
  static void simulateProgress(TransferTaskModel task) {
    if (task.status != TransferTaskStatus.uploading) return;

    // 更新正在上传的文件
    for (int i = 0; i < task.fileItems.length; i++) {
      final file = task.fileItems[i];
      if (file.status == TransferTaskStatus.uploading && file.progress < 1.0) {
        final newProgress = min(1.0, file.progress + _random.nextDouble() * 0.1);
        final newUploadedSize = (file.fileSize * newProgress).toInt();
        task.updateFileProgress(i, newProgress, newUploadedSize);
        break; // 一次只更新一个文件
      }
    }
  }
}