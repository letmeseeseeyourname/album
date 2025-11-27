import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:semaphore_plus/semaphore_plus.dart';
import '../../eventbus/event_bus.dart';
import '../../network/constant_sign.dart';
import '../../network/network_provider.dart';
import '../../network/response/response_model.dart';
import '../../pages/home_page.dart';
import '../../utils/win_helper.dart';
import '../models/device_model.dart';
import '../models/login_response_model.dart';
import '../models/my_all_groups_model.dart';
import '../models/p6device_info_model.dart';
import '../models/user.dart';
import '../models/user_model.dart';
import '../my_instance.dart';
import '../models/qr_code_model.dart';
import '../../p2p/pg_tunnel_service.dart';


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
  final sm = LocalSemaphore(1);
  ResponseModel<MyAllGroupsModel>? groupResp;
  DateTime lastGetAllGroupTime = DateTime.now();
  String currentP2pAccount = ''; // 当前P2P连接的账号

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

  doP6login() async {
    var deviceCode = MyInstance().deviceCode;
    var p6loginResp = await p6Login(deviceCode);
    return p6loginResp;
  }

  Future<ResponseModel<MyAllGroupsModel>> getAllGroups({bool force = false}) async {
    await sm.acquire();
    if (!force && DateTime.now().difference(lastGetAllGroupTime).inSeconds < 5 &&
        groupResp != null &&
        groupResp!.isSuccess) {
      sm.release();
      return groupResp!;
    }
    String url = "${AppConfig.userUrl()}/api/admin/group/get-all-groups";

    ResponseModel<MyAllGroupsModel> responseModel =
    await requestAndConvertResponseModel(
      url,
      netMethod: NetMethod.get,
    );
    if (responseModel.isSuccess) {
      MyInstance().groups = responseModel.model?.groups ?? [];
      var allGroup = responseModel.model?.groups ?? [];
      if (allGroup.isEmpty) {
        notifyListeners();
        sm.release();
        MyInstance().p6deviceInfoModel = null;
        return responseModel;
      }
      var selectGroupId = MyInstance().group?.groupId;
      var group = allGroup
          .where(
            (element) => element.groupId == selectGroupId,
      )
          .toList()
          .firstOrNull;
      if (group == null) {
        group = allGroup[0];
        await MyInstance().setGroup(group);
      }
      await changeGroup(group.deviceCode ?? "");
      notifyListeners();
    } else {
      // mygroups = MyAllGroupsModel(groups: [], total: 0);
      notifyListeners();
    }
    lastGetAllGroupTime = DateTime.now();
    groupResp = responseModel;
    sm.release();
    return responseModel;
  }


  Future<ResponseModel<UserModel>> changeGroup(String deviceCode) async {
    if (MyInstance().deviceCode == deviceCode) {
      return ResponseModel<UserModel>(
          message: "已在当前设备", code: 200, model: null);
    }

    var resp = await getDevice(deviceCode);
    if (resp.isNotSuccess) {
      debugPrint("getDevice error ${resp.message}");
      return ResponseModel<UserModel>(
          message: "获取设备信息失败", code: -1, model: null);
    }
    MyInstance().deviceCode = deviceCode;
    MyInstance().deviceModel = resp.model!;
    await _loginP2p(resp.model?.p2pName ?? "");
    var p6loginResp = await p6Login(deviceCode);

    var deviceRsp = await getStorageInfo();
    if (deviceRsp.isSuccess) {
      P6DeviceInfoModel? storageInfo = deviceRsp.model;
      debugPrint("storageInfo $storageInfo");
      MyInstance().p6deviceInfoModel = storageInfo;
    }
    MCEventBus.fire(GroupChangedEvent());
    return p6loginResp;
  }

  /// 获取二维码接口
  /// Path: api/admin/auth/get-qr-code
  Future<ResponseModel<QrCodeModel>> getQrCode(String deviceCode) async {
    String url = "${AppConfig.userUrl()}/api/admin/auth/get-qr-code";

    // 根据现有代码习惯，使用 requestAndConvertResponseModel 统一处理
    // 参照 getDevice 接口，这里使用 POST 方式传递 deviceCode
    ResponseModel<QrCodeModel> responseModel = await requestAndConvertResponseModel(
      url,
      formData: {
        "deviceCode": deviceCode,
      },
      netMethod: NetMethod.post, // 如果后端强制要求 GET，请改为 NetMethod.get 并将参数拼接到 url 或调整 formData
      isUrlEncode: true,
    );

    return responseModel;
  }

  Future<ResponseModel<LoginResponseModel>> p6useQRLogin(String deviceCode) async {
    var appInfo = await PackageInfo.fromPlatform();

    String url = "${AppConfig.userUrl()}/api/admin/auth/p6useQRLogin";

    var formData = {
      "appVersion": appInfo.version,
      "deviceType": "windows",
      "deviceCode": deviceCode,
      "deviceModel": await WinHelper.getDeviceModel(),
    };

    ResponseModel<LoginResponseModel> responseModel =
    await requestAndConvertResponseModel(
      url,
      formData: formData,
      netMethod: NetMethod.post,
    );

    // 登录成功后的处理（与 login 方法保持一致）
    if (responseModel.isSuccess) {
      await MyInstance().set(responseModel.model);
    }

    return responseModel;
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
    var uuid = await WinHelper.uuid();
    String url = "${AppConfig.userUrl()}/api/admin/auth/login-by-password";
    var formData = {
      "deviceCode": uuid,
      "deviceType": "windows",
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
    var uuid = await WinHelper.uuid();
    ResponseModel<UserModel> responseModel =
    await requestAndConvertResponseModel(
      url,
      formData: {"type": "主动", "clientType": "Windows", "deviceCode": uuid},
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

  Future<ResponseModel<UserModel>> p6Login(String deviceCode) async {
    String url = "${AppConfig.hostUrl()}/nass/clound/common/p6Login";
    var user = MyInstance().user;
    ResponseModel<UserModel> responseModel =
    await requestAndConvertResponseModel(url,
        formData: {
          "deviceCode": deviceCode,
          "token": user?.accessToken ?? "",
          "loginType": "A",
          "userId": user?.user?.id ?? 0,
        },
        netMethod: NetMethod.post);

    return responseModel;
  }
  //nass/ps/storage/getStorageInfo
  Future<ResponseModel<P6DeviceInfoModel>> getStorageInfo() async {
    String url = "${AppConfig.hostUrl()}/nass/ps/storage/getStorageInfo";
    ResponseModel<P6DeviceInfoModel> responseModel =
    await requestAndConvertResponseModel(url,
        formData: {}, netMethod: NetMethod.post);
    return responseModel;
  }

  Future<ResponseModel<DeviceModel>> getDevice(String deviceCode) async {
    String url =
        "${AppConfig.userUrl()}/api/admin/device/getDeviceBydeviceCode";
    // var user = MyInstance().user;
    ResponseModel<DeviceModel> responseModel =
    await requestAndConvertResponseModel(url,
        formData: {
          "deviceCode": deviceCode,
        },
        netMethod: NetMethod.post,
        isUrlEncode: true);
    return responseModel;
  }

  ///TODO( add p2p connect )
  Future<bool> _loginP2p(String p2pName) async {
    try {
      final p2pService = PgTunnelService();

      // 如果当前账号与要连接的账号相同，直接返回成功
      if (currentP2pAccount == p2pName) {
        debugPrint("P2P已连接到账号: $p2pName");
        return true;
      }

      // 如果有旧账号，先清理旧连接
      if (currentP2pAccount.isNotEmpty) {
        debugPrint("清理旧P2P连接: $currentP2pAccount");
        try {
          // 删除旧连接
          await p2pService.connectDelete(
            peerId: currentP2pAccount,
            clientAddr: "127.0.0.1:9000",
          );
          await p2pService.connectDelete(
            peerId: currentP2pAccount,
            clientAddr: "127.0.0.1:8080",
          );
          // 停止隧道
          await p2pService.stop();
        } catch (e) {
          debugPrint("清理旧连接时出错: $e");
        }
      }

      // 获取设备UUID
      String uuid = await WinHelper.uuid();
      debugPrint("Starting P2P tunnel with account: $p2pName, uuid: $uuid");

      // 启动隧道
      await p2pService.start(uuid);

      // 添加连接 - 8080端口
      await p2pService.connectAdd(
        peerId: p2pName,
        listenAddr: "127.0.0.1:8080",
        clientAddr: "127.0.0.1:8080",
      );

      // 添加连接 - 9000端口
      await p2pService.connectAdd(
        peerId: p2pName,
        listenAddr: "127.0.0.1:9000",
        clientAddr: "127.0.0.1:9000",
      );

      // 更新当前账号
      currentP2pAccount = p2pName;

      debugPrint("P2P连接成功: $p2pName");
      return true;
    } catch (e) {
      debugPrint("P2P连接失败: $e");
      return false;
    }
  }


  updateUserinfo() async {
    await getUserInfo();
  }

  userInfoUpdate() {
    notifyListeners();
  }
}