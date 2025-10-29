import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'login_response_model.g.dart';

@JsonSerializable()
class LoginResponseModel {
  String? accessToken;
  final String? refreshToken;
  final String? tokenType;
  final int? expiresIn;
  User? user;
  final dynamic groupDeviceUser;
  final int? groupMemberCount;
  final String? p2pUsername;
  final List<dynamic>? mgroupDeviceUsers;
  final bool? firstLogin;

  LoginResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
    this.groupDeviceUser,
    required this.groupMemberCount,
    required this.p2pUsername,
    required this.mgroupDeviceUsers,
    required this.firstLogin,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseModelFromJson(json);

  Map<String, dynamic> toJson() => _$LoginResponseModelToJson(this);

  LoginResponseModel copyWith({
    String? accessToken,
    String? refreshToken,
    String? tokenType,
    int? expiresIn,
    User? user,
    dynamic groupDeviceUser,
    int? groupMemberCount,
    String? p2pUsername,
    List<dynamic>? mgroupDeviceUsers,
    bool? firstLogin,
  }) {
    return LoginResponseModel(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenType: tokenType ?? this.tokenType,
      expiresIn: expiresIn ?? this.expiresIn,
      user: user ?? this.user,
      groupDeviceUser: groupDeviceUser ?? this.groupDeviceUser,
      groupMemberCount: groupMemberCount ?? this.groupMemberCount,
      p2pUsername: p2pUsername ?? this.p2pUsername,
      mgroupDeviceUsers: mgroupDeviceUsers ?? this.mgroupDeviceUsers,
      firstLogin: firstLogin ?? this.firstLogin,
    );
  }
}

// Run this command to generate the required code:
// flutter pub run build_runner build --delete-conflicting-outputs
