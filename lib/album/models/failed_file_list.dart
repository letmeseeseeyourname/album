import 'package:json_annotation/json_annotation.dart';

part 'failed_file_list.g.dart';

@JsonSerializable()
class FailedFileList {
    final String? fileCode;
    final String? failedReason;

    const FailedFileList({
        required this.fileCode,
        required this.failedReason,
    });

    factory FailedFileList.fromJson(Map<String, dynamic> json) => _$FailedFileListFromJson(json);

    Map<String, dynamic> toJson() => _$FailedFileListToJson(this);

    FailedFileList copyWith({
        String? fileCode,
        String? failedReason,
    }) {
        return FailedFileList(
            fileCode: fileCode ?? this.fileCode,
            failedReason: failedReason ?? this.failedReason,
        );
    }
}

// Run this command to generate the required code:
// flutter pub run build_runner build --delete-conflicting-outputs
