

import 'package:flutter/material.dart';

import 'model_factory.dart';

class ResponseModel<T> {
  int code;
  String message;
  T? model;
  

  bool get isEmpty => code == -10101010;

  bool get isSuccess => (code == 0 || code == 200);

  bool get isNotSuccess => !isSuccess;

  ResponseModel({required this.code, required this.message, required this.model});

  factory ResponseModel.fromJson(Map<String, dynamic> json) {
    int code = json['code'];
     String message = "";
     try {
         message = json['msg'];
    } catch (e) {
        // debugPrint("msg 类型转换错误:${e}");
    }

    try {
         message = json['message'];
    } catch (e) {
        // debugPrint("message 类型转换错误:${e}");
    }


    T? model;
    try {
      final data = json['data'];

      // ✅ 特殊处理 bool 类型
      if (T == bool) {
        if (data is bool) {
          model = data as T;
        } else {
          // data 不是 bool（可能是 null、Map 等），根据 code 判断
          model = (code == 0 || code == 200) as T;
        }
      } else {
        model = ModelFactory.generateOBJ<T>(data ?? <String, dynamic>{});
      }
    } catch (e) {
      debugPrint("data 类型转换错误:$e");

      // ✅ 如果转换失败且 T 是 bool，使用 code 判断
      if (T == bool) {
        model = (code == 0 || code == 200) as T;
      }
    }
    return ResponseModel(code: code, message: message, model: model);
  }
}