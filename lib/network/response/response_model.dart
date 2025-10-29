

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
      model = ModelFactory.generateOBJ<T>(
          json['data'] ?? <String, dynamic>{});
    } catch (e) {
        debugPrint("data 类型转换错误:${e}");
    }
    return ResponseModel(code: code, message: message, model: model);
  }
}