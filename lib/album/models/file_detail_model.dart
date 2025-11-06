import 'package:json_annotation/json_annotation.dart';

part 'file_detail_model.g.dart';

@JsonSerializable()
class FileDetailModel {
    final String? fileCode;
    final String? metaPath;
    final String? middlePath;
    final String? snailPath;
    final String? fileName;
    final String? fileType;
    final int? duration;
    final int? width;
    final int? height;
    final int? size;
    final String? fmt;
    final String? photoDate;
    final String? latitude;
    final String? longitude;

    const FileDetailModel({
        required this.fileCode,
        required this.metaPath,
        required this.middlePath,
        required this.snailPath,
        required this.fileName,
        required this.fileType,
        required this.duration,
        required this.width,
        required this.height,
        required this.size,
        required this.fmt,
        required this.photoDate,
        required this.latitude,
        required this.longitude,
    });

    factory FileDetailModel.fromJson(Map<String, dynamic> json) => _$FileDetailModelFromJson(json);

    Map<String, dynamic> toJson() => _$FileDetailModelToJson(this);

    FileDetailModel copyWith({
        String? fileCode,
        String? metaPath,
        String? middlePath,
        String? snailPath,
        String? fileName,
        String? fileType,
        int? duration,
        int? width,
        int? height,
        int? size,
        String? fmt,
        String? photoDate,
        String? latitude,
        String? longitude,
    }) {
        return FileDetailModel(
            fileCode: fileCode ?? this.fileCode,
            metaPath: metaPath ?? this.metaPath,
            middlePath: middlePath ?? this.middlePath,
            snailPath: snailPath ?? this.snailPath,
            fileName: fileName ?? this.fileName,
            fileType: fileType ?? this.fileType,
            duration: duration ?? this.duration,
            width: width ?? this.width,
            height: height ?? this.height,
            size: size ?? this.size,
            fmt: fmt ?? this.fmt,
            photoDate: photoDate ?? this.photoDate,
            latitude: latitude ?? this.latitude,
            longitude: longitude ?? this.longitude,
        );
    }
}

// Run this command to generate the required code:
// flutter pub run build_runner build --delete-conflicting-outputs
