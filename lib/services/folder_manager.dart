// services/folder_manager.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/folder_info.dart';

/// 文件夹管理服务
/// 负责本地图库和相册图库的文件夹列表的持久化存储
class FolderManager {
  static final FolderManager _instance = FolderManager._internal();
  factory FolderManager() => _instance;
  FolderManager._internal();

  // 存储键
  static const String _localFoldersKey = 'local_folders';
  static const String _cloudFoldersKey = 'cloud_folders';

  // 内存缓存
  List<FolderInfo>? _localFolders;
  List<FolderInfo>? _cloudFolders;

  /// 获取本地图库文件夹列表
  Future<List<FolderInfo>> getLocalFolders() async {
    if (_localFolders != null) {
      return _localFolders!;
    }

    final prefs = await SharedPreferences.getInstance();
    final String? foldersJson = prefs.getString(_localFoldersKey);

    if (foldersJson == null || foldersJson.isEmpty) {
      _localFolders = [];
      return _localFolders!;
    }

    try {
      final List<dynamic> decoded = jsonDecode(foldersJson);
      _localFolders = decoded
          .map((item) => FolderInfo.fromJson(item as Map<String, dynamic>))
          .toList();
      return _localFolders!;
    } catch (e) {
      print('Error loading local folders: $e');
      _localFolders = [];
      return _localFolders!;
    }
  }

  /// 获取相册图库文件夹列表
  Future<List<FolderInfo>> getCloudFolders() async {
    if (_cloudFolders != null) {
      return _cloudFolders!;
    }

    final prefs = await SharedPreferences.getInstance();
    final String? foldersJson = prefs.getString(_cloudFoldersKey);

    if (foldersJson == null || foldersJson.isEmpty) {
      _cloudFolders = [];
      return _cloudFolders!;
    }

    try {
      final List<dynamic> decoded = jsonDecode(foldersJson);
      _cloudFolders = decoded
          .map((item) => FolderInfo.fromJson(item as Map<String, dynamic>))
          .toList();
      return _cloudFolders!;
    } catch (e) {
      print('Error loading cloud folders: $e');
      _cloudFolders = [];
      return _cloudFolders!;
    }
  }

  /// 保存本地图库文件夹列表
  Future<void> saveLocalFolders(List<FolderInfo> folders) async {
    _localFolders = folders;
    final prefs = await SharedPreferences.getInstance();
    final String foldersJson = jsonEncode(
      folders.map((folder) => folder.toJson()).toList(),
    );
    await prefs.setString(_localFoldersKey, foldersJson);
  }

  /// 保存相册图库文件夹列表
  Future<void> saveCloudFolders(List<FolderInfo> folders) async {
    _cloudFolders = folders;
    final prefs = await SharedPreferences.getInstance();
    final String foldersJson = jsonEncode(
      folders.map((folder) => folder.toJson()).toList(),
    );
    await prefs.setString(_cloudFoldersKey, foldersJson);
  }

  /// 添加本地文件夹
  Future<void> addLocalFolder(FolderInfo folder) async {
    final folders = await getLocalFolders();
    // 检查是否已存在
    if (!folders.any((f) => f.path == folder.path)) {
      folders.add(folder);
      await saveLocalFolders(folders);
    }
  }

  /// 添加相册文件夹
  Future<void> addCloudFolder(FolderInfo folder) async {
    final folders = await getCloudFolders();
    // 检查是否已存在
    if (!folders.any((f) => f.path == folder.path)) {
      folders.add(folder);
      await saveCloudFolders(folders);
    }
  }

  /// 删除本地文件夹
  Future<void> removeLocalFolder(String folderPath) async {
    final folders = await getLocalFolders();
    folders.removeWhere((f) => f.path == folderPath);
    await saveLocalFolders(folders);
  }

  /// 删除相册文件夹
  Future<void> removeCloudFolder(String folderPath) async {
    final folders = await getCloudFolders();
    folders.removeWhere((f) => f.path == folderPath);
    await saveCloudFolders(folders);
  }

  /// 清空本地文件夹列表
  Future<void> clearLocalFolders() async {
    _localFolders = [];
    await saveLocalFolders([]);
  }

  /// 清空相册文件夹列表
  Future<void> clearCloudFolders() async {
    _cloudFolders = [];
    await saveCloudFolders([]);
  }

  /// 刷新内存缓存（强制重新从存储读取）
  void invalidateCache() {
    _localFolders = null;
    _cloudFolders = null;
  }
}