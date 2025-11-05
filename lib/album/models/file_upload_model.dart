import 'package:json_annotation/json_annotation.dart';

part 'file_upload_model.g.dart';

@JsonSerializable()
class FileUploadModel {
    final String? fileCode;
    final String? filePath;
    final String? fileName;
    final String? fileType;
    final int? storageSpace;

    const FileUploadModel({
        required this.fileCode,
        required this.filePath,
        required this.fileName,
        required this.fileType,
        required this.storageSpace,
    });

    factory FileUploadModel.fromJson(Map<String, dynamic> json) => _$FileUploadModelFromJson(json);

    Map<String, dynamic> toJson() => _$FileUploadModelToJson(this);

    FileUploadModel copyWith({
        String? fileCode,
        String? filePath,
        String? fileName,
        String? fileType,
        int? storageSpace,
    }) {
        return FileUploadModel(
            fileCode: fileCode ?? this.fileCode,
            filePath: filePath ?? this.filePath,
            fileName: fileName ?? this.fileName,
            fileType: fileType ?? this.fileType,
            storageSpace: storageSpace ?? this.storageSpace,
        );
    }
}

// Run this command to generate the required code:
// flutter pub run build_runner build --delete-conflicting-outputs
