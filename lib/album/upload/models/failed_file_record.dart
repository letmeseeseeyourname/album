import '../../manager/local_folder_upload_manager.dart';
import 'local_file_info.dart';

/// 失败文件记录
class FailedFileRecord {
  final LocalFileInfo fileInfo;
  final String md5Hash;
  final String? errorMessage;
  int retryCount;

  FailedFileRecord({
    required this.fileInfo,
    required this.md5Hash,
    this.errorMessage,
    this.retryCount = 0,
  });

  MapEntry<LocalFileInfo, String> toEntry() => MapEntry(fileInfo, md5Hash);
}