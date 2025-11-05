import 'package:json_annotation/json_annotation.dart';

import 'failed_file_list.dart';


part 'file_upload_response_model.g.dart';

@JsonSerializable()
class FileUploadResponseModel {
    final int? taskId;
    final String? uploadPath;
    final int? okCount;
    final int? failedCount;
    final List<FailedFileList>? failedFileList;

    const FileUploadResponseModel({
        required this.taskId,
        required this.uploadPath,
        required this.okCount,
        required this.failedCount,
        required this.failedFileList,
    });

    factory FileUploadResponseModel.fromJson(Map<String, dynamic> json) => _$FileUploadResponseModelFromJson(json);

    Map<String, dynamic> toJson() => _$FileUploadResponseModelToJson(this);

    FileUploadResponseModel copyWith({
        int? taskId,
        String? uploadPath,
        int? okCount,
        int? failedCount,
        List<FailedFileList>? failedFileList,
    }) {
        return FileUploadResponseModel(
            taskId: taskId ?? this.taskId,
            uploadPath: uploadPath ?? this.uploadPath,
            okCount: okCount ?? this.okCount,
            failedCount: failedCount ?? this.failedCount,
            failedFileList: failedFileList ?? this.failedFileList,
        );
    }
}

// Run this command to generate the required code:
// flutter pub run build_runner build --delete-conflicting-outputs
