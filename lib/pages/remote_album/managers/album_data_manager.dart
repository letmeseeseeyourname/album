// album/managers/album_data_manager.dart (修复下载问题)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../album/provider/album_provider.dart';
import '../../../user/models/resource_list_model.dart';

/// 相册数据管理器（优化版 - 修复下载问题）
/// 负责数据加载、分页、分组、缓存等逻辑
class AlbumDataManager extends ChangeNotifier {
  final AlbumProvider _albumProvider = AlbumProvider();

  // Tab 分离缓存 - 为每个 Tab 维护独立的数据
  final Map<bool, List<ResList>> _cachedResources = {
    true: [],   // 个人相册
    false: [],  // 家庭相册
  };

  final Map<bool, Map<String, List<ResList>>> _cachedGroupedResources = {
    true: {},
    false: {},
  };

  final Map<bool, int> _cachedPages = {
    true: 1,
    false: 1,
  };

  final Map<bool, bool> _cachedHasMore = {
    true: true,
    false: true,
  };

  // ResId 索引 - 快速查询
  final Map<bool, Map<String, ResList>> _resourceIndexes = {
    true: {},
    false: {},
  };

  // 当前状态
  bool _currentIsPrivate = true;
  List<ResList> _allResources = [];
  Map<String, List<ResList>> _groupedResources = {};
  Map<String, ResList> _resourceIndex = {};

  // 加载状态
  bool _isLoading = false;
  int _currentPage = 1;
  bool _hasMore = true;
  String? _errorMessage;

  // 缓存配置
  static const String _cacheKeyPrefix = 'album_cache_';
  static const Duration _cacheExpiry = Duration(hours: 24);

  // Getters
  List<ResList> get allResources => _allResources;
  Map<String, List<ResList>> get groupedResources => _groupedResources;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  bool get hasData => _allResources.isNotEmpty;

  /// 切换 Tab（不重新加载数据）
  void switchTab(bool isPrivate) {
    if (_currentIsPrivate != isPrivate) {
      // 保存当前 Tab 的状态到缓存
      _cachedResources[_currentIsPrivate] = _allResources;
      _cachedGroupedResources[_currentIsPrivate] = _groupedResources;
      _cachedPages[_currentIsPrivate] = _currentPage;
      _cachedHasMore[_currentIsPrivate] = _hasMore;
      _resourceIndexes[_currentIsPrivate] = _resourceIndex;

      // 切换到新 Tab，恢复缓存数据
      _currentIsPrivate = isPrivate;
      _allResources = List.from(_cachedResources[isPrivate]!);
      _groupedResources = Map.from(_cachedGroupedResources[isPrivate]!);
      _currentPage = _cachedPages[isPrivate]!;
      _hasMore = _cachedHasMore[isPrivate]!;
      _resourceIndex = Map.from(_resourceIndexes[isPrivate]!);

      debugPrint('切换Tab: isPrivate=$isPrivate, 资源数=${_allResources.length}, 索引数=${_resourceIndex.length}');

      notifyListeners();
    }
  }

  /// 重置并加载数据
  Future<void> resetAndLoad({required bool isPrivate}) async {
    _currentIsPrivate = isPrivate;

    // 检查内存缓存
    if (_cachedResources[isPrivate]!.isNotEmpty) {
      // 恢复内存缓存
      _allResources = List.from(_cachedResources[isPrivate]!);
      _groupedResources = Map.from(_cachedGroupedResources[isPrivate]!);
      _currentPage = _cachedPages[isPrivate]!;
      _hasMore = _cachedHasMore[isPrivate]!;
      _resourceIndex = Map.from(_resourceIndexes[isPrivate]!);

      debugPrint('从内存缓存恢复: 资源数=${_allResources.length}, 索引数=${_resourceIndex.length}');
      notifyListeners();
      return;
    }

    // 尝试从本地缓存加载
    final hasCache = await _loadFromLocalCache(isPrivate);

    if (!hasCache) {
      // 缓存无效，清空并重新加载
      _allResources.clear();
      _groupedResources.clear();
      _resourceIndex.clear();
      _currentPage = 1;
      _hasMore = true;
      _errorMessage = null;
      notifyListeners();

      await loadResources(isPrivate: isPrivate);
    }
  }

  /// 强制刷新（清空缓存重新加载）
  Future<void> forceRefresh({required bool isPrivate}) async {
    _currentIsPrivate = isPrivate;

    // 清空所有缓存
    _cachedResources[isPrivate]!.clear();
    _cachedGroupedResources[isPrivate]!.clear();
    _cachedPages[isPrivate] = 1;
    _cachedHasMore[isPrivate] = true;
    _resourceIndexes[isPrivate]!.clear();

    _allResources.clear();
    _groupedResources.clear();
    _resourceIndex.clear();
    _currentPage = 1;
    _hasMore = true;
    _errorMessage = null;

    // 清空本地缓存
    await _clearLocalCache(isPrivate);

    notifyListeners();
    await loadResources(isPrivate: isPrivate);
  }

  /// 加载资源
  Future<void> loadResources({required bool isPrivate}) async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _albumProvider.listResources(
        _currentPage,
        isPrivate: isPrivate,
      );

      if (response.isSuccess && response.model != null) {
        final newResources = response.model!.resList;

        debugPrint('加载数据: 页码=$_currentPage, 新增=${newResources.length}项');

        // 去重：只添加不存在的资源
        final existingIds = _resourceIndex.keys.toSet();
        final uniqueResources = newResources
            .where((r) => r.resId != null && !existingIds.contains(r.resId))
            .toList();

        debugPrint('去重后: 实际新增=${uniqueResources.length}项');

        if (uniqueResources.isNotEmpty) {
          _allResources.addAll(uniqueResources);
          _addResourcesToGroups(uniqueResources); // 增量分组
        }

        _hasMore = newResources.length >= AlbumProvider.myPageSize;

        debugPrint('加载完成: 总资源=${_allResources.length}, 索引=${_resourceIndex.length}, hasMore=$_hasMore');

        // 保存到本地缓存
        await _saveToLocalCache(isPrivate);

        // 更新内存缓存
        _cachedResources[isPrivate] = _allResources;
        _cachedGroupedResources[isPrivate] = _groupedResources;
        _cachedPages[isPrivate] = _currentPage;
        _cachedHasMore[isPrivate] = _hasMore;
        _resourceIndexes[isPrivate] = _resourceIndex;

        notifyListeners();
      } else {
        _errorMessage = '加载数据失败';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = '加载失败: $e';
      debugPrint('加载相册资源失败: $e');
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 加载更多
  Future<void> loadMore({required bool isPrivate}) async {
    if (!_hasMore || _isLoading) return;

    _currentPage++;
    await loadResources(isPrivate: isPrivate);
  }

  /// 增量添加资源到分组（性能优化：O(m) 而非 O(n)）
  void _addResourcesToGroups(List<ResList> newResources) {
    final dateFormat = DateFormat('yyyy年M月d日');

    for (var resource in newResources) {
      // 更新索引 - 关键！必须先更新索引
      if (resource.resId != null && resource.resId!.isNotEmpty) {
        _resourceIndex[resource.resId!] = resource;
      }

      // 分组
      final date = resource.photoDate ?? resource.createDate;
      if (date != null) {
        final dateKey = dateFormat.format(date);
        _groupedResources.putIfAbsent(dateKey, () => []);
        _groupedResources[dateKey]!.add(resource);
      }
    }

    debugPrint('增量更新: 索引总数=${_resourceIndex.length}');
  }

  /// 按日期分组资源（全量重新分组）
  void _groupResourcesByDate() {
    _groupedResources.clear();
    _resourceIndex.clear();
    final dateFormat = DateFormat('yyyy年M月d日');

    for (var resource in _allResources) {
      // 更新索引 - 关键！
      if (resource.resId != null && resource.resId!.isNotEmpty) {
        _resourceIndex[resource.resId!] = resource;
      }

      // 分组
      final date = resource.photoDate ?? resource.createDate;
      if (date != null) {
        final dateKey = dateFormat.format(date);
        _groupedResources.putIfAbsent(dateKey, () => []);
        _groupedResources[dateKey]!.add(resource);
      }
    }

    debugPrint('全量分组: 资源=${_allResources.length}, 索引=${_resourceIndex.length}');
  }

  /// 保存到本地缓存
  Future<void> _saveToLocalCache(bool isPrivate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix${isPrivate ? "private" : "family"}';

      // 只缓存前 500 项数据，避免缓存过大
      final itemsToCache = _allResources.length > 500
          ? _allResources.sublist(0, 500)
          : _allResources;

      final cacheData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'page': _currentPage,
        'hasMore': _hasMore,
        'resources': itemsToCache.map((r) => r.toJson()).toList(),
      };

      await prefs.setString(cacheKey, jsonEncode(cacheData));
      debugPrint('保存本地缓存: ${itemsToCache.length}项');
    } catch (e) {
      debugPrint('保存缓存失败: $e');
    }
  }

  /// 从本地缓存加载
  Future<bool> _loadFromLocalCache(bool isPrivate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix${isPrivate ? "private" : "family"}';

      final cacheString = prefs.getString(cacheKey);
      if (cacheString == null) {
        debugPrint('本地缓存不存在');
        return false;
      }

      final cacheData = jsonDecode(cacheString);
      final timestamp = DateTime.fromMillisecondsSinceEpoch(cacheData['timestamp']);

      // 检查缓存是否过期
      if (DateTime.now().difference(timestamp) > _cacheExpiry) {
        await prefs.remove(cacheKey);
        debugPrint('本地缓存已过期');
        return false;
      }

      _currentPage = cacheData['page'];
      _hasMore = cacheData['hasMore'];
      _allResources = (cacheData['resources'] as List)
          .map((json) => ResList.fromJson(json))
          .toList();

      _groupResourcesByDate(); // 重新分组，会同时建立索引

      // 更新内存缓存
      _cachedResources[isPrivate] = _allResources;
      _cachedGroupedResources[isPrivate] = _groupedResources;
      _cachedPages[isPrivate] = _currentPage;
      _cachedHasMore[isPrivate] = _hasMore;
      _resourceIndexes[isPrivate] = _resourceIndex;

      debugPrint('从本地缓存加载: 资源=${_allResources.length}, 索引=${_resourceIndex.length}');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('加载缓存失败: $e');
      return false;
    }
  }

  /// 清空本地缓存
  Future<void> _clearLocalCache(bool isPrivate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix${isPrivate ? "private" : "family"}';
      await prefs.remove(cacheKey);
      debugPrint('清空本地缓存');
    } catch (e) {
      debugPrint('清空缓存失败: $e');
    }
  }

  /// 获取资源在列表中的全局索引
  int getGlobalIndex(ResList resource) {
    return _allResources.indexOf(resource);
  }

  /// 根据ID获取资源列表（性能优化：O(m) 而非 O(n)）
  List<ResList> getResourcesByIds(Set<String> ids) {
    debugPrint('查询资源: 请求=${ids.length}个, 索引有=${_resourceIndex.length}个');

    final result = ids
        .where((id) {
      final exists = _resourceIndex.containsKey(id);
      if (!exists) {
        debugPrint('警告: ID不在索引中: $id');
      }
      return exists;
    })
        .map((id) => _resourceIndex[id]!)
        .toList();

    debugPrint('查询结果: 找到${result.length}个资源');
    return result;
  }

  /// 获取所有资源ID
  List<String> getAllResourceIds() {
    return _resourceIndex.keys.toList();
  }

  /// 计算选中项的总大小（性能优化：O(m) 而非 O(n)）
  String calculateSelectedSize(Set<String> selectedIds) {
    if (selectedIds.isEmpty) {
      return '共 ${_allResources.length} 项';
    }

    int totalSize = 0;
    int imageCount = 0;
    int videoCount = 0;

    for (var id in selectedIds) {
      final resource = _resourceIndex[id];
      if (resource != null) {
        totalSize += resource.fileSize ?? 0;
        if (resource.fileType == 'V') {
          videoCount++;
        } else {
          imageCount++;
        }
      }
    }

    final sizeInMB = totalSize / (1024 * 1024);
    String sizeStr;
    if (sizeInMB < 1024) {
      sizeStr = '${sizeInMB.toStringAsFixed(2)} MB';
    } else {
      sizeStr = '${(sizeInMB / 1024).toStringAsFixed(2)} GB';
    }

    if (selectedIds.length == 1) {
      return '已选择 1 项 ($sizeStr)';
    }

    String itemsStr = '已选择 ${selectedIds.length} 项';
    if (imageCount > 0 && videoCount > 0) {
      itemsStr += ' (${imageCount}张照片, ${videoCount}个视频)';
    } else if (imageCount > 0) {
      itemsStr += ' (${imageCount}张照片)';
    } else if (videoCount > 0) {
      itemsStr += ' (${videoCount}个视频)';
    }

    return '$itemsStr - $sizeStr';
  }

  @override
  void dispose() {
    _albumProvider.dispose();
    super.dispose();
  }
}