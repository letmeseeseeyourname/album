import 'package:json_annotation/json_annotation.dart';

part 'qr_code_model.g.dart';

@JsonSerializable()
class QrCodeModel {
  final String? qrCode;
  final String? token;

  const QrCodeModel({
    this.qrCode,
    this.token,
  });

  factory QrCodeModel.fromJson(Map<String, dynamic> json) => _$QrCodeModelFromJson(json);

  Map<String, dynamic> toJson() => _$QrCodeModelToJson(this);
}