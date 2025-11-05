
import 'package:flutter/material.dart';

import '../../user/models/login_response_model.dart';
import '../../user/models/p6device_info_model.dart';
import '../../user/models/user.dart';
import '../../user/models/user_model.dart';

class ModelFactory {
  static T? generateOBJ<T>(json) {
    var type = T.toString();
    var dataType = json?.runtimeType.toString();
    if (type == dataType) return json;
    switch (type) {
      case "LoginResponseModel":
        return LoginResponseModel.fromJson(json) as T;
      case "UserModel":
        return UserModel.fromJson(json) as T;
      case "UserInfo":
        return UserInfo.fromJson(json) as T;
      case "User":
        return User.fromJson(json) as T;
      case "P6DeviceInfoModel":
        return P6DeviceInfoModel.fromJson(json) as T;
      default:
        if (type != 'dynamic') {
          debugPrint("************ 请注意 ************** 该类型解析失败了 $type");
        }

        return null;
    }
  }
}
