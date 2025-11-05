import 'dart:convert' as convert;

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

  factory MyInstance() {
    return _singleton;
  }

  MyInstance._internal();

   bool  isDeviceAdmin()   {
    //1、管理员；2、成员；3、虚拟用户
    var groupCount =   groups?.length ?? 0;
    if (groupCount == 0) {
      return false;
    }
    int? groupId = this.group?.groupId;
    if(groupId == null || groupId == -1) {
      return false;
    }
    var group =   groups?.where((g) => g.groupId == groupId).toList().firstOrNull;
    if(group == null) {
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
    if(groupStr == null || groupStr.isEmpty) {
      return null;
    }
    Group? group  = Group.fromJson(convert.jsonDecode(groupStr));
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
}
