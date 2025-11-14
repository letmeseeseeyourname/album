// controllers/upload_coordinator_fixed.dart
// ============ 修复 Stack Overflow 错误的版本 ============
import 'package:flutter/material.dart';
import '../../../album/manager/local_folder_upload_manager.dart';
import '../../../models/file_item.dart';
import '../services/file_service.dart';

/// 上传协调器 - 负责协调上传流程
///
/// ✅ 修复版: 继承 ChangeNotifier,避免循环调用
class UploadCoordinator extends ChangeNotifier {
  final FileService _fileService;

  // 活跃的上传任务列表
  final List<UploadTaskContext> _activeTasks = [];

  UploadCoordinator(LocalFolderUploadManager _, this._fileService);

  /// 获取是否有上传任务进行中
  bool get isUploading => _activeTasks.isNotEmpty;

  /// 获取当前上传进度 (返回第一个任务的进度作为主进度)
  LocalUploadProgress? get uploadProgress {
    if (_activeTasks.isEmpty) return null;
    return _activeTasks.first.progress;
  }

  // ✅ 使用 ChangeNotifier 的内置方法,不需要自定义监听器管理
  // addListener() 和 removeListener() 由 ChangeNotifier 提供
  // notifyListeners() 由 ChangeNotifier 提供

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
        final filesInFolder = await _fileService.getAllMediaFilesRecursive(folder.path);
        allFilesToUpload.addAll(filesInFolder);
      }
    }

    // 移除重复路径
    final finalUploadList = allFilesToUpload.toSet().toList();

    if (finalUploadList.isEmpty) {
      return UploadPrepareResult(success: false, message: '没有可上传的媒体文件');
    }

    // 分析文件
    final analysis = await _fileService.analyzeFilesForUpload(finalUploadList);

    return UploadPrepareResult(
      success: true,
      filePaths: finalUploadList,
      imageCount: analysis.imageCount,
      videoCount: analysis.videoCount,
      totalSizeMB: analysis.totalBytes / (1024 * 1024),
    );
  }

  /// 开始上传
  ///
  /// ✅ 修复: 直接使用 notifyListeners(),不需要中间方法
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
    notifyListeners();  // ✅ 直接调用 ChangeNotifier 的方法

    try {
      await uploadManager.uploadLocalFiles(
        filePaths,
        onProgress: (progress) {
          // 更新任务进度
          taskContext.progress = progress;
          notifyListeners();  // ✅ 直接通知,不需要额外的 updateProgress 方法
        },
        onComplete: (success, message) {
          // 从活跃任务中移除
          _activeTasks.remove(taskContext);
          notifyListeners();  // ✅ 直接通知

          // 回调通知
          onMessage(message, isError: !success);
          onComplete();
        },
      );
    } catch (e) {
      // 异常时也要清理任务
      _activeTasks.remove(taskContext);
      notifyListeners();  // ✅ 直接通知

      onMessage('上传失败: $e', isError: true);
      onComplete();
    }
  }

  /// 获取所有活跃任务的进度信息 (供高级 UI 使用)
  List<LocalUploadProgress?> getAllTaskProgress() {
    return _activeTasks.map((task) => task.progress).toList();
  }

  /// 取消所有上传任务 (可选功能)
  Future<void> cancelAllUploads() async {
    _activeTasks.clear();
    notifyListeners();  // ✅ 直接通知
  }
}

/// 上传任务上下文
/// 用于管理单个上传任务的状态
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