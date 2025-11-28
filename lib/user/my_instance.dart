import 'dart:convert' as convert;
import 'dart:io';

import 'package:ablumwin/user/provider/mine_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/device_model.dart';
import 'models/group.dart';
import 'models/login_response_model.dart';
import 'models/p6device_info_model.dart';

class MyInstance {
  static final MyInstance _singleton = MyInstance._internal();
  LoginResponseModel? user;
  // int? selectGroupId;
  String? myCookie;
  String deviceCode = "";
  DeviceModel? deviceModel;
  P6DeviceInfoModel? p6deviceInfoModel;
  bool isExternalStorage = false;
  MyNetworkProvider mineProvider = MyNetworkProvider();
  Group? group;
  List<Group>? groups;

  // 设置相关的键
  static const String _downloadPathKey = 'download_path';
  static const String _minimizeOnCloseKey = 'minimize_on_close';

  factory MyInstance() {
    return _singleton;
  }

  MyInstance._internal();

  bool isDeviceAdmin() {
    //1、管理员；2、成员；3、虚拟用户
    var groupCount = groups?.length ?? 0;
    if (groupCount == 0) {
      return false;
    }
    int? groupId = this.group?.groupId;
    if (groupId == null || groupId == -1) {
      return false;
    }
    var group = groups?.where((g) => g.groupId == groupId).toList().firstOrNull;
    if (group == null) {
      return false;
    }
    var allMembers = group.users ?? [];
    var admin = allMembers.where((user) => user.shipStatus == 1).toList().first;
    return admin.userId == (MyInstance().user?.user?.id ?? 0);
  }

  Future<String?> getCookie() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String Cookie = prefs.getString('Cookie') ?? "";
    if (Cookie.isEmpty) {
      return null;
    }
    myCookie = Cookie;
    return Cookie;
  }

  setCookie(String cookie) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    myCookie = cookie;
    await prefs.setString('Cookie', cookie);
  }

  Future<Group?> getGroup() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? groupStr = prefs.getString('group');
    if (groupStr == null || groupStr.isEmpty) {
      return null;
    }
    Group? group = Group.fromJson(convert.jsonDecode(groupStr));
    this.group = group;
    return group;
  }

  setGroup(Group? group) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (group == null) {
      prefs.remove('group');
      return;
    }
    this.group = group;
    var groupStr = convert.jsonEncode(group.toJson());
    await prefs.setString('group', groupStr);
  }

  set(LoginResponseModel? user) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    this.user = user;
    if (user == null) {
      prefs.remove('user_json');
      return;
    }
    Map<String, dynamic> json = user.toJson();
    String str = convert.jsonEncode(json);
    await prefs.setString('user_json', str);
  }

  Future<LoginResponseModel?> get() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String jsonstr = prefs.getString('user_json') ?? "";
    if (jsonstr == "") {
      return null;
    }
    Map<String, dynamic> json = convert.jsonDecode(jsonstr);
    var user = LoginResponseModel.fromJson(json);
    this.user = user;
    return user;
  }

  bool isLogin() {
    if (user != null) {
      return true;
    }
    return false;
  }

  // ========== 设置相关方法 ==========

  /// 获取默认的 Windows 下载路径
  Future<String> _getDefaultWindowsDownloadPath() async {
    final userHome = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ?? '';
    final downloadDir = Directory('$userHome\\Downloads\\亲选相册');

    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    return downloadDir.path;
  }

  /// 获取下载路径
  /// 如果没有设置则返回 Windows 系统默认下载路径
  Future<String> getDownloadPath() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString(_downloadPathKey);

    if (savedPath != null && savedPath.isNotEmpty) {
      // 检查保存的路径是否存在
      final dir = Directory(savedPath);
      if (await dir.exists()) {
        return savedPath;
      }
      // 路径不存在，尝试创建
      try {
        await dir.create(recursive: true);
        return savedPath;
      } catch (e) {
        // 创建失败，返回默认路径
      }
    }

    // 返回默认的 Windows 下载路径
    return await _getDefaultWindowsDownloadPath();
  }

  /// 设置下载路径
  Future<void> setDownloadPath(String path) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_downloadPathKey, path);
  }

  /// 获取关闭时是否最小化（true=最小化到托盘，false=退出程序）
  Future<bool> getMinimizeOnClose() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // 默认值为 true（最小化到托盘）
    return prefs.getBool(_minimizeOnCloseKey) ?? true;
  }

  /// 设置关闭时是否最小化
  Future<void> setMinimizeOnClose(bool minimize) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_minimizeOnCloseKey, minimize);
  }
}