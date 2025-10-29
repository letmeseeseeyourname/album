import 'dart:convert';
import 'dart:developer' as LogUtil;
import 'dart:io';

import 'package:ablumwin/network/response/response_model.dart';
import 'package:ablumwin/network/response/http_response.dart';
import 'package:ablumwin/user/provider/mine_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import 'package:path_provider/path_provider.dart';

import '../user/my_instance.dart';
import 'network.dart';


/// Generates a unique filename based on the URL and FormData parameters.
String generateCacheFileName(String url, dynamic data) {
  String paramString = '';
  if (data is FormData) {
    // Convert FormData fields to a sorted map for consistent ordering
    final fields = Map.fromEntries(data.fields)..removeWhere((k, v) => v == null);
    final sortedKeys = fields.keys.toList()..sort();
    for (var key in sortedKeys) {
      paramString += '$key=${fields[key]}&';
    }
    // If you want to include file names, you could add data.files info here as well
    for (var file in data.files) {
      paramString += '${file.key}=${file.value.filename}&';
    }
  } else if (data is Map) {
    final sortedKeys = data.keys.toList()..sort();
    for (var key in sortedKeys) {
      paramString += '$key=${data[key]}&';
    }
  }
  final baseString = '$url?$paramString';
  return baseString.toMd5();
}

Future<String> _getCacheFilePath(String url,  dynamic data) async {
      var groupId =   MyInstance().group?.groupId ?? -1;
    var userId = MyInstance().user?.user?.id ?? -1;
    if (groupId == -1 || userId == -1) {
      LogUtil.log("userId or groupId is invalid");
      return "";
    }
    
  final dir = await getApplicationDocumentsDirectory();
  // You can use a hash of the URL for more complex keys
  final fileName = generateCacheFileName(url, data);
  //dir not exist then create
  var dioDir = Directory("${dir.path}/diocache");
   if (!(await dioDir.exists())) {
          dioDir.create();
   }
  return '${dioDir.path}/dio_cache_${userId}_${groupId}_$fileName.json';
}

Future<ResponseModel<T>> requestAndConvertResponseModel<T>(String url,
    {formData,
    NetMethod netMethod = NetMethod.post,
    isUrlEncode = false,
    receiveTimeout = 15}) async {
  final filePath = await _getCacheFilePath(url ,formData);
  final file = File(filePath);

  final connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult.first == ConnectivityResult.none) {
    if (await file.exists()) {
      final cachedStr = await file.readAsString();
      final cachedData = json.decode(cachedStr);
      // Return a fake Response with the cached data
      return ResponseModel.fromJson(cachedData);
    }
  }

  HttpResponse<String> response = await sendRequest(url,
      formData: formData,
      netMethod: netMethod,
      isUrlEncode: isUrlEncode,
      receiveTimeout: receiveTimeout);
  ResponseModel<T> model;
  if (response.isHttpSuccess) {
    try {
      model = ResponseModel.fromJson(json.decode(response.data));
       if (file.path.isNotEmpty) {
         await file.writeAsString(response.data);
       }

      return model;
    } catch (e) {
      return ResponseModel(code: -1, message: "Json转换异常", model: null);
    }
  }

  if (await file.exists()) {
    final cachedStr = await file.readAsString();
    final cachedData = json.decode(cachedStr);
    // Return a fake Response with the cached data
    return ResponseModel.fromJson(cachedData);
  }

  return ResponseModel(
      code: response.statusCode, message: response.message, model: null);
}

Future<HttpResponse<String>> sendRequest(String url,
    {formData,
    NetMethod netMethod = NetMethod.post,
    isUrlEncode = false,
    receiveTimeout = 15}) async {
  try {
    var dio = Network.instance.getDio();

    dio.options.receiveTimeout = Duration(seconds: receiveTimeout);
    dynamic future;
    switch (netMethod) {
      case NetMethod.get:
        future = dio.get<String>(
          url,
          queryParameters: formData,
        );
        break;

      case NetMethod.delete:
        future = dio.delete<String>(url, data: formData);
        break;

      case NetMethod.put:
        future = dio.put<String>(url, data: formData);
        break;

      default: //默认给post请求
        if (isUrlEncode) {
          future = dio.post<String>(url, data: {}, queryParameters: formData);
          break;
        }
        future = dio.post<String>(url, data: formData);
        break;
    }
    Response response = await future;
    if (response.statusCode == 200) {
      if (url.contains("/nass/clound/common/p6Login")) {
        // 处理登录响应中的 Cookie
        var cookies = response.headers['set-cookie'];
        if (cookies != null && cookies.isNotEmpty) {
          MyInstance().setCookie(cookies.first.split(';').first);
        }
      }

      return HttpResponse(
          statusCode: 200, data: response.data ?? "", message: "");
    } else {
      return HttpResponse(
        statusCode: response.statusCode ?? -1,
        data: "",
        message: "网络异常，请稍后重试",
      );
    }
  } catch (e) {
    return HttpResponse(statusCode: -1, data: "", message: "网络异常，请稍后重试");
  }
}

enum NetMethod {
  get,
  post,
  delete,
  put,
}
