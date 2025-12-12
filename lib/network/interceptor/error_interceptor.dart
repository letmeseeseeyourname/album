// Path: interceptor/error_interceptor.dart

import 'package:ablumwin/user/my_instance.dart';
import 'package:ablumwin/user/provider/mine_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

import '../utils/dev_environment_helper.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 通过 err.requestOptions 获取请求配置
    final RequestOptions options = err.requestOptions;

    // 打印错误信息
    debugPrint("--- ❌ Error Interceptor ---");
    debugPrint("Request Path: ${options.path}");
    debugPrint("Error Type: ${err.type}");
    debugPrint("Error Message: ${err.message}");
    String errorMessage = _handleError(err);
    _checkException(err);

    // 你可以在这里根据 errorMessage 进行一些全局操作，
    // 例如：显示一个 Toast 提示用户，或者跳转到登录页（如果错误是401/未授权）。
    debugPrint("Processed Error Message: $errorMessage");

    // 如果你希望继续将错误传递给调用者，请使用 handler.next(err).
    // 如果你已经完全处理了错误并希望终止它，请使用 handler.resolve(response).
    // 通常对于错误处理，我们会使用 handler.next(err)
    handler.next(err);
  }

  String _handleError(DioException error) {
    String message = "未知错误";

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        message = "连接超时";
        break;
      case DioExceptionType.sendTimeout:
        message = "请求超时";
        break;
      case DioExceptionType.receiveTimeout:
        message = "响应超时";
        break;
      case DioExceptionType.badResponse:
      // HTTP 状态码错误
        final statusCode = error.response?.statusCode;
        switch (statusCode) {
          case 400:
            message = "请求语法错误";
            break;
          case 401:
            message = "未授权，请重新登录";
            // TODO: 在此执行清除用户信息的逻辑，并跳转到登录页
            break;
          case 403:
            message = "拒绝访问";
            break;
          case 404:
            message = "请求资源不存在";
            break;
          case 500:
            message = "服务器内部错误";
            break;
          default:
            message = "网络异常：HTTP $statusCode";
        }
        break;
      case DioExceptionType.cancel:
        message = "请求已被取消";
        break;
      case DioExceptionType.unknown:
        if (error.message?.contains('SocketException') ?? false) {
          message = "网络连接失败，请检查网络设置";
        } else {
          message = "未知错误: ${error.message}";
        }
        break;
      default:
        message = "未知错误";
        break;
    }
    return message;
  }

  /// 判断环境，做IP切换
  void _checkException(DioException error,) async {
    var deviceCode = MyInstance().deviceCode;
    await MyNetworkProvider().getDevice(deviceCode);
    var message = error.message;
    var path = error.requestOptions.path;
    var p6IP = MyInstance().deviceModel?.p2pAddress;
    if(path.contains('127.0.0.1')&&message!.contains('远程计算机拒绝网络连接')) {
      DevEnvironmentHelper().resetEnvironment(p6IP!);
    }else if(error.type == DioExceptionType.connectionTimeout){
      DevEnvironmentHelper().resetEnvironment(p6IP!);
    }
  }
}