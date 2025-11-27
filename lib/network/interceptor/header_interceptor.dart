import 'package:ablumwin/utils/win_helper.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../user/my_instance.dart';

class HeaderInterceptor extends Interceptor {
  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    PackageInfo info = await PackageInfo.fromPlatform();
    var json = MyInstance().user?.accessToken ?? "";
    var cookie = await  MyInstance().getCookie() ?? "";
    var deviceCode = await WinHelper.uuid();
    Map<String, dynamic> headers = {
      "content-type": "application/json",
      "Accept-Language": "zh_CN",
      "version": info.version,
      "versionCode": info.buildNumber,
      "deviceCode": deviceCode,
      "Cookie": cookie
    };
    if (json.isNotEmpty) {
      headers["Authorization"] = json;
    }
    options.headers.addAll(headers);
    super.onRequest(options, handler);
  }
}
