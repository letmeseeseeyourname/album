import 'dart:convert';
import 'dart:io';

import 'package:ablumwin/network/utils/dev_environment_helper.dart';
import 'package:ablumwin/pages/remote_album/managers/album_data_manager.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:semaphore_plus/semaphore_plus.dart';
import '../../eventbus/event_bus.dart';
import '../../eventbus/p2p_events.dart';
import '../../minio/mc_service.dart';
import '../../minio/minio_config.dart';
import '../../network/constant_sign.dart';
import '../../network/network_provider.dart';
import '../../network/response/response_model.dart';
import '../../pages/home_page.dart';
import '../../utils/win_helper.dart';
import '../models/device_model.dart';
import '../models/login_response_model.dart';
import '../models/my_all_groups_model.dart';
import '../models/p6device_info_model.dart';
import '../models/upgrade_info_model.dart';
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
  // 添加 P2P 连接锁
  final _p2pLock = LocalSemaphore(1);
  bool _isP2pConnecting = false; // 连接中标志

  // 🆕 当前 P2P 连接状态（用于同步获取）
  P2pConnectionStatus _currentP2pStatus = P2pConnectionStatus.disconnected;

  static final MyNetworkProvider _singleton = MyNetworkProvider._internal();

  MyNetworkProvider._internal();

  factory MyNetworkProvider() {
    if (_singleton.appInfo == null) {
      PackageInfo.fromPlatform().then((value) => _singleton.appInfo = value);
    }
    return _singleton;
  }

  // 🆕 获取当前 P2P 连接状态（同步方法，供 UI 初始化时使用）
  P2pConnectionStatus getCurrentP2pStatus() {
    return _currentP2pStatus;
  }

  // 🆕 获取当前 P2P 账号
  String getCurrentP2pAccount() {
    return currentP2pAccount;
  }

  ///清除登录标志
  doLogout() async {
    var userId = MyInstance().user?.user?.id ?? 0;
    var deviceCode = MyInstance().deviceCode;
    lastGetAllGroupTime = DateTime.now().subtract(Duration(seconds: 3600));
    await p6Logout();
    await MyInstance().set(null);
    await MyInstance().setGroup(null);
    MyInstance().deviceCode = "";
    await AlbumDataManager().clearAllCache();
  }

  doP6login() async {
    var deviceCode = MyInstance().deviceCode;
    var p6loginResp = await p6Login(deviceCode);
    return p6loginResp;
  }

  /// 🆕 优化版：获取所有 Groups（快速返回，不等待 P2P 连接）
  Future<ResponseModel<MyAllGroupsModel>> getAllGroups({
    bool force = false,
  }) async {
    await sm.acquire();

    // 缓存检查
    if (!force &&
        DateTime.now().difference(lastGetAllGroupTime).inSeconds < 5 &&
        groupResp != null &&
        groupResp!.isSuccess) {
      sm.release();
      return groupResp!;
    }

    String url = "${AppConfig.userUrl()}/api/admin/group/get-all-groups";

    ResponseModel<MyAllGroupsModel> responseModel =
        await requestAndConvertResponseModel(url, netMethod: NetMethod.get);

    if (responseModel.isSuccess) {
      MyInstance().groups = responseModel.model?.groups ?? [];
      var allGroup = responseModel.model?.groups ?? [];

      if (allGroup.isEmpty) {
        notifyListeners();
        sm.release();
        MyInstance().p6deviceInfoModel = null;
        return responseModel;
      }

      // 确定要选中的 group
      var selectGroupId = MyInstance().group?.groupId;
      var group = allGroup
          .where((element) => element.groupId == selectGroupId)
          .toList()
          .firstOrNull;

      if (group == null) {
        group = allGroup[0];
        await MyInstance().setGroup(group);
      }

      // 🆕 关键优化：先通知 UI 更新（显示 groups 列表）
      notifyListeners();

      // 🆕 记录时间和响应，释放信号量
      lastGetAllGroupTime = DateTime.now();
      groupResp = responseModel;
      sm.release();

      // 🆕 异步建立 P2P 连接（不阻塞 UI）
      _connectToGroupAsync(group.deviceCode ?? "");

      return responseModel;
    } else {
      notifyListeners();
      lastGetAllGroupTime = DateTime.now();
      groupResp = responseModel;
      sm.release();
      return responseModel;
    }
  }

  /// 🆕 异步连接到 Group（不阻塞调用者）
  Future<void> _connectToGroupAsync(String deviceCode) async {
    try {
      debugPrint('开始异步建立 P2P 连接: $deviceCode');
      await changeGroup(deviceCode);
      debugPrint('异步 P2P 连接完成: $deviceCode');
    } catch (e) {
      debugPrint('异步 P2P 连接失败: $e');
    }
  }

  Future<ResponseModel<UserModel>> changeGroup(String deviceCode) async {
    if (MyInstance().deviceCode == deviceCode) {
      return ResponseModel<UserModel>(
        message: "已在当前设备",
        code: 200,
        model: null,
      );
    }

    var resp = await getDevice(deviceCode);
    if (resp.isNotSuccess) {
      debugPrint("getDevice error ${resp.message}");
      return ResponseModel<UserModel>(
        message: "获取设备信息失败",
        code: -1,
        model: null,
      );
    } else {
      /// 局域网与p2p 判断
      var p6IP = resp.model?.p2pAddress ?? "";
      await DevEnvironmentHelper().resetEnvironment(p6IP);
    }
    MyInstance().deviceCode = deviceCode;
    MyInstance().deviceModel = resp.model!;
    await _loginP2p(resp.model?.p2pName ?? "");
    await _initMinIO();
    var deviceRsp = await getStorageInfo();
    await Future.delayed(const Duration(seconds: 2));
    var p6loginResp = await p6Login(deviceCode);
    if (deviceRsp.isSuccess) {
      P6DeviceInfoModel? storageInfo = deviceRsp.model;
      debugPrint("storageInfo $storageInfo");
      MyInstance().p6deviceInfoModel = storageInfo;
    }
    MCEventBus.fire(GroupChangedEvent());
    return p6loginResp;
  }

  Future<void> _initMinIO() async{
   await McService.instance.reconfigure(
        endpoint: 'http://${AppConfig.usedIP}:9000',
        accessKey: MinioConfig.accessKey,
        secretKey: MinioConfig.secretKey);
  }

  /// 获取二维码接口
  /// Path: api/admin/auth/get-qr-code
  Future<ResponseModel<QrCodeModel>> getQrCode(String deviceCode) async {
    String url = "${AppConfig.userUrl()}/api/admin/auth/get-qr-code";

    // 根据现有代码习惯，使用 requestAndConvertResponseModel 统一处理
    // 参照 getDevice 接口，这里使用 POST 方式传递 deviceCode
    ResponseModel<QrCodeModel> responseModel =
        await requestAndConvertResponseModel(
          url,
          formData: {"deviceCode": deviceCode},
          netMethod: NetMethod.post,
          // 如果后端强制要求 GET，请改为 NetMethod.get 并将参数拼接到 url 或调整 formData
          isUrlEncode: true,
        );

    return responseModel;
  }

  Future<ResponseModel<LoginResponseModel>> p6useQRLogin(
    String deviceCode,
  ) async {
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
  Future<ResponseModel<String>> getCode(String phone) async {
    String url =
        "${AppConfig.userUrl()}/api/admin/auth/send-phone-code?phoneNumber=$phone";
    ResponseModel<String> responseModel = await requestAndConvertResponseModel(
      url,
      formData: {},
      netMethod: NetMethod.post,
    );
    return responseModel;
  }

  ///更新获取验证码的方式
  ///get-phone-code-new -> send-phone-code
  Future<ResponseModel<String>> getPhoneCheckCode(String phone) async {
    String url =
        "${AppConfig.userUrl()}/api/admin/auth/get-phone-code-new";
    ResponseModel<String> responseModel = await requestAndConvertResponseModel(
      url,
      formData: {
        'phone':phone,
        "code":""
      },
      netMethod: NetMethod.post,
    );
    return responseModel;
  }

  ///get Actual verification code
  Future<ResponseModel<String>> getActualCode(String phone,String checkCode) async {
    String url =
        "${AppConfig.userUrl()}/api/admin/auth/send-phone-code2";
    ResponseModel<String> responseModel = await requestAndConvertResponseModel(
      url,
      formData: {
        "phone": phone,
        "code": checkCode,
      },
      netMethod: NetMethod.post,
    );
    return responseModel;
  }

  /// 账号登录接口
  /// @param account use phone number
  /// @param password : password or code
  /// @param logType : 'A':账号密码登录  'V':验证码登录   'S':'扫码登录'
  /// @return
  Future<ResponseModel<LoginResponseModel>> login(
    String account,
    String password,
    Logintype logType,
  ) async {
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
      formData.addAll({"password": password.toMd5()});
    } else if (logType == Logintype.code) {
      url = "${AppConfig.userUrl()}/api/admin/auth/login-by-phoneCode";
      formData.addAll({"code": password});
    }
    ResponseModel<LoginResponseModel> responseModel =
        await requestAndConvertResponseModel(
          url,
          formData: formData,
          netMethod: NetMethod.post,
        );

    if (responseModel.isSuccess) {
      await MyInstance().set(responseModel.model);
    }

    notifyListeners();
    return responseModel;
  }

  //api/admin/auth/getcode-by-phone
  Future<ResponseModel<String>> verifyCodeByPhone(
    String phone,
    String code,
  ) async {
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
    ResponseModel<User> responseModel = await requestAndConvertResponseModel(
      url,
      netMethod: NetMethod.get,
    );

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

  Future<ResponseModel<UpgradeInfoModel>> getUpGradeInfo() async {
    String url = "${AppConfig.userUrl()}/api/admin/upgrade/getUPgrade";
    ResponseModel<UpgradeInfoModel> responseModel =
        await requestAndConvertResponseModel(
          url,
          formData: {"status": 0, "packetType": 5, "versionCode": 2},
          netMethod: NetMethod.post,
        );

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
        await requestAndConvertResponseModel(
          url,
          formData: {
            "deviceCode": deviceCode,
            "token": user?.accessToken ?? "",
            "loginType": "B",
            "userId": user?.user?.id ?? 0,
          },
          netMethod: NetMethod.post,
          useCache: false,
        );

    return responseModel;
  }

  Future<ResponseModel<UserModel>> p6Logout() async {
    String url = "${AppConfig.hostUrl()}/nass/clound/common/p6LoginOut";
    var user = MyInstance().user;
    ResponseModel<UserModel> responseModel =
        await requestAndConvertResponseModel(
          url,
          formData: {
            "token": user?.accessToken ?? "",
            "loginType": "B",
            "userId": user?.user?.id ?? 0,
          },
          netMethod: NetMethod.post,
        );
    return responseModel;
  }

  /// 🆕 检查服务器连接状态（用于连接状态弹窗）
  Future<bool> checkServerStatus() async {
    try {
      String url = "${AppConfig.userUrl()}/api/admin/users/getUser";
      ResponseModel<User> responseModel = await requestAndConvertResponseModel(
        url,
        netMethod: NetMethod.get,
      );
      return responseModel.isSuccess;
    } catch (e) {
      debugPrint('检查服务器状态异常: $e');
      return false;
    }
  }

  Future<bool> getUploadPath() async {
    try {
      String url = "${AppConfig.hostUrl()}/nass/ps/storage/getUploadPath";
      ResponseModel responseModel = await requestAndConvertResponseModel(
        url,
        formData: {"type": "H"},
        netMethod: NetMethod.post,
      );
      return responseModel.isSuccess;
    } catch (e) {
      debugPrint('getUploadPath 异常: $e');
      return false;
    }
  }

  //nass/ps/storage/getStorageInfo
  Future<ResponseModel<P6DeviceInfoModel>> getStorageInfo() async {
    String url = "${AppConfig.hostUrl()}/nass/ps/storage/getStorageInfo";
    ResponseModel<P6DeviceInfoModel> responseModel =
        await requestAndConvertResponseModel(
          url,
          formData: {},
          netMethod: NetMethod.post,
        );
    return responseModel;
  }

  Future<ResponseModel<DeviceModel>> getDevice(String deviceCode) async {
    String url =
        "${AppConfig.userUrl()}/api/admin/device/getDeviceBydeviceCode";
    // var user = MyInstance().user;
    ResponseModel<DeviceModel> responseModel =
        await requestAndConvertResponseModel(
          url,
          formData: {"deviceCode": deviceCode},
          netMethod: NetMethod.post,
          isUrlEncode: true,
        );
    if (responseModel.isSuccess) {
      MyInstance().deviceModel = responseModel.model;
    }
    return responseModel;
  }

  /// 修改后的 _loginP2p 方法
  Future<bool> _loginP2p(String p2pName) async {
    // 🔧 修复1: 使用信号量保证串行执行
    await _p2pLock.acquire();
    try {
      // 🔧 修复2: 双重检查，获取锁后再次验证
      if (currentP2pAccount == p2pName &&
          _currentP2pStatus == P2pConnectionStatus.connected) {
        debugPrint("P2P已连接到账号: $p2pName");
        return true;
      }

      // 🔧 修复3: 检查是否正在连接中
      if (_isP2pConnecting) {
        debugPrint("P2P正在连接中，跳过重复调用");
        return false;
      }

      _isP2pConnecting = true;

      final p2pService = PgTunnelService();

      // 如果当前账号与要连接的账号相同，直接返回成功
      if (currentP2pAccount == p2pName) {
        debugPrint("P2P已连接到账号: $p2pName");
        _currentP2pStatus = P2pConnectionStatus.connected; // 🆕 更新状态
        MCEventBus.fire(
          P2pConnectionEvent(
            status: P2pConnectionStatus.connected,
            p2pName: p2pName,
          ),
        );
        return true;
      }

      // 🆕 发送连接中事件，并更新状态
      _currentP2pStatus = P2pConnectionStatus.connecting;
      MCEventBus.fire(
        P2pConnectionEvent(
          status: P2pConnectionStatus.connecting,
          p2pName: p2pName,
        ),
      );

      // 如果有旧账号，先清理旧连接
      if (currentP2pAccount.isNotEmpty) {
        debugPrint("清理旧P2P连接: $currentP2pAccount");
        try {
          await p2pService.connectDelete(
            peerId: currentP2pAccount,
            clientAddr: "127.0.0.1:9000",
          );
          await p2pService.connectDelete(
            peerId: currentP2pAccount,
            clientAddr: "127.0.0.1:8080",
          );
          await p2pService.stop();
        } catch (e) {
          debugPrint("清理旧连接时出错: $e");
        }
      }

      // 获取设备UUID
      String uuid = await WinHelper.uuid();

      int nowInMicroseconds = DateTime.now().microsecondsSinceEpoch;
      debugPrint(
        "Starting P2P tunnel with account: $p2pName, device : $nowInMicroseconds",
      );
      // 启动隧道
      await p2pService.start(nowInMicroseconds.toString());

      // 先更新账号，确保后续清理能正常工作
      currentP2pAccount = p2pName;

      try {
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

        debugPrint("✅ P2P连接成功: $p2pName");

        // 🆕 发送连接成功事件，并更新状态
        _currentP2pStatus = P2pConnectionStatus.connected;
        MCEventBus.fire(
          P2pConnectionEvent(
            status: P2pConnectionStatus.connected,
            p2pName: p2pName,
          ),
        );

        _isP2pConnecting = false;
        _p2pLock.release(); // 🔧 确保释放锁
        return true;
      } catch (e) {
        // 连接失败时回滚：清理已建立的连接
        debugPrint("P2P连接部分失败，开始回滚: $e");
        try {
          await p2pService.connectDelete(
            peerId: p2pName,
            clientAddr: "127.0.0.1:8080",
          );
        } catch (_) {}
        try {
          await p2pService.connectDelete(
            peerId: p2pName,
            clientAddr: "127.0.0.1:9000",
          );
        } catch (_) {}
        await p2pService.stop();
        currentP2pAccount = '';

        // 🆕 发送连接失败事件，并更新状态
        _currentP2pStatus = P2pConnectionStatus.failed;
        MCEventBus.fire(
          P2pConnectionEvent(
            status: P2pConnectionStatus.failed,
            p2pName: p2pName,
            errorMessage: e.toString(),
          ),
        );

        rethrow;
      }
    } catch (e) {
      debugPrint("❌ P2P连接失败: $e");
      currentP2pAccount = '';

      // 🆕 发送连接失败事件，并更新状态
      _currentP2pStatus = P2pConnectionStatus.failed;
      MCEventBus.fire(
        P2pConnectionEvent(
          status: P2pConnectionStatus.failed,
          p2pName: p2pName,
          errorMessage: e.toString(),
        ),
      );
      _isP2pConnecting = false;
      _p2pLock.release(); // 🔧 确保释放锁
      return false;
    }
  }

  /// 🆕 断开P2P连接（公开方法，供退出登录时调用）
  /// 修改后的 disconnectP2p 方法
  Future<bool> disconnectP2p() async {
    try {
      if (currentP2pAccount.isEmpty) {
        debugPrint("P2P未连接，无需断开");
        return true;
      }

      final p2pService = PgTunnelService();
      final oldAccount = currentP2pAccount;
      debugPrint("开始断开P2P连接: $oldAccount");

      try {
        await p2pService.connectDelete(
          peerId: oldAccount,
          clientAddr: "127.0.0.1:9000",
        );
        debugPrint("✅ 已删除 9000 端口连接");
      } catch (e) {
        debugPrint("⚠️ 删除 9000 端口连接时出错: $e");
      }

      try {
        await p2pService.connectDelete(
          peerId: oldAccount,
          clientAddr: "127.0.0.1:8080",
        );
        debugPrint("✅ 已删除 8080 端口连接");
      } catch (e) {
        debugPrint("⚠️ 删除 8080 端口连接时出错: $e");
      }

      try {
        await p2pService.stop();
        debugPrint("✅ P2P隧道已停止");
      } catch (e) {
        debugPrint("⚠️ 停止P2P隧道时出错: $e");
      }

      currentP2pAccount = '';
      debugPrint("✅ P2P连接已完全断开");

      // 🆕 发送断开连接事件，并更新状态
      _currentP2pStatus = P2pConnectionStatus.disconnected;
      MCEventBus.fire(
        P2pConnectionEvent(
          status: P2pConnectionStatus.disconnected,
          p2pName: oldAccount,
        ),
      );

      return true;
    } catch (e) {
      debugPrint("❌ 断开P2P连接失败: $e");
      return false;
    }
  }

  /// 🆕 重连 P2P（公开方法，供外部调用）
  Future<bool> reconnectP2p() async {
    try {
      final deviceModel = MyInstance().deviceModel;
      final p2pName = deviceModel?.p2pName ?? '';

      if (p2pName.isEmpty) {
        debugPrint("❌ 无法重连：缺少 P2P 名称");
        _currentP2pStatus = P2pConnectionStatus.failed; // 🆕 更新状态
        MCEventBus.fire(
          P2pConnectionEvent(
            status: P2pConnectionStatus.failed,
            errorMessage: "缺少 P2P 名称",
          ),
        );
        return false;
      }

      debugPrint("开始重连 P2P: $p2pName");

      // 先断开现有连接
      currentP2pAccount = ''; // 清空以强制重连

      // 重新连接
      return await _loginP2p(p2pName);
    } catch (e) {
      debugPrint("❌ P2P 重连失败: $e");
      _currentP2pStatus = P2pConnectionStatus.failed; // 🆕 更新状态
      MCEventBus.fire(
        P2pConnectionEvent(
          status: P2pConnectionStatus.failed,
          errorMessage: e.toString(),
        ),
      );
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
