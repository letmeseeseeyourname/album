import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  final int? id;
  String? nickName;
  String? mobile;
  dynamic email;
  final String? password;
  final dynamic configCodeId;
  String? birthDate;
  String? sex;
  String? countryCode;
  String? provinceCode;
  String? cityCode;
  String? districtCode;
  String? address;
  final dynamic? headUrl;
  final String? createdDate;
  final String? updatedDate;
  final dynamic? createdBy;
  final dynamic? updatedBy;
  final dynamic? deletedFlag;
  final String? username;
  final int? status;
  final bool? enabled;
  final List<dynamic>? authorities;
  final bool? accountNonExpired;
  final bool? accountNonLocked;
  final bool? credentialsNonExpired;

  User({
    required this.id,
    this.nickName,
    required this.mobile,
    this.email,
    required this.password,
    this.configCodeId,
    this.birthDate,
    this.sex,
    this.countryCode,
    this.provinceCode,
    this.cityCode,
    this.districtCode,
    this.address,
    this.headUrl,
    required this.createdDate,
    required this.updatedDate,
    this.createdBy,
    this.updatedBy,
    this.deletedFlag,
    required this.username,
    required this.status,
    required this.enabled,
    required this.authorities,
    required this.accountNonExpired,
    required this.accountNonLocked,
    required this.credentialsNonExpired,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    int? id,
    dynamic? nickName,
    String? mobile,
    dynamic? email,
    String? password,
    dynamic? configCodeId,
    dynamic? birthDate,
    dynamic? sex,
    dynamic? countryCode,
    dynamic? provinceCode,
    dynamic? cityCode,
    dynamic? districtCode,
    dynamic? address,
    dynamic? headUrl,
    String? createdDate,
    String? updatedDate,
    dynamic? createdBy,
    dynamic? updatedBy,
    dynamic? deletedFlag,
    String? username,
    int? status,
    bool? enabled,
    List<dynamic>? authorities,
    bool? accountNonExpired,
    bool? accountNonLocked,
    bool? credentialsNonExpired,
  }) {
    return User(
      id: id ?? this.id,
      nickName: nickName ?? this.nickName,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      password: password ?? this.password,
      configCodeId: configCodeId ?? this.configCodeId,
      birthDate: birthDate ?? this.birthDate,
      sex: sex ?? this.sex,
      countryCode: countryCode ?? this.countryCode,
      provinceCode: provinceCode ?? this.provinceCode,
      cityCode: cityCode ?? this.cityCode,
      districtCode: districtCode ?? this.districtCode,
      address: address ?? this.address,
      headUrl: headUrl ?? this.headUrl,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      deletedFlag: deletedFlag ?? this.deletedFlag,
      username: username ?? this.username,
      status: status ?? this.status,
      enabled: enabled ?? this.enabled,
      authorities: authorities ?? this.authorities,
      accountNonExpired: accountNonExpired ?? this.accountNonExpired,
      accountNonLocked: accountNonLocked ?? this.accountNonLocked,
      credentialsNonExpired:
          credentialsNonExpired ?? this.credentialsNonExpired,
    );
  }
}

// Run this command to generate the required code:
// flutter pub run build_runner build --delete-conflicting-outputs
