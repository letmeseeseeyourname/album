// controllers/selection_controller.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../models/file_item.dart';

/// 文件夹统计结果
class FolderStats {
  final int imageCount;
  final int videoCount;
  final int totalBytes;

  FolderStats({
    required this.imageCount,
    required this.videoCount,
    required this.totalBytes,
  });

  double get totalSizeMB => totalBytes / (1024 * 1024);

  FolderStats operator +(FolderStats other) {
    return FolderStats(
      imageCount: imageCount + other.imageCount,
      videoCount: videoCount + other.videoCount,
      totalBytes: totalBytes + other.totalBytes,
    );
  }

  static FolderStats zero = FolderStats(imageCount: 0, videoCount: 0, totalBytes: 0);
}

/// 递归获取文件夹内的所有媒体文件统计（用于 compute 隔离区）
Future<FolderStats> _computeFolderStats(String folderPath) async {
  int imageCount = 0;
  int videoCount = 0;
  int totalBytes = 0;

  const imageExtensions = ['bmp', 'gif', 'jpg', 'jpeg', 'png', 'webp', 'wbmp', 'heic'];
  const videoExtensions = ['mp4', 'mov', 'avi', '3gp', 'mkv', '3gp2'];

  try {
    final directory = Directory(folderPath);
    if (!await directory.exists()) {
      return FolderStats.zero;
    }

    await for (var entity in directory.list(recursive: true)) {
      if (entity is File) {
        final ext = entity.path.split('.').last.toLowerCase();
        try {
          final stat = await entity.stat();
          if (imageExtensions.contains(ext)) {
            imageCount++;
            totalBytes += stat.size;
          } else if (videoExtensions.contains(ext)) {
            videoCount++;
            totalBytes += stat.size;
          }
        } catch (e) {
          // 忽略无法访问的文件
        }
      }
    }
  } catch (e) {
    debugPrint('Error scanning folder $folderPath: $e');
  }

  return FolderStats(
    imageCount: imageCount,
    videoCount: videoCount,
    totalBytes: totalBytes,
  );
}

/// 选择控制器 - 负责文件选择和筛选逻辑
/// 已修复：支持文件夹的递归统计
class SelectionController {
  final Set<int> _selectedIndices = {};
  bool _isSelectionMode = false;
  String _filterType = 'all'; // 'all', 'image', 'video'

  // 缓存的统计数据（用于文件夹递归统计）
  int _cachedImageCount = 0;
  int _cachedVideoCount = 0;
  int _cachedTotalBytes = 0;
  bool _isCountingFiles = false;

  Set<int> get selectedIndices => Set.unmodifiable(_selectedIndices);
  bool get isSelectionMode => _isSelectionMode;
  String get filterType => _filterType;
  int get selectedCount => _selectedIndices.length;
  bool get isCountingFiles => _isCountingFiles;

  // 缓存的统计结果
  int get cachedImageCount => _cachedImageCount;
  int get cachedVideoCount => _cachedVideoCount;
  double get cachedTotalSizeMB => _cachedTotalBytes / (1024 * 1024);

  /// 切换选择状态
  void toggleSelection(int index) {
    if (_selectedIndices.contains(index)) {
      _selectedIndices.remove(index);
      if (_selectedIndices.isEmpty) {
        _isSelectionMode = false;
      }
    } else {
      _selectedIndices.add(index);
      _isSelectionMode = true;
    }
  }

  /// 全选/取消全选
  void toggleSelectAll(int totalCount) {
    if (_selectedIndices.length == totalCount && totalCount > 0) {
      _selectedIndices.clear();
      _isSelectionMode = false;
    } else {
      _selectedIndices.clear();
      for (int i = 0; i < totalCount; i++) {
        _selectedIndices.add(i);
      }
      _isSelectionMode = true;
    }
  }

  /// 取消选择
  void cancelSelection() {
    _selectedIndices.clear();
    _isSelectionMode = false;
    // 清除缓存
    _cachedImageCount = 0;
    _cachedVideoCount = 0;
    _cachedTotalBytes = 0;
  }

  /// 设置筛选类型
  void setFilterType(String type) {
    _filterType = type;
    _selectedIndices.clear();
    _isSelectionMode = false;
    // 清除缓存
    _cachedImageCount = 0;
    _cachedVideoCount = 0;
    _cachedTotalBytes = 0;
  }

  /// 获取筛选后的文件列表
  List<FileItem> getFilteredFiles(List<FileItem> allFiles) {
    if (_filterType == 'all') {
      return allFiles;
    } else if (_filterType == 'image') {
      return allFiles.where((item) =>
      item.type == FileItemType.folder || item.type == FileItemType.image
      ).toList();
    } else if (_filterType == 'video') {
      return allFiles.where((item) =>
      item.type == FileItemType.folder || item.type == FileItemType.video
      ).toList();
    }
    return allFiles;
  }

  /// 获取选中的项目
  List<FileItem> getSelectedItems(List<FileItem> allFiles) {
    return _selectedIndices
        .where((index) => index < allFiles.length)
        .map((index) => allFiles[index])
        .toList();
  }

  /// 获取选中的图片数量（仅计算直接选中的图片，不含文件夹）
  int getSelectedImageCount(List<FileItem> allFiles) {
    return _selectedIndices
        .where((index) => index < allFiles.length && allFiles[index].type == FileItemType.image)
        .length;
  }

  /// 获取选中的视频数量（仅计算直接选中的视频，不含文件夹）
  int getSelectedVideoCount(List<FileItem> allFiles) {
    return _selectedIndices
        .where((index) => index < allFiles.length && allFiles[index].type == FileItemType.video)
        .length;
  }

  /// 获取选中的总大小(MB)（仅计算直接选中的文件，不含文件夹）
  double getSelectedTotalSize(List<FileItem> allFiles) {
    int totalBytes = _selectedIndices
        .where((index) => index < allFiles.length)
        .map((index) => allFiles[index])
        .where((item) => item.type != FileItemType.folder)
        .fold(0, (sum, item) => sum + item.size);
    return totalBytes / (1024 * 1024);
  }

  /// 检查选中项是否包含文件夹
  bool hasSelectedFolders(List<FileItem> allFiles) {
    return _selectedIndices.any((index) =>
    index < allFiles.length && allFiles[index].type == FileItemType.folder
    );
  }

  /// 获取选中的文件夹列表
  List<FileItem> getSelectedFolders(List<FileItem> allFiles) {
    return _selectedIndices
        .where((index) => index < allFiles.length && allFiles[index].type == FileItemType.folder)
        .map((index) => allFiles[index])
        .toList();
  }

  /// 异步更新选中项的统计数据（包括递归统计文件夹）
  /// 返回是否需要刷新UI
  Future<bool> updateSelectedStats(List<FileItem> allFiles, {VoidCallback? onUpdate}) async {
    if (_selectedIndices.isEmpty) {
      _cachedImageCount = 0;
      _cachedVideoCount = 0;
      _cachedTotalBytes = 0;
      return true;
    }

    _isCountingFiles = true;
    onUpdate?.call();

    int imageCount = 0;
    int videoCount = 0;
    int totalBytes = 0;

    final selectedItems = getSelectedItems(allFiles);

    for (var item in selectedItems) {
      if (item.type == FileItemType.folder) {
        // 对文件夹进行递归统计
        try {
          final stats = await compute(_computeFolderStats, item.path);
          imageCount += stats.imageCount;
          videoCount += stats.videoCount;
          totalBytes += stats.totalBytes;
        } catch (e) {
          debugPrint('Error computing folder stats for ${item.path}: $e');
        }
      } else if (item.type == FileItemType.image) {
        imageCount++;
        totalBytes += item.size;
      } else if (item.type == FileItemType.video) {
        videoCount++;
        totalBytes += item.size;
      }
    }

    _cachedImageCount = imageCount;
    _cachedVideoCount = videoCount;
    _cachedTotalBytes = totalBytes;
    _isCountingFiles = false;

    onUpdate?.call();
    return true;
  }

  /// 重置状态
  void reset() {
    _selectedIndices.clear();
    _isSelectionMode = false;
    _filterType = 'all';
    _cachedImageCount = 0;
    _cachedVideoCount = 0;
    _cachedTotalBytes = 0;
    _isCountingFiles = false;
  }
}