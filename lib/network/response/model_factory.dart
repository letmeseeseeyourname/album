import 'package:flutter/material.dart';

import '../../album/models/file_upload_response_model.dart';
import '../../user/models/device_model.dart';
import '../../user/models/login_response_model.dart';
import '../../user/models/my_all_groups_model.dart';
import '../../user/models/p6device_info_model.dart';
import '../../user/models/qr_code_model.dart';
import '../../user/models/resource_list_model.dart';
import '../../user/models/user.dart';
import '../../user/models/user_model.dart';

class ModelFactory {
  static T? generateOBJ<T>(json) {
    var type = T.toString();
    var dataType = json?.runtimeType.toString();
    // 直接返回原始类型（int、double、String、bool等）
    if (json == null) return null;

    if (T == int ||
        T == double ||
        T == num ||
        T == String ||
        T == bool ||
        T == dynamic) {
      return json as T;
    }
    if (type == dataType) return json;
    switch (type) {
      case "ResourceListModel":
        return ResourceListModel.fromJson(json) as T;
      case "LoginResponseModel":
        return LoginResponseModel.fromJson(json) as T;
      case "UserModel":
        return UserModel.fromJson(json) as T;
      case "QrCodeModel":
        return QrCodeModel.fromJson(json) as T;
      case "UserInfo":
        return UserInfo.fromJson(json) as T;
      case "User":
        return User.fromJson(json) as T;
      case "DeviceModel":
        return DeviceModel.fromJson(json) as T;
      case "P6DeviceInfoModel":
        return P6DeviceInfoModel.fromJson(json) as T;
      case "FileUploadResponseModel":
        return FileUploadResponseModel.fromJson(json) as T;
      case "MyAllGroupsModel":
        return MyAllGroupsModel.fromJson(json) as T;
      default:
        if (type != 'dynamic') {
          debugPrint("************ 请注意 ************** 该类型解析失败了 $type");
        }
        return null;
    }
  }
}
