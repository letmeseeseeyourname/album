import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../network/constant_sign.dart';
import '../../network/network_provider.dart';
import '../../network/response/response_model.dart';
import '../models/login_response_model.dart';
import '../models/user.dart';
import '../models/user_model.dart';
import '../my_instance.dart';
import '../native_bridge.dart';


extension StringMD5 on String {
  String toMd5() {
    return md5.convert(utf8.encode(this)).toString();
  }
}

//'A':账号密码登录  'V':验证码登录   'S':'扫码登录'
enum Logintype { password, code, scan }

extension LogintypeExtension on Logintype {
  String get value {
    switch (this) {
      case Logintype.password:
        return 'A';
      case Logintype.code:
        return 'V';
      case Logintype.scan:
        return 'S';
    }
  }

  static Logintype fromValue(String value) {
    switch (value) {
      case 'A':
        return Logintype.password;
      case 'V':
        return Logintype.code;
      case 'S':
        return Logintype.scan;
      default:
        throw ArgumentError('Unknown Logintype value: $value');
    }
  }
}

extension Unique<E, Id> on List<E> {
  List<E> unique([Id Function(E element)? id, bool inplace = true]) {
    final ids = Set();
    var list = inplace ? this : List<E>.from(this);
    list.retainWhere((x) => ids.add(id != null ? id(x) : x as Id));
    return list;
  }
}

class MyNetworkProvider extends ChangeNotifier {

  PackageInfo? appInfo;

  DateTime lastGetAllGroupTime = DateTime.now();

  static final MyNetworkProvider _singleton = MyNetworkProvider._internal();

  MyNetworkProvider._internal();

  factory MyNetworkProvider() {
    if (_singleton.appInfo == null) {
      PackageInfo.fromPlatform().then((value) => _singleton.appInfo = value);
    }
    return _singleton;
  }

  ///清除登录标志
  doLogout() async {
    var userId = MyInstance().user?.user?.id ?? 0;
    var deviceCode = MyInstance().deviceCode;
    lastGetAllGroupTime = DateTime.now().subtract(Duration(seconds: 3600));
    await MyInstance().set(null);
    await MyInstance().setGroup(null);
    MyInstance().deviceCode = "";
  }


//邮件类型：1-注册用户、2-找回/重置密码、3-验证邮箱、4-更换邮箱
  Future<ResponseModel<String>> getCode(
    String phone,
  ) async {
    String url =
        "${AppConfig.userUrl()}/api/admin/auth/send-phone-code?phoneNumber=$phone";
    ResponseModel<String> responseModel = await requestAndConvertResponseModel(
        url,
        formData: {},
        netMethod: NetMethod.post);
    return responseModel;
  }

  /// 账号登录接口
  /// @param account use phone number
  /// @param password : password or code
  /// @param logType : 'A':账号密码登录  'V':验证码登录   'S':'扫码登录'
  /// @return
  Future<ResponseModel<LoginResponseModel>> login(
      String account, String password, Logintype logType) async {
    var appInfo = await PackageInfo.fromPlatform();
    var uuid = await NativeBridge.uuid();
    String url = "${AppConfig.userUrl()}/api/admin/auth/login-by-password";
    var formData = {
      "deviceCode": uuid,
      "deviceType": "web",
      "deviceModel": "",
      "appVersion": appInfo.version,
      "username": account,
    };
    if (logType == Logintype.scan) {
      url = "${AppConfig.userUrl()}/api/admin/auth/login-by-password";
      formData.addAll({"vcode": password, "password": ""});
    } else if (logType == Logintype.password) {
      url = "${AppConfig.userUrl()}/api/admin/auth/login-by-password";
      formData.addAll({
        "password": password.toMd5(),
      });
    } else if (logType == Logintype.code) {
      url = "${AppConfig.userUrl()}/api/admin/auth/login-by-phoneCode";
      formData.addAll({
        "code": password,
      });
    }
    ResponseModel<LoginResponseModel> responseModel =
        await requestAndConvertResponseModel(url,
            formData: formData, netMethod: NetMethod.post);

    if (responseModel.isSuccess) {
      await MyInstance().set(responseModel.model);
    }
    return responseModel;
  }

  Future<ResponseModel<UserModel>> logout() async {
    String url = "${AppConfig.userUrl()}/api/admin/auth/logout";
    var uuid = await NativeBridge.uuid();
    ResponseModel<UserModel> responseModel =
        await requestAndConvertResponseModel(
      url,
      formData: {"type": "主动", "clientType": "iOS", "deviceCode": uuid},
      netMethod: NetMethod.post,
    );
    return responseModel;
  }


  //api/admin/auth/getcode-by-phone
  Future<ResponseModel<String>> verifyCodeByPhone(
      String phone, String code) async {
    String url = "${AppConfig.userUrl()}/api/admin/auth/verify-code-by-phone";
    ResponseModel<String> responseModel = await requestAndConvertResponseModel(
      url,
      formData: {"phone": phone, "code": code},
      netMethod: NetMethod.post,
      isUrlEncode: true,
    );
    return responseModel;
  }


  Future<ResponseModel<User>> getUserInfo() async {
    String url = "${AppConfig.userUrl()}/api/admin/users/getUser";
    ResponseModel<User> responseModel =
        await requestAndConvertResponseModel(url, netMethod: NetMethod.get);

    if (responseModel.isSuccess) {
      var user = MyInstance().user;
      if (responseModel.model != null) {
        user?.user = responseModel.model!;
      }
      await MyInstance().set(user);
    }

    notifyListeners();
    return responseModel;
  }

  Future<String> getAvatarTempUrl() async {
    Directory dir = await getApplicationDocumentsDirectory();
    String savePath = "${dir.path}/avatar.png";
    return savePath;
  }

  Future<void> createDirectoryIfNotExists(String folderName) async {
    // final directory = await getApplicationDocumentsDirectory(); // 应用私有目录
    final newDir = Directory(folderName);

    if (!(await newDir.exists())) {
      await newDir.create(recursive: true);
      debugPrint('✅ Directory created: ${newDir.path}');
    } else {
      debugPrint('📁 Directory already exists: ${newDir.path}');
    }
  }

  updateUserinfo() async {
    await getUserInfo();
  }

  userInfoUpdate() {
    notifyListeners();
  }
}
