// services/login_service.dart
import 'package:ablumwin/user/my_instance.dart';
import 'package:flutter/cupertino.dart';

import '../user/models/qr_code_model.dart';
import '../user/provider/mine_provider.dart';
import '../network/response/response_model.dart';
import '../user/models/login_response_model.dart';

/// 登录服务类 - 封装 MyNetworkProvider 的登录相关方法
class LoginService {
  static final _provider = MyNetworkProvider();

  /// 密码登录
  /// [phone] 手机号
  /// [password] 密码
  static Future<LoginResult> loginWithPassword(String phone, String password) async {
    try {
      final response = await _provider.login(
        phone,
        password,
        Logintype.password,
      );

      return _handleLoginResponse(response);
    } catch (e) {
      return LoginResult(
        success: false,
        message: '登录失败：${e.toString()}',
      );
    }
  }

  /// 获取扫码登录二维码
  /// [deviceCode] 设备唯一标识
  static Future<QrCodeResult> getQrCode(String deviceCode) async {
    try {
      final response = await _provider.getQrCode(deviceCode);

      if (response.isSuccess && response.model != null) {
        return QrCodeResult(
          success: true,
          message: response.message ?? '获取二维码成功',
          qrCodeData: response.model!,
        );
      } else {
        return QrCodeResult(
          success: false,
          message: response.message ?? '获取二维码失败',
        );
      }
    } catch (e) {
      return QrCodeResult(
        success: false,
        message: '获取二维码异常：${e.toString()}',
      );
    }
  }
  /// 扫码登录轮询接口
  /// 用于检查用户是否已通过APP扫码确认登录
  static Future<LoginResult> p6useQRLogin(String deviceCode) async {
    try {
      final response = await _provider.p6useQRLogin(deviceCode);

      return LoginResult(
        success: response.isSuccess,
        message: response.isSuccess ? '登录成功' : (response.message ?? '等待扫码确认'),
        loginData: response.model,
      );
    } catch (e) {
      return LoginResult(
        success: false,
        message: '扫码登录异常：${e.toString()}',
      );
    }
  }


  /// 验证码登录
  /// [phone] 手机号
  /// [verifyCode] 验证码
  static Future<LoginResult> loginWithVerifyCode(String phone, String verifyCode) async {
    try {
      final response = await _provider.login(
        phone,
        verifyCode,
        Logintype.code,
      );

      return _handleLoginResponse(response);
    } catch (e) {
      return LoginResult(
        success: false,
        message: '登录失败：${e.toString()}',
      );
    }
  }

  /// 扫码登录
  /// [phone] 手机号
  /// [scanCode] 扫码结果
  static Future<LoginResult> loginWithScan(String phone, String scanCode) async {
    try {
      final response = await _provider.login(
        phone,
        scanCode,
        Logintype.scan,
      );

      return _handleLoginResponse(response);
    } catch (e) {
      return LoginResult(
        success: false,
        message: '登录失败：${e.toString()}',
      );
    }
  }

  /// 发送验证码
  /// [phone] 手机号
  static Future<SendCodeResult> sendVerifyCode(String phone) async {
    try {
      // final response = await _provider.getCode(phone);
      final response = await _provider.getPhoneCheckCode(phone);
      debugPrint('PhoneCheckCode : ${response.model}');
      final codeRes = await _provider.getActualCode(phone, response.model ?? '');
      debugPrint('ActualCode : ${codeRes}');

      if (response.isSuccess) {
        return SendCodeResult(
          success: true,
          message: '验证码已发送',
        );
      } else {
        return SendCodeResult(
          success: false,
          message: response.message ?? '验证码发送失败',
        );
      }
    } catch (e) {
      return SendCodeResult(
        success: false,
        message: '验证码发送失败：${e.toString()}',
      );
    }
  }

  /// 验证手机验证码
  /// [phone] 手机号
  /// [code] 验证码
  static Future<VerifyCodeResult> verifyCodeByPhone(String phone, String code) async {
    try {
      final response = await _provider.verifyCodeByPhone(phone, code);

      if (response.isSuccess) {
        return VerifyCodeResult(
          success: true,
          message: '验证成功',
        );
      } else {
        return VerifyCodeResult(
          success: false,
          message: response.message ?? '验证失败',
        );
      }
    } catch (e) {
      return VerifyCodeResult(
        success: false,
        message: '验证失败：${e.toString()}',
      );
    }
  }

  /// 登出
  static Future<LogoutResult> logout() async {
    try {
      final response = await _provider.logout();

      if (response.isSuccess) {
        await _provider.doLogout();
        return LogoutResult(
          success: true,
          message: '登出成功',
        );
      } else {
        return LogoutResult(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      return LogoutResult(
        success: false,
        message: '登出失败：${e.toString()}',
      );
    }
  }

  /// 处理登录响应
  static LoginResult _handleLoginResponse(
      ResponseModel<LoginResponseModel> response) {
    if (response.isSuccess && response.model != null) {
      // 登录成功，用户信息已在 MyNetworkProvider.login() 中保存到 MyInstance
      MyInstance().deviceCode = response.model!.user!.deviceCode!;
      return LoginResult(
        success: true,
        message: '登录成功',
        loginData: response.model,
      );
    } else {
      return LoginResult(
        success: false,
        message: response.message ?? '登录失败',
      );
    }
  }
}

/// 登录结果类
class LoginResult {
  final bool success;
  final String message;
  final LoginResponseModel? loginData;

  LoginResult({
    required this.success,
    required this.message,
    this.loginData,
  });
}

/// 获取二维码结果类
class QrCodeResult {
  final bool success;
  final String message;
  final QrCodeModel? qrCodeData;

  QrCodeResult({
    required this.success,
    required this.message,
    this.qrCodeData,
  });
}
/// 发送验证码结果类
class SendCodeResult {
  final bool success;
  final String message;

  SendCodeResult({
    required this.success,
    required this.message,
  });
}

/// 验证码验证结果类
class VerifyCodeResult {
  final bool success;
  final String message;

  VerifyCodeResult({
    required this.success,
    required this.message,
  });
}

/// 登出结果类
class LogoutResult {
  final bool success;
  final String message;

  LogoutResult({
    required this.success,
    required this.message,
  });
}