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
          // 从活跃任务中移除
          _activeTasks.remove(taskContext);
          notifyListeners();

          // 回调通知
          onMessage(message, isError: !success);
          onComplete();
        },
      );
    } catch (e) {
      // 异常时也要清理任务
      _activeTasks.remove(taskContext);
      notifyListeners();

      onMessage('上传失败: $e', isError: true);
      onComplete();
    }
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

  /// 当前上传进度
  LocalUploadProgress? get uploadProgress => _uploadCoordinator.uploadProgress;

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