import 'package:ablumwin/network/interceptor/error_interceptor.dart';
import 'package:dio/dio.dart';

import 'interceptor/awesome_dio_interceptor.dart';
import 'interceptor/header_interceptor.dart';


class Network {

  static const Duration connectTimeout = Duration(seconds: 5);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);

  static Network instance = Network();

  Dio? dio;

  Dio getDio() {
    if (this.dio != null) {
      return this.dio!;
    }
    BaseOptions options = _initOptions();
    Dio dio = Dio(options);
    List<Interceptor> inters = _initInterceptors();
    dio.interceptors.addAll(inters);
    return dio;
  }

  ///基础配置
  BaseOptions _initOptions() {
    return BaseOptions(
      baseUrl: "",
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      sendTimeout: sendTimeout,
    );
  }

  /// 插件
  List<Interceptor> _initInterceptors() {
    List<Interceptor> interceptors = [];
    ///header公共参数
    interceptors.add(HeaderInterceptor());
    interceptors.add(ErrorInterceptor());
    interceptors.add(AwesomeDioInterceptor());
    return interceptors;
  }
}