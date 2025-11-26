// services/media_cache_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import '../../../models/file_item.dart';
import '../../../services/thumbnail_helper.dart';

/// 媒体缓存服务 - 统一管理宽高比和视频缩略图缓存
///
/// 单例模式，跨组件共享缓存数据
class MediaCacheService {
  // 单例
  static final MediaCacheService _instance = MediaCacheService._();
  static MediaCacheService get instance => _instance;
  MediaCacheService._();

  // 宽高比缓存
  final Map<String, double> _aspectRatioCache = {};

  // 视频缩略图路径缓存
  final Map<String, String> _thumbnailCache = {};

  // 正在加载的路径集合（防止重复加载）
  final Set<String> _loadingAspectRatioPaths = {};
  final Set<String> _loadingThumbnailPaths = {};

  // 缓存更新通知
  final _cacheUpdateController = StreamController<CacheUpdateEvent>.broadcast();
  Stream<CacheUpdateEvent> get onCacheUpdate => _cacheUpdateController.stream;

  // 默认宽高比
  static const double defaultImageAspectRatio = 4 / 3;
  static const double defaultVideoAspectRatio = 16 / 9;
  static const double folderAspectRatio = 1.0;

  /// 获取宽高比（同步，如果未缓存则返回默认值）
  double getAspectRatio(String path, FileItemType type) {
    if (type == FileItemType.folder) {
      return folderAspectRatio;
    }
    if (_aspectRatioCache.containsKey(path)) {
      return _aspectRatioCache[path]!;
    }
    return type == FileItemType.video
        ? defaultVideoAspectRatio
        : defaultImageAspectRatio;
  }

  /// 检查宽高比是否已缓存
  bool hasAspectRatio(String path) {
    return _aspectRatioCache.containsKey(path);
  }

  /// 获取视频缩略图路径（同步，可能为null）
  String? getVideoThumbnail(String path) {
    return _thumbnailCache[path];
  }

  /// 检查视频缩略图是否已缓存
  bool hasThumbnail(String path) {
    return _thumbnailCache.containsKey(path);
  }

  /// 检查是否正在加载宽高比
  bool isLoadingAspectRatio(String path) {
    return _loadingAspectRatioPaths.contains(path);
  }

  /// 检查是否正在加载缩略图
  bool isLoadingThumbnail(String path) {
    return _loadingThumbnailPaths.contains(path);
  }

  /// 预加载单个文件的宽高比
  Future<double?> preloadAspectRatio(FileItem item) async {
    if (item.type == FileItemType.folder) {
      return folderAspectRatio;
    }

    if (_aspectRatioCache.containsKey(item.path)) {
      return _aspectRatioCache[item.path];
    }

    if (_loadingAspectRatioPaths.contains(item.path)) {
      return null; // 正在加载中
    }

    _loadingAspectRatioPaths.add(item.path);

    try {
      final file = File(item.path);
      if (!await file.exists()) {
        _loadingAspectRatioPaths.remove(item.path);
        return null;
      }

      double aspectRatio;

      if (item.type == FileItemType.image) {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 100);
        final frame = await codec.getNextFrame();
        final image = frame.image;

        aspectRatio = image.width / image.height;

        image.dispose();
        codec.dispose();
      } else {
        aspectRatio = defaultVideoAspectRatio;
      }

      _aspectRatioCache[item.path] = aspectRatio;
      _loadingAspectRatioPaths.remove(item.path);

      // 通知缓存更新
      _cacheUpdateController.add(CacheUpdateEvent(
        type: CacheUpdateType.aspectRatio,
        path: item.path,
      ));

      return aspectRatio;
    } catch (e) {
      _loadingAspectRatioPaths.remove(item.path);
      final defaultRatio = item.type == FileItemType.video
          ? defaultVideoAspectRatio
          : defaultImageAspectRatio;
      _aspectRatioCache[item.path] = defaultRatio;
      return defaultRatio;
    }
  }

  /// 预加载视频缩略图
  Future<String?> preloadVideoThumbnail(String videoPath) async {
    if (_thumbnailCache.containsKey(videoPath)) {
      return _thumbnailCache[videoPath];
    }

    if (_loadingThumbnailPaths.contains(videoPath)) {
      return null; // 正在加载中
    }

    _loadingThumbnailPaths.add(videoPath);

    try {
      if (kDebugMode) {
        print('MediaCacheService: Generating thumbnail for: $videoPath');
      }

      final thumbnailPath = await ThumbnailHelper.generateThumbnail(videoPath);

      if (thumbnailPath != null) {
        final file = File(thumbnailPath);
        if (await file.exists()) {
          _thumbnailCache[videoPath] = thumbnailPath;

          // 从缩略图获取实际宽高比
          try {
            final bytes = await file.readAsBytes();
            final codec = await ui.instantiateImageCodec(bytes, targetWidth: 100);
            final frame = await codec.getNextFrame();
            final image = frame.image;
            final aspectRatio = image.width / image.height;
            _aspectRatioCache[videoPath] = aspectRatio;
            image.dispose();
            codec.dispose();
          } catch (e) {
            // 使用默认宽高比
          }

          if (kDebugMode) {
            print('MediaCacheService: Thumbnail generated at: $thumbnailPath');
          }

          _loadingThumbnailPaths.remove(videoPath);

          // 通知缓存更新
          _cacheUpdateController.add(CacheUpdateEvent(
            type: CacheUpdateType.thumbnail,
            path: videoPath,
          ));

          return thumbnailPath;
        }
      }

      _loadingThumbnailPaths.remove(videoPath);
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('MediaCacheService: Error generating thumbnail: $e');
      }
      _loadingThumbnailPaths.remove(videoPath);
      return null;
    }
  }

  /// 批量预加载文件
  Future<void> preloadBatch(List<FileItem> items, {int concurrency = 5}) async {
    final mediaItems = items.where((item) =>
    item.type == FileItemType.image || item.type == FileItemType.video
    ).toList();

    // 使用并发限制进行预加载
    final chunks = <List<FileItem>>[];
    for (var i = 0; i < mediaItems.length; i += concurrency) {
      chunks.add(mediaItems.sublist(
          i,
          i + concurrency > mediaItems.length ? mediaItems.length : i + concurrency
      ));
    }

    for (final chunk in chunks) {
      await Future.wait(chunk.map((item) async {
        await preloadAspectRatio(item);
        if (item.type == FileItemType.video) {
          await preloadVideoThumbnail(item.path);
        }
      }));
    }
  }

  /// 清理指定路径的缓存
  void clearPath(String path) {
    _aspectRatioCache.remove(path);
    _thumbnailCache.remove(path);
  }

  /// 清理所有缓存
  void clearAll() {
    _aspectRatioCache.clear();
    _thumbnailCache.clear();
    _loadingAspectRatioPaths.clear();
    _loadingThumbnailPaths.clear();
  }

  /// 获取缓存统计
  CacheStats getStats() {
    return CacheStats(
      aspectRatioCacheSize: _aspectRatioCache.length,
      thumbnailCacheSize: _thumbnailCache.length,
      loadingAspectRatioCount: _loadingAspectRatioPaths.length,
      loadingThumbnailCount: _loadingThumbnailPaths.length,
    );
  }

  /// 释放资源
  void dispose() {
    _cacheUpdateController.close();
  }
}

/// 缓存更新事件类型
enum CacheUpdateType {
  aspectRatio,
  thumbnail,
}

/// 缓存更新事件
class CacheUpdateEvent {
  final CacheUpdateType type;
  final String path;

  CacheUpdateEvent({
    required this.type,
    required this.path,
  });
}

/// 缓存统计
class CacheStats {
  final int aspectRatioCacheSize;
  final int thumbnailCacheSize;
  final int loadingAspectRatioCount;
  final int loadingThumbnailCount;

  CacheStats({
    required this.aspectRatioCacheSize,
    required this.thumbnailCacheSize,
    required this.loadingAspectRatioCount,
    required this.loadingThumbnailCount,
  });

  @override
  String toString() {
    return 'CacheStats(aspectRatio: $aspectRatioCacheSize, thumbnail: $thumbnailCacheSize, '
        'loadingAR: $loadingAspectRatioCount, loadingTN: $loadingThumbnailCount)';
  }
}