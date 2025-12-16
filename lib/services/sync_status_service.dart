// services/sync_status_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../album/provider/album_provider.dart';
import '../user/models/resource_list_model.dart';
import '../user/models/recycle_resource_model.dart';

/// 同步状态服务 - 通过比对服务端 resId 与本地文件 MD5 判断同步状态
class SyncStatusService {
  static final SyncStatusService _instance = SyncStatusService._internal();
  static SyncStatusService get instance => _instance;
  SyncStatusService._internal();

  final AlbumProvider _albumProvider = AlbumProvider();

  // ═══════════════════════════════════════════════════════════════
  // 缓存：服务端已存在的 resId (MD5) 集合
  // ═══════════════════════════════════════════════════════════════
  Set<String> _serverResIds = {};

  // 本地文件 MD5 缓存 (path -> md5)
  final Map<String, String> _localMd5Cache = {};

  // 缓存有效期
  DateTime? _lastFetchTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  // 加载状态
  bool _isLoading = false;
  bool _isInitialized = false;

  // MD5 计算配置（与 LocalFolderUploadManager 保持一致）
  static const int _md5ReadSizeBytes = 1024 * 1024; // 1MB

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 是否正在加载
  bool get isLoading => _isLoading;

  // ═══════════════════════════════════════════════════════════════
  // 初始化：从服务端拉取完整文件列表
  // ═══════════════════════════════════════════════════════════════

  /// 初始化服务端 resId 缓存
  ///
  /// [forceRefresh] 是否强制刷新缓存
  Future<void> initialize({bool forceRefresh = false}) async {
    // 检查缓存是否有效
    if (!forceRefresh && _isCacheValid()) {
      return;
    }

    if (_isLoading) return;
    _isLoading = true;

    try {
      final resIds = <String>{};

      // 1. 获取普通资源列表（非私密）
      await _fetchAllResources(resIds, isPrivate: false);

      // 2. 获取私密资源列表
      await _fetchAllResources(resIds, isPrivate: true);

      // 3. 获取回收站资源列表
      await _fetchAllRecycleResources(resIds);

      _serverResIds = resIds;
      _lastFetchTime = DateTime.now();
      _isInitialized = true;

      debugPrint('[SyncStatusService] 初始化完成，服务端文件数: ${_serverResIds.length}');
    } catch (e) {
      debugPrint('[SyncStatusService] 初始化失败: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// 分页获取所有普通资源
  Future<void> _fetchAllResources(Set<String> resIds, {required bool isPrivate}) async {
    int page = 1;
    bool hasMore = true;

    while (hasMore) {
      try {
        final response = await _albumProvider.listResources(
          page,
          isPrivate: isPrivate,
          pageSize: AlbumProvider.myPageSize,
        );

        if (response.isSuccess && response.model != null) {
          final resList = response.model!.resList;

          for (final res in resList) {
            if (res.resId != null && res.resId!.isNotEmpty) {
              resIds.add(res.resId!);
            }
          }

          // 判断是否还有更多数据
          hasMore = resList.length >= AlbumProvider.myPageSize;
          page++;
        } else {
          hasMore = false;
        }
      } catch (e) {
        debugPrint('[SyncStatusService] 获取资源列表失败 (page=$page, isPrivate=$isPrivate): $e');
        hasMore = false;
      }
    }
  }

  /// 分页获取所有回收站资源
  Future<void> _fetchAllRecycleResources(Set<String> resIds) async {
    int page = 1;
    bool hasMore = true;

    while (hasMore) {
      try {
        final response = await _albumProvider.listRecycleFiles(page);

        if (response.isSuccess && response.model != null) {
          final recycleList = response.model!.recycleList ?? [];

          for (final item in recycleList) {
            if (item.resId != null && item.resId!.isNotEmpty) {
              resIds.add(item.resId!);
            }
          }

          hasMore = recycleList.length >= AlbumProvider.myPageSize;
          page++;
        } else {
          hasMore = false;
        }
      } catch (e) {
        debugPrint('[SyncStatusService] 获取回收站列表失败 (page=$page): $e');
        hasMore = false;
      }
    }
  }

  /// 检查缓存是否有效
  bool _isCacheValid() {
    if (!_isInitialized || _lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheValidDuration;
  }

  // ═══════════════════════════════════════════════════════════════
  // 同步状态判断
  // ═══════════════════════════════════════════════════════════════

  /// 检查单个文件是否已同步
  ///
  /// [filePath] 本地文件路径
  /// Returns: true=已同步, false=未同步, null=无法判断（服务未初始化）
  Future<bool?> isFileSynced(String filePath) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isInitialized) return null;

    try {
      final md5 = await _getFileMd5(filePath);
      return _serverResIds.contains(md5);
    } catch (e) {
      debugPrint('[SyncStatusService] 检查文件同步状态失败: $filePath, $e');
      return null;
    }
  }

  /// 批量检查文件同步状态
  ///
  /// [filePaths] 本地文件路径列表
  /// Returns: Map<filePath, isUploaded>
  Future<Map<String, bool>> checkSyncStatusBatch(List<String> filePaths) async {
    if (!_isInitialized) {
      await initialize();
    }

    final result = <String, bool>{};

    if (!_isInitialized) {
      // 服务未初始化，全部返回 false（显示未同步图标）
      for (final path in filePaths) {
        result[path] = false;
      }
      return result;
    }

    // 并行计算 MD5（使用 Isolate 优化性能）
    final md5Map = await _computeMd5Batch(filePaths);

    for (final entry in md5Map.entries) {
      result[entry.key] = _serverResIds.contains(entry.value);
    }

    return result;
  }

  /// 批量计算文件 MD5
  Future<Map<String, String>> _computeMd5Batch(List<String> filePaths) async {
    final result = <String, String>{};

    // 使用 compute 在独立 Isolate 中计算以避免阻塞 UI
    for (final path in filePaths) {
      // 优先使用缓存
      if (_localMd5Cache.containsKey(path)) {
        result[path] = _localMd5Cache[path]!;
        continue;
      }

      try {
        final md5Hash = await _getFileMd5(path);
        _localMd5Cache[path] = md5Hash;
        result[path] = md5Hash;
      } catch (e) {
        debugPrint('[SyncStatusService] MD5 计算失败: $path');
      }
    }

    return result;
  }

  /// 计算文件 MD5（与 LocalFolderUploadManager 保持一致）
  Future<String> _getFileMd5(String filePath) async {
    final file = File(filePath);
    final bytes = await _readFileMax1M(file);
    return md5.convert(bytes).toString();
  }

  /// 读取文件前 1MB（与 LocalFolderUploadManager 保持一致）
  Future<Uint8List> _readFileMax1M(File file) async {
    final raf = await file.open();
    try {
      final fileSize = await file.length();
      final readSize = fileSize > _md5ReadSizeBytes ? _md5ReadSizeBytes : fileSize;
      final bytes = await raf.read(readSize);
      return Uint8List.fromList(bytes);
    } finally {
      await raf.close();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 缓存管理
  // ═══════════════════════════════════════════════════════════════

  /// 刷新缓存
  Future<void> refresh() async {
    await initialize(forceRefresh: true);
  }

  /// 添加 resId 到缓存（上传成功后调用）
  void addSyncedResId(String resId) {
    _serverResIds.add(resId);
  }

  /// 批量添加 resId
  void addSyncedResIds(List<String> resIds) {
    _serverResIds.addAll(resIds);
  }

  /// 移除 resId（删除文件后调用）
  void removeSyncedResId(String resId) {
    _serverResIds.remove(resId);
  }

  /// 清除本地 MD5 缓存
  void clearLocalMd5Cache() {
    _localMd5Cache.clear();
  }

  /// 清除所有缓存
  void clearAll() {
    _serverResIds.clear();
    _localMd5Cache.clear();
    _lastFetchTime = null;
    _isInitialized = false;
  }
}