// services/global_upload_service.dart
// 全局上传状态服务（单例）
// 解决切换页面后上传状态丢失的问题

import 'package:flutter/material.dart';
import '../album/manager/local_folder_upload_manager.dart';

/// 全局上传状态服务
///
/// 单例模式，确保上传状态在整个应用中共享。
/// 任何页面都可以监听上传状态变化。
///
/// 使用方式：
/// ```dart
/// // 获取实例
/// final service = GlobalUploadService.instance;
///
/// // 监听状态变化
/// service.addListener(() {
///   print('上传状态: ${service.isUploading}');
/// });
///
/// // 开始上传
/// await service.uploadFiles(filePaths, onComplete: (success, msg) {});
/// ```
class GlobalUploadService extends ChangeNotifier {
  // 单例实例
  static final GlobalUploadService _instance = GlobalUploadService._internal();
  static GlobalUploadService get instance => _instance;

  // 内部上传管理器
  final LocalFolderUploadManager _uploadManager = LocalFolderUploadManager();

  // 私有构造函数
  GlobalUploadService._internal() {
    // 监听内部管理器的变化，转发通知
    _uploadManager.addListener(_onUploadManagerChanged);
  }

  /// 是否正在上传
  bool get isUploading => _uploadManager.isUploading;

  /// 当前上传进度
  LocalUploadProgress? get currentProgress => _uploadManager.currentProgress;

  /// 失败队列
  List<FailedFileRecord> get failedQueue => _uploadManager.failedQueue;

  /// 永久失败文件
  List<FailedFileRecord> get permanentlyFailedFiles =>
      _uploadManager.permanentlyFailedFiles;

  /// 内部管理器变化回调
  void _onUploadManagerChanged() {
    notifyListeners();
  }

  /// 上传本地文件
  ///
  /// [filePaths] 文件路径列表
  /// [onProgress] 进度回调（可选，状态也会通过 notifyListeners 通知）
  /// [onComplete] 完成回调
  Future<void> uploadFiles(
      List<String> filePaths, {
        void Function(LocalUploadProgress)? onProgress,
        required void Function(bool success, String message) onComplete,
      }) async {
    // await _uploadManager.uploadLocalFiles(
    //   filePaths,
    //   onProgress: onProgress,
    //   onComplete: onComplete,
    // );
  }

  /// 取消上传
  void cancelUpload() {
    _uploadManager.cancelUpload();
  }

  @override
  void dispose() {
    _uploadManager.removeListener(_onUploadManagerChanged);
    super.dispose();
  }
}

/// 全局上传状态 Mixin
///
/// 为 StatefulWidget 提供便捷的上传状态监听能力。
///
/// 使用方式：
/// ```dart
/// class _MyPageState extends State<MyPage> with GlobalUploadMixin {
///   @override
///   Widget build(BuildContext context) {
///     return UploadBottomBar(
///       isUploading: isUploading,
///       uploadProgress: uploadProgress,
///       // ...
///     );
///   }
/// }
/// ```
mixin GlobalUploadMixin<T extends StatefulWidget> on State<T> {
  late final GlobalUploadService _uploadService;

  /// 是否正在上传
  bool get isUploading => _uploadService.isUploading;

  /// 当前上传进度
  LocalUploadProgress? get uploadProgress => _uploadService.currentProgress;

  /// 上传服务实例（用于调用上传方法）
  GlobalUploadService get uploadService => _uploadService;

  @override
  void initState() {
    super.initState();
    _uploadService = GlobalUploadService.instance;
    _uploadService.addListener(_onUploadStateChanged);
  }

  @override
  void dispose() {
    _uploadService.removeListener(_onUploadStateChanged);
    super.dispose();
  }

  void _onUploadStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }
}