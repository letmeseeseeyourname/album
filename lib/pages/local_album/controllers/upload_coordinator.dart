// ============================================================
// UploadCoordinator 取消任务统计修复
// ============================================================
//
// 问题：取消任务后，upload_bottom_bar 中的文件个数和总大小没有减去
// 原因：取消任务时只是从 _activeTasks 中移除，但没有更新聚合进度的统计
//
// 解决方案：
// 1. 取消任务时，从统计中减去该任务的数据
// 2. 或者直接重新计算聚合进度（更简单可靠）
// ============================================================


// controllers/upload_coordinator.dart
// ✅ 修复版：取消任务时正确更新统计

import 'package:flutter/material.dart';
import '../../../album/manager/local_folder_upload_manager.dart';
import '../../../album/upload/models/local_upload_progress.dart';
import '../../../models/file_item.dart';
import '../services/file_service.dart';

/// 上传协调器 - 全局单例
class UploadCoordinator extends ChangeNotifier {
  // ========== 单例实现 ==========
  static UploadCoordinator? _instance;
  static FileService? _fileService;

  static void initialize(FileService fileService) {
    _fileService = fileService;
    _instance ??= UploadCoordinator._internal(fileService);
  }

  static UploadCoordinator get instance {
    if (_instance == null) {
      throw StateError(
        'UploadCoordinator 未初始化，请先调用 UploadCoordinator.initialize(fileService)',
      );
    }
    return _instance!;
  }

  static UploadCoordinator of([FileService? fileService]) {
    if (_instance == null && fileService != null) {
      initialize(fileService);
    }
    return instance;
  }

  // ========== 内部实现 ==========
  final FileService _internalFileService;

  final List<UploadTaskContext> _activeTasks = [];

  // ✅ 已完成任务的累计统计（不包括被取消的任务）
  int _completedTaskCount = 0;
  int _completedTotalFiles = 0;
  int _completedUploadedFiles = 0;
  int _completedFailedFiles = 0;
  int _completedTransferredBytes = 0;
  int _completedTotalBytes = 0;

  final List<String> _allUploadedMd5List = [];

  UploadCoordinator._internal(this._internalFileService);

  factory UploadCoordinator(LocalFolderUploadManager _, FileService fileService) {
    if (_instance == null) {
      initialize(fileService);
    }
    return _instance!;
  }

  bool get isUploading => _activeTasks.isNotEmpty;

  LocalUploadProgress? get uploadProgress {
    if (_activeTasks.isEmpty) return null;
    return _activeTasks.first.progress;
  }

  int get activeTaskCount => _activeTasks.length;

  int get totalTaskCount => _activeTasks.length + _completedTaskCount;

  List<String> get allUploadedMd5List => List.unmodifiable(_allUploadedMd5List);

  /// ✅ 获取聚合进度
  /// 注意：只统计活跃任务和已完成任务，不包括被取消的任务
  LocalUploadProgress? get aggregatedProgress {
    if (_activeTasks.isEmpty && _completedTaskCount == 0) return null;

    int totalFiles = _completedTotalFiles;
    int uploadedFiles = _completedUploadedFiles;
    int failedFiles = _completedFailedFiles;
    String? currentFileName;

    int globalTransferredBytes = _completedTransferredBytes;
    int globalTotalBytes = _completedTotalBytes;
    int currentSpeed = 0;

    for (final task in _activeTasks) {
      final progress = task.progress;
      if (progress != null) {
        totalFiles += progress.totalFiles;
        uploadedFiles += progress.uploadedFiles;
        failedFiles += progress.failedFiles;

        globalTransferredBytes += progress.globalTransferredBytes;
        globalTotalBytes += progress.globalTotalBytes;
        currentSpeed += progress.speed;

        if (currentFileName == null && progress.currentFileName != null) {
          currentFileName = progress.currentFileName;
        }
      }
    }

    final totalTaskCount = _completedTaskCount + _activeTasks.length;

    // 没有任何任务
    if (totalFiles == 0 && _activeTasks.isEmpty) {
      return null;
    }

    if (_activeTasks.isEmpty) {
      return LocalUploadProgress(
        totalFiles: totalFiles,
        uploadedFiles: uploadedFiles,
        failedFiles: failedFiles,
        currentFileName: null,
        statusMessage: '全部完成',
        globalTransferredBytes: globalTotalBytes,
        globalTotalBytes: globalTotalBytes,
        speed: 0,
      );
    }

    if (_activeTasks.length == 1 && _completedTaskCount == 0) {
      return _activeTasks.first.progress;
    }

    return LocalUploadProgress(
      totalFiles: totalFiles,
      uploadedFiles: uploadedFiles,
      failedFiles: failedFiles,
      currentFileName: currentFileName,
      statusMessage: '$totalTaskCount个任务并行上传中...',
      globalTransferredBytes: globalTransferredBytes,
      globalTotalBytes: globalTotalBytes,
      speed: currentSpeed,
    );
  }

  // ========== 任务查询方法 ==========

  /// 根据数据库 taskId 获取活跃任务
  UploadTaskContext? getActiveTaskByDbTaskId(int dbTaskId) {
    for (final task in _activeTasks) {
      if (task.dbTaskId == dbTaskId) {
        return task;
      }
      // 也检查 uploadManager 中保存的 dbTaskId
      if (task.uploadManager.currentDbTaskId == dbTaskId) {
        return task;
      }
    }
    return null;
  }

  /// 检查指定 dbTaskId 的任务是否正在上传
  bool isTaskUploading(int dbTaskId) {
    return getActiveTaskByDbTaskId(dbTaskId) != null;
  }

  /// 获取所有活跃任务的 dbTaskId 列表
  List<int> get activeDbTaskIds {
    final ids = <int>[];
    for (final task in _activeTasks) {
      if (task.dbTaskId != null) {
        ids.add(task.dbTaskId!);
      } else if (task.uploadManager.currentDbTaskId != null) {
        ids.add(task.uploadManager.currentDbTaskId!);
      }
    }
    return ids;
  }

  // ========== ✅ 取消任务方法（修复版）==========

  /// 根据数据库 taskId 取消特定任务
  /// ✅ 修复：取消后不计入已完成统计，直接从活跃任务移除
  Future<CancelTaskResult> cancelTaskById(int dbTaskId) async {
    UploadTaskContext? targetTask;
    int targetIndex = -1;

    // 查找任务
    for (int i = 0; i < _activeTasks.length; i++) {
      final task = _activeTasks[i];
      if (task.dbTaskId == dbTaskId ||
          task.uploadManager.currentDbTaskId == dbTaskId) {
        targetTask = task;
        targetIndex = i;
        break;
      }
    }

    if (targetTask == null || targetIndex == -1) {
      return CancelTaskResult(success: false, message: '任务不存在或已完成', taskWasActive: false,  );// ✅ 任务不在活跃列表
    }

    // 获取当前进度（用于返回信息）
    final progress = targetTask.progress;
    int cancelledFiles = 0;
    int cancelledBytes = 0;

    if (progress != null) {
      // 被取消的文件数 = 总数 - 已上传数
      cancelledFiles = progress.totalFiles - progress.uploadedFiles;
      // 被取消的字节数 = 总字节 - 已传输字节
      cancelledBytes = progress.globalTotalBytes - progress.globalTransferredBytes;
    }

    // ✅ 从活跃任务中移除（不计入已完成统计）
    _activeTasks.removeAt(targetIndex);

    // ✅ 调用 uploadManager 的取消方法（会终止 McService 进程）
    await targetTask.uploadManager.cancelUpload();

    // ✅ 立即通知监听器更新 UI
    notifyListeners();

    // 如果所有任务都完成/取消了，延迟清理累计数据
    if (_activeTasks.isEmpty) {
      Future.delayed(const Duration(seconds: 3), () {
        _resetCompletedStats();
        notifyListeners();
      });
    }

    return CancelTaskResult(
      success: true,
      message: '任务已取消',
      cancelledFiles: cancelledFiles,
      cancelledBytes: cancelledBytes,
      taskWasActive: true,  // ✅ 任务在活跃列表中被取消
    );
  }

  /// 取消所有上传任务
  Future<void> cancelAllUploads() async {
    debugPrint('[UploadCoordinator] 取消所有上传任务，共 ${_activeTasks.length} 个');

    // 复制列表，避免遍历时修改
    final tasksToCancel = List<UploadTaskContext>.from(_activeTasks);

    for (final task in tasksToCancel) {
      try {
        await task.uploadManager.cancelUpload();
      } catch (e) {
        debugPrint('[UploadCoordinator] 取消任务失败: $e');
      }
    }

    // 清空所有任务和统计
    _activeTasks.clear();
    _resetCompletedStats();
    _allUploadedMd5List.clear();

    notifyListeners();
  }

  // ========== 上传方法 ==========

  Future<UploadPrepareResult> prepareUpload(List<FileItem> selectedItems) async {
    final selectedFiles = selectedItems
        .where((item) => item.type != FileItemType.folder)
        .toList();
    final selectedFolders = selectedItems
        .where((item) => item.type == FileItemType.folder)
        .toList();

    final List<String> allFilesToUpload = [];

    allFilesToUpload.addAll(selectedFiles.map((item) => item.path));

    if (selectedFolders.isNotEmpty) {
      for (final folder in selectedFolders) {
        final filesInFolder =
        await _internalFileService.getAllMediaFilesRecursive(folder.path);
        allFilesToUpload.addAll(filesInFolder);
      }
    }

    final finalUploadList = allFilesToUpload.toSet().toList();

    if (finalUploadList.isEmpty) {
      return UploadPrepareResult(success: false, message: '没有可上传的媒体文件');
    }

    final analysis =
    await _internalFileService.analyzeFilesForUpload(finalUploadList);

    return UploadPrepareResult(
      success: true,
      filePaths: finalUploadList,
      imageCount: analysis.imageCount,
      videoCount: analysis.videoCount,
      totalSizeMB: analysis.totalBytes / (1024 * 1024),
    );
  }

  Future<void> startUpload(
      List<String> filePaths,
      Function(String message, {bool isError}) onMessage,
      Function(List<String> uploadedMd5s) onComplete, {
        int? dbTaskId,
      }) async {
    final uploadManager = LocalFolderUploadManager();

    final taskContext = UploadTaskContext(
      uploadManager: uploadManager,
      filePaths: filePaths,
      dbTaskId: dbTaskId,
    );

    _activeTasks.add(taskContext);
    notifyListeners();

    try {
      await uploadManager.uploadLocalFiles(
        filePaths,
        onProgress: (progress) {
          taskContext.progress = progress;
          notifyListeners();
        },
        onComplete: (success, message, uploadedMd5s) {
          final finalProgress = taskContext.progress;

          // ✅ 只有成功完成的任务才计入已完成统计
          if (success && finalProgress != null) {
            _completedTaskCount++;
            _completedTotalFiles += finalProgress.totalFiles;
            _completedUploadedFiles += finalProgress.uploadedFiles;
            _completedFailedFiles += finalProgress.failedFiles;
            _completedTransferredBytes += finalProgress.globalTotalBytes;
            _completedTotalBytes += finalProgress.globalTotalBytes;
          }

          if (uploadedMd5s.isNotEmpty) {
            _allUploadedMd5List.addAll(uploadedMd5s);
            taskContext.uploadedMd5s = uploadedMd5s;
          }

          _activeTasks.remove(taskContext);
          notifyListeners();

          // ✅ 修改：只有非空消息才显示
          if (message.isNotEmpty) {
            onMessage(message, isError: !success);
          }
          onComplete(uploadedMd5s);

          if (_activeTasks.isEmpty) {
            Future.delayed(const Duration(seconds: 3), () {
              _resetCompletedStats();
              notifyListeners();
            });
          }
        },
      );
    } catch (e) {
      // 异常时不计入已完成统计
      _activeTasks.remove(taskContext);
      notifyListeners();

      onMessage('上传失败: $e', isError: true);
      onComplete([]);

      if (_activeTasks.isEmpty) {
        Future.delayed(const Duration(seconds: 3), () {
          _resetCompletedStats();
          notifyListeners();
        });
      }
    }
  }

  Future<void> startUploadLegacy(
      List<String> filePaths,
      Function(String message, {bool isError}) onMessage,
      Function() onComplete,
      ) async {
    await startUpload(
      filePaths,
      onMessage,
          (_) => onComplete(),
    );
  }

  void _resetCompletedStats() {
    _completedTaskCount = 0;
    _completedTotalFiles = 0;
    _completedUploadedFiles = 0;
    _completedFailedFiles = 0;
    _completedTransferredBytes = 0;
    _completedTotalBytes = 0;
    _allUploadedMd5List.clear();
  }

  List<LocalUploadProgress?> getAllTaskProgress() {
    return _activeTasks.map((task) => task.progress).toList();
  }

  @visibleForTesting
  static void reset() {
    if (_instance != null) {
      // 先取消所有任务
      _instance!.cancelAllUploads();

      // 清理内部状态
      _instance!._activeTasks.clear();
      _instance!._resetCompletedStats();
      _instance!._allUploadedMd5List.clear();

      // 移除所有监听器
      _instance!.dispose();
    }

    // 重置单例
    _instance = null;
    _fileService = null;
  }
}


/// 取消任务结果
class CancelTaskResult {
  final bool success;
  final String message;
  final int cancelledFiles;
  final int cancelledBytes;
  final bool taskWasActive;  // ✅ 新增：任务是否在活跃列表中
  CancelTaskResult({
    required this.success,
    required this.message,
    this.cancelledFiles = 0,
    this.cancelledBytes = 0,
    this.taskWasActive = false,
  });
}


/// 上传协调器 Mixin
mixin UploadCoordinatorMixin<T extends StatefulWidget> on State<T> {
  late final UploadCoordinator _uploadCoordinator;

  bool get isUploading => _uploadCoordinator.isUploading;

  LocalUploadProgress? get uploadProgress => _uploadCoordinator.aggregatedProgress;

  int get activeTaskCount => _uploadCoordinator.totalTaskCount;

  UploadCoordinator get uploadCoordinator => _uploadCoordinator;

  @override
  void initState() {
    super.initState();
    _uploadCoordinator = UploadCoordinator.instance;
    _uploadCoordinator.addListener(_onUploadStateChanged);
  }

  @override
  void dispose() {
    _uploadCoordinator.removeListener(_onUploadStateChanged);
    super.dispose();
  }

  void _onUploadStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }
}


/// 上传任务上下文
class UploadTaskContext {
  final LocalFolderUploadManager uploadManager;
  final List<String> filePaths;
  final int? dbTaskId;
  LocalUploadProgress? progress;
  List<String> uploadedMd5s;

  UploadTaskContext({
    required this.uploadManager,
    required this.filePaths,
    this.dbTaskId,
    this.progress,
    this.uploadedMd5s = const [],
  });
}


/// 上传准备结果
class UploadPrepareResult {
  final bool success;
  final String? message;
  final List<String>? filePaths;
  final int? imageCount;
  final int? videoCount;
  final double? totalSizeMB;

  UploadPrepareResult({
    required this.success,
    this.message,
    this.filePaths,
    this.imageCount,
    this.videoCount,
    this.totalSizeMB,
  });
}