// album/managers/album_data_manager.dart (优化版 v9)
//
// 参考 mine_page 的 _loadListData() 和 _getGalleryLisWith() 实现
// 核心改动：
// 1. 使用 RefreshPageManager 管理加载状态
// 2. 一次性加载所有数据（循环分页直到加载完成）
// 3. 加载完成后一次性更新 UI

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../album/provider/album_provider.dart';
import '../../../user/models/resource_list_model.dart';

/// 页面加载状态管理器（参考 mine_page 的 RefreshPageManager）
class RefreshPageManager {
  bool isLoading = true;   // 是否正在加载
  bool hasError = false;   // 是否有错误
  bool isEmpty = false;    // 是否为空
  bool isRequest = false;  // 是否正在请求（防止重复请求）
}

/// 相册数据管理器（优化版 v9）
/// 参考 mine_page 的数据加载策略
class AlbumDataManager extends ChangeNotifier {
  final AlbumProvider _albumProvider = AlbumProvider();

  // 加载状态管理
  final RefreshPageManager _loadManager = RefreshPageManager();

  // Tab 分离缓存
  final Map<bool, List<ResList>> _cachedResources = {
    true: [],   // 个人相册
    false: [],  // 家庭相册
  };

  final Map<bool, Map<String, List<ResList>>> _cachedGroupedResources = {
    true: {},
    false: {},
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

  // 缓存配置
  static const String _cacheKeyPrefix = 'album_cache_';
  static const Duration _cacheExpiry = Duration(hours: 24);

  // 每页加载数量（参考 mine_page 使用 1000）
  static const int _pageSize = 1000;

  // Getters
  List<ResList> get allResources => _allResources;
  Map<String, List<ResList>> get groupedResources => _groupedResources;
  bool get isLoading => _loadManager.isLoading;
  bool get hasError => _loadManager.hasError;
  bool get hasData => _allResources.isNotEmpty;
  bool get isEmpty => _loadManager.isEmpty;
  String? get errorMessage => _loadManager.hasError ? '加载数据失败' : null;

  // 兼容旧接口
  bool get hasMore => false; // 新策略下一次加载完成，没有"更多"的概念

  /// 清空所有缓存（用于 Group 切换时）
  Future<void> clearAllCache() async {
    debugPrint('清空所有相册缓存（Group 切换）');

    // 清空内存缓存
    _cachedResources[true]!.clear();
    _cachedGroupedResources[true]!.clear();
    _resourceIndexes[true]!.clear();

    _cachedResources[false]!.clear();
    _cachedGroupedResources[false]!.clear();
    _resourceIndexes[false]!.clear();

    // 清空当前状态
    _allResources.clear();
    _groupedResources.clear();
    _resourceIndex.clear();

    // 重置加载状态
    _loadManager.isLoading = true;
    _loadManager.hasError = false;
    _loadManager.isEmpty = false;
    _loadManager.isRequest = false;

    // 清空本地缓存
    await _clearLocalCache(true);
    await _clearLocalCache(false);

    notifyListeners();
  }

  /// 切换 Tab（不重新加载数据）
  void switchTab(bool isPrivate) {
    if (_currentIsPrivate != isPrivate) {
      // 保存当前 Tab 的状态到缓存
      _cachedResources[_currentIsPrivate] = List.from(_allResources);
      _cachedGroupedResources[_currentIsPrivate] = Map.from(_groupedResources);
      _resourceIndexes[_currentIsPrivate] = Map.from(_resourceIndex);

      // 切换到新 Tab，恢复缓存数据
      _currentIsPrivate = isPrivate;
      _allResources = List.from(_cachedResources[isPrivate]!);
      _groupedResources = Map.from(_cachedGroupedResources[isPrivate]!);
      _resourceIndex = Map.from(_resourceIndexes[isPrivate]!);

      debugPrint('切换Tab: isPrivate=$isPrivate, 资源数=${_allResources.length}');

      notifyListeners();
    }
  }

  /// 重置并加载数据
  Future<void> resetAndLoad({required bool isPrivate}) async {
    debugPrint('重置并加载数据: isPrivate=$isPrivate');

    _currentIsPrivate = isPrivate;

    // 检查内存缓存
    if (_cachedResources[isPrivate]!.isNotEmpty) {
      _allResources = List.from(_cachedResources[isPrivate]!);
      _groupedResources = Map.from(_cachedGroupedResources[isPrivate]!);
      _resourceIndex = Map.from(_resourceIndexes[isPrivate]!);
      _loadManager.isLoading = false;
      _loadManager.hasError = false;
      _loadManager.isEmpty = _allResources.isEmpty;

      debugPrint('从内存缓存恢复: 资源数=${_allResources.length}');
      notifyListeners();
      return;
    }

    // 尝试从本地缓存加载
    final hasCache = await _loadFromLocalCache(isPrivate);

    if (!hasCache) {
      // 缓存无效，重新加载
      await loadResources(isPrivate: isPrivate);
    }
  }

  /// 强制刷新（清空缓存重新加载）
  Future<void> forceRefresh({required bool isPrivate}) async {
    debugPrint('强制刷新: isPrivate=$isPrivate');

    _currentIsPrivate = isPrivate;

    // 清空当前 Tab 的缓存
    _cachedResources[isPrivate]!.clear();
    _cachedGroupedResources[isPrivate]!.clear();
    _resourceIndexes[isPrivate]!.clear();

    _allResources.clear();
    _groupedResources.clear();
    _resourceIndex.clear();

    // 重置加载状态
    _loadManager.isLoading = true;
    _loadManager.hasError = false;
    _loadManager.isEmpty = false;
    _loadManager.isRequest = false;

    // 清空本地缓存
    await _clearLocalCache(isPrivate);

    notifyListeners();
    await loadResources(isPrivate: isPrivate);
  }

  /// 加载资源（参考 mine_page 的 _getGalleryLisWith）
  /// 一次性加载所有数据
  Future<void> loadResources({required bool isPrivate}) async {
    // 防止重复请求
    if (_loadManager.isRequest) {
      debugPrint('正在请求中，跳过');
      return;
    }

    _loadManager.isRequest = true;
    _loadManager.isLoading = true;
    _loadManager.hasError = false;
    notifyListeners();

    int loadPage = 1;
    bool loadSuccess = true;
    List<ResList> allLoadedResources = [];

    try {
      // 循环加载所有页面（参考 mine_page 的 while(true) 循环）
      while (true) {
        debugPrint('加载第 $loadPage 页...');

        final response = await _albumProvider.listResources(
          loadPage,
          pageSize: _pageSize,
          isPrivate: isPrivate,
        );

        if (!response.isSuccess || response.model == null) {
          debugPrint('加载第 $loadPage 页失败');
          loadSuccess = false;
          break;
        }

        final newResources = response.model!.resList;
        debugPrint('第 $loadPage 页加载完成，获取 ${newResources.length} 条数据');

        if (loadPage == 1) {
          allLoadedResources = [...newResources];
        } else {
          allLoadedResources = [...allLoadedResources, ...newResources];
        }

        loadPage++;

        // 如果返回的数据少于 pageSize，说明已经加载完成
        if (newResources.length < _pageSize) {
          debugPrint('数据加载完成，共 ${allLoadedResources.length} 条');
          break;
        }
      }
    } catch (e) {
      debugPrint('加载相册资源异常: $e');
      loadSuccess = false;
    }

    _loadManager.isRequest = false;

    if (!loadSuccess) {
      _loadManager.isLoading = false;
      _loadManager.hasError = true;
      notifyListeners();
      return;
    }

    // 加载成功，更新数据
    _allResources = allLoadedResources;
    _groupResourcesByDate();

    _loadManager.isLoading = false;
    _loadManager.hasError = false;
    _loadManager.isEmpty = _allResources.isEmpty;

    // 保存到缓存
    _cachedResources[isPrivate] = List.from(_allResources);
    _cachedGroupedResources[isPrivate] = Map.from(_groupedResources);
    _resourceIndexes[isPrivate] = Map.from(_resourceIndex);

    // 保存到本地缓存
    await _saveToLocalCache(isPrivate);

    debugPrint('资源加载完成: 总数=${_allResources.length}, 分组数=${_groupedResources.length}');
    notifyListeners();
  }

  /// 加载更多（兼容旧接口，新策略下不需要）
  Future<void> loadMore({required bool isPrivate}) async {
    // 新策略下一次性加载完成，不需要加载更多
    debugPrint('loadMore 被调用，但新策略下一次性加载完成');
  }

  /// 按日期分组资源
  void _groupResourcesByDate() {
    _groupedResources.clear();
    _resourceIndex.clear();
    final dateFormat = DateFormat('yyyy年M月d日');

    for (var resource in _allResources) {
      // 更新索引
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

    debugPrint('分组完成: 资源=${_allResources.length}, 索引=${_resourceIndex.length}, 分组=${_groupedResources.length}');
  }

  /// 保存到本地缓存
  Future<void> _saveToLocalCache(bool isPrivate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix${isPrivate ? "private" : "family"}';

      // 缓存所有数据（不做截断）
      final cacheData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'resources': _allResources.map((r) => r.toJson()).toList(),
      };

      await prefs.setString(cacheKey, jsonEncode(cacheData));
      debugPrint('保存本地缓存: ${_allResources.length}项');
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

      _allResources = (cacheData['resources'] as List)
          .map((json) => ResList.fromJson(json))
          .toList();

      _groupResourcesByDate();

      // 更新状态
      _loadManager.isLoading = false;
      _loadManager.hasError = false;
      _loadManager.isEmpty = _allResources.isEmpty;

      // 更新内存缓存
      _cachedResources[isPrivate] = List.from(_allResources);
      _cachedGroupedResources[isPrivate] = Map.from(_groupedResources);
      _resourceIndexes[isPrivate] = Map.from(_resourceIndex);

      debugPrint('从本地缓存加载: 资源=${_allResources.length}');
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
      debugPrint('清空本地缓存: $cacheKey');
    } catch (e) {
      debugPrint('清空缓存失败: $e');
    }
  }

  /// 获取资源在列表中的全局索引
  int getGlobalIndex(ResList resource) {
    return _allResources.indexOf(resource);
  }

  /// 根据ID获取资源列表
  List<ResList> getResourcesByIds(Set<String> ids) {
    return ids
        .where((id) => _resourceIndex.containsKey(id))
        .map((id) => _resourceIndex[id]!)
        .toList();
  }

  /// 获取所有资源ID
  List<String> getAllResourceIds() {
    return _resourceIndex.keys.toList();
  }

  /// 计算选中项的总大小
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