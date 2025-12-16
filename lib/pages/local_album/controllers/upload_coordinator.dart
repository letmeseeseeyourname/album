// controllers/upload_coordinator.dart
// ============ 全局单例版本 - 支持跨页面上传状态共享 ============

import 'package:flutter/material.dart';
import '../../../album/manager/local_folder_upload_manager.dart';
import '../../../models/file_item.dart';
import '../services/file_service.dart';

/// 上传协调器 - 全局单例
///
/// ✅ 改进：
/// 1. 单例模式，确保上传状态全局共享
/// 2. 切换页面后上传进度条仍然显示
/// 3. 支持多任务并发
class UploadCoordinator extends ChangeNotifier {
  // ========== 单例实现 ==========
  static UploadCoordinator? _instance;
  static FileService? _fileService;

  /// 初始化单例（应用启动时调用一次）
  static void initialize(FileService fileService) {
    _fileService = fileService;
    _instance ??= UploadCoordinator._internal(fileService);
  }

  /// 获取单例实例
  static UploadCoordinator get instance {
    if (_instance == null) {
      throw StateError(
        'UploadCoordinator 未初始化，请先调用 UploadCoordinator.initialize(fileService)',
      );
    }
    return _instance!;
  }

  /// 便捷方法：获取实例（如果未初始化则使用默认 FileService）
  static UploadCoordinator of([FileService? fileService]) {
    if (_instance == null && fileService != null) {
      initialize(fileService);
    }
    return instance;
  }

  // ========== 内部实现 ==========
  final FileService _internalFileService;

  // 活跃的上传任务列表
  final List<UploadTaskContext> _activeTasks = [];

  // ✅ 已完成任务的累计统计（用于聚合进度显示）
  int _completedTaskCount = 0;
  int _completedTotalFiles = 0;
  int _completedUploadedFiles = 0;
  int _completedFailedFiles = 0;

  // 私有构造函数
  UploadCoordinator._internal(this._internalFileService);

  /// @deprecated 保留旧构造函数以兼容现有代码，但建议使用单例
  /// 如果调用此构造函数，会返回单例实例
  factory UploadCoordinator(LocalFolderUploadManager _, FileService fileService) {
    if (_instance == null) {
      initialize(fileService);
    }
    return _instance!;
  }

  /// 获取是否有上传任务进行中
  bool get isUploading => _activeTasks.isNotEmpty;

  /// 获取当前上传进度 (返回第一个任务的进度作为主进度)
  LocalUploadProgress? get uploadProgress {
    if (_activeTasks.isEmpty) return null;
    return _activeTasks.first.progress;
  }

  /// 活跃任务数量
  int get activeTaskCount => _activeTasks.length;

  /// 总任务数量（活跃 + 已完成，用于 UI 显示）
  int get totalTaskCount => _activeTasks.length + _completedTaskCount;

  /// 获取聚合进度（合并所有任务的进度，包括已完成的任务）
  LocalUploadProgress? get aggregatedProgress {
    // 没有活跃任务且没有已完成任务时返回 null
    if (_activeTasks.isEmpty && _completedTaskCount == 0) return null;

    // 聚合：已完成任务 + 活跃任务
    int totalFiles = _completedTotalFiles;
    int uploadedFiles = _completedUploadedFiles;
    int failedFiles = _completedFailedFiles;
    String? currentFileName;

    for (final task in _activeTasks) {
      final progress = task.progress;
      if (progress != null) {
        totalFiles += progress.totalFiles;
        uploadedFiles += progress.uploadedFiles;
        failedFiles += progress.failedFiles;
        // 取第一个正在上传的文件名
        if (currentFileName == null && progress.currentFileName != null) {
          currentFileName = progress.currentFileName;
        }
      }
    }

    // 计算总任务数
    final totalTaskCount = _completedTaskCount + _activeTasks.length;

    // 所有任务都完成了
    if (_activeTasks.isEmpty) {
      return LocalUploadProgress(
        totalFiles: totalFiles,
        uploadedFiles: uploadedFiles,
        failedFiles: failedFiles,
        currentFileName: null,
        statusMessage: '全部完成',
      );
    }

    // 只有一个活跃任务且没有已完成任务时，直接返回该任务进度
    if (_activeTasks.length == 1 && _completedTaskCount == 0) {
      return _activeTasks.first.progress;
    }

    return LocalUploadProgress(
      totalFiles: totalFiles,
      uploadedFiles: uploadedFiles,
      failedFiles: failedFiles,
      currentFileName: currentFileName,
      statusMessage: '$totalTaskCount个任务并行上传中...',
    );
  }

  /// 准备上传文件列表
  Future<UploadPrepareResult> prepareUpload(List<FileItem> selectedItems) async {
    // 分离文件和文件夹
    final selectedFiles = selectedItems
        .where((item) => item.type != FileItemType.folder)
        .toList();
    final selectedFolders = selectedItems
        .where((item) => item.type == FileItemType.folder)
        .toList();

    // 构建最终待上传文件列表
    final List<String> allFilesToUpload = [];

    // 添加单独选中的文件路径
    allFilesToUpload.addAll(selectedFiles.map((item) => item.path));

    // 递归处理选中的文件夹
    if (selectedFolders.isNotEmpty) {
      for (final folder in selectedFolders) {
        final filesInFolder =
        await _internalFileService.getAllMediaFilesRecursive(folder.path);
        allFilesToUpload.addAll(filesInFolder);
      }
    }

    // 移除重复路径
    final finalUploadList = allFilesToUpload.toSet().toList();

    if (finalUploadList.isEmpty) {
      return UploadPrepareResult(success: false, message: '没有可上传的媒体文件');
    }

    // 分析文件
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

  /// 开始上传
  Future<void> startUpload(
      List<String> filePaths,
      Function(String message, {bool isError}) onMessage,
      Function() onComplete,
      ) async {
    // 创建独立的上传管理器实例 (支持多任务并发)
    final uploadManager = LocalFolderUploadManager();

    // 创建任务上下文
    final taskContext = UploadTaskContext(
      uploadManager: uploadManager,
      filePaths: filePaths,
    );

    // 添加到活跃任务列表
    _activeTasks.add(taskContext);
    notifyListeners();

    try {
      await uploadManager.uploadLocalFiles(
        filePaths,
        onProgress: (progress) {
          // 更新任务进度
          taskContext.progress = progress;
          notifyListeners();
        },
        onComplete: (success, message) {
          // ✅ 累计已完成任务的统计数据
          final finalProgress = taskContext.progress;
          if (finalProgress != null) {
            _completedTaskCount++;
            _completedTotalFiles += finalProgress.totalFiles;
            _completedUploadedFiles += finalProgress.uploadedFiles;
            _completedFailedFiles += finalProgress.failedFiles;
          }

          // 从活跃任务中移除
          _activeTasks.remove(taskContext);
          notifyListeners();

          // 回调通知
          onMessage(message, isError: !success);
          onComplete();

          // ✅ 所有任务完成后，延迟清理累计数据（让UI有时间显示最终状态）
          if (_activeTasks.isEmpty) {
            Future.delayed(const Duration(seconds: 3), () {
              _resetCompletedStats();
              notifyListeners();
            });
          }
        },
      );
    } catch (e) {
      // ✅ 异常时也要累计统计数据
      final finalProgress = taskContext.progress;
      if (finalProgress != null) {
        _completedTaskCount++;
        _completedTotalFiles += finalProgress.totalFiles;
        _completedUploadedFiles += finalProgress.uploadedFiles;
        _completedFailedFiles += finalProgress.failedFiles;
      }

      // 异常时也要清理任务
      _activeTasks.remove(taskContext);
      notifyListeners();

      onMessage('上传失败: $e', isError: true);
      onComplete();

      // ✅ 所有任务完成后，延迟清理累计数据
      if (_activeTasks.isEmpty) {
        Future.delayed(const Duration(seconds: 3), () {
          _resetCompletedStats();
          notifyListeners();
        });
      }
    }
  }

  /// 重置已完成任务的累计统计
  void _resetCompletedStats() {
    _completedTaskCount = 0;
    _completedTotalFiles = 0;
    _completedUploadedFiles = 0;
    _completedFailedFiles = 0;
  }

  /// 获取所有活跃任务的进度信息 (供高级 UI 使用)
  List<LocalUploadProgress?> getAllTaskProgress() {
    return _activeTasks.map((task) => task.progress).toList();
  }

  /// 取消所有上传任务
  Future<void> cancelAllUploads() async {
    for (final task in _activeTasks) {
      task.uploadManager.cancelUpload();
    }
    _activeTasks.clear();
    _resetCompletedStats();  // ✅ 取消时也清理累计数据
    notifyListeners();
  }

  /// 重置单例（仅用于测试）
  @visibleForTesting
  static void reset() {
    _instance?.dispose();
    _instance = null;
    _fileService = null;
  }
}

/// 上传协调器 Mixin
///
/// 为 StatefulWidget 提供便捷的上传状态监听能力。
/// 使用后自动监听 UploadCoordinator 状态变化并刷新 UI。
///
/// 使用方式：
/// ```dart
/// class _MyPageState extends State<MyPage> with UploadCoordinatorMixin {
///   @override
///   Widget build(BuildContext context) {
///     return UploadBottomBar(
///       isUploading: isUploading,        // 来自 Mixin
///       uploadProgress: uploadProgress,   // 来自 Mixin
///       // ...
///     );
///   }
/// }
/// ```
mixin UploadCoordinatorMixin<T extends StatefulWidget> on State<T> {
  late final UploadCoordinator _uploadCoordinator;

  /// 是否正在上传
  bool get isUploading => _uploadCoordinator.isUploading;

  /// 当前上传进度（聚合所有任务）
  LocalUploadProgress? get uploadProgress => _uploadCoordinator.aggregatedProgress;

  /// 总任务数量（活跃 + 已完成）
  int get activeTaskCount => _uploadCoordinator.totalTaskCount;

  /// 上传协调器实例（用于调用上传方法）
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
  LocalUploadProgress? progress;

  UploadTaskContext({
    required this.uploadManager,
    required this.filePaths,
    this.progress,
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