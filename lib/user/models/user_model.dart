import 'package:json_annotation/json_annotation.dart';
part 'user_model.g.dart';

@JsonSerializable()
class UserModel extends Object {
  @JsonKey(name: 'userInfo')
  UserInfo userInfo;

  @JsonKey(name: 'json')
  String json;

  @JsonKey(name: 'regFlag')
  int regFlag;

  UserModel(
    this.userInfo,
    this.json,
    this.regFlag,
  );

  factory UserModel.fromJson(Map<String, dynamic> srcJson) =>
      _$UserModelFromJson(srcJson);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}

@JsonSerializable()
class UserInfo extends Object {
  @JsonKey(name: 'userId')
  int userId;

  @JsonKey(name: 'nickName')
  String nickName;

  @JsonKey(name: 'mobile')
  String mobile;

  @JsonKey(name: 'email')
  String email;

  @JsonKey(name: 'password')
  String password;

  @JsonKey(name: 'configCodeId')
  int configCodeId;

  @JsonKey(name: 'birthDate')
  String birthDate;

  @JsonKey(name: 'sex')
  String sex;

  @JsonKey(name: 'countryCode')
  String countryCode;

  @JsonKey(name: 'countryName')
  String countryName;

  @JsonKey(name: 'provinceCode')
  String provinceCode;

  @JsonKey(name: 'provinceName')
  String provinceName;

  @JsonKey(name: 'cityCode')
  String cityCode;

  @JsonKey(name: 'cityName')
  String cityName;

  @JsonKey(name: 'districtCode')
  String districtCode;

  @JsonKey(name: 'districtName')
  String districtName;

  @JsonKey(name: 'address')
  String address;

  @JsonKey(name: 'headUrl')
  String headUrl;

  @JsonKey(name: 'createdDate')
  String createdDate;

  @JsonKey(name: 'updatedDate')
  String updatedDate;

  @JsonKey(name: 'roleId')
  int roleId;

  @JsonKey(name: 'roleName')
  String roleName;

  UserInfo(
    this.userId,
    this.nickName,
    this.mobile,
    this.email,
    this.password,
    this.configCodeId,
    this.birthDate,
    this.sex,
    this.countryCode,
    this.countryName,
    this.provinceCode,
    this.provinceName,
    this.cityCode,
    this.cityName,
    this.districtCode,
    this.districtName,
    this.address,
    this.headUrl,
    this.createdDate,
    this.updatedDate,
    this.roleId,
    this.roleName,
  );

  factory UserInfo.fromJson(Map<String, dynamic> srcJson) =>
      _$UserInfoFromJson(srcJson);

  Map<String, dynamic> toJson() => _$UserInfoToJson(this);
}
