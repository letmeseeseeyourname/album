


import '../../models/local_file_item.dart';

/// 文件类型枚举
enum LocalFileType { image, video, unknown }

/// 本地文件信息
class LocalFileInfo {
  final String filePath;
  final String fileName;
  final LocalFileType fileType;
  final int fileSize;
  final DateTime createTime;

  LocalFileInfo({
    required this.filePath,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.createTime,
  });

  /// 转换为 FileItem（用于数据库存储）
  FileItem toFileItem(String userId, String deviceCode, String md5Hash) {
    return FileItem(
      md5Hash: md5Hash,
      filePath: filePath,
      fileName: fileName,
      fileType: fileType == LocalFileType.image ? "P" : "V",
      fileSize: fileSize,
      assetId: md5Hash,
      status: 0,
      userId: userId,
      deviceCode: deviceCode,
      duration: 0,
      width: 0,
      height: 0,
      lng: 0.0,
      lat: 0.0,
      createDate: createTime.millisecondsSinceEpoch.toDouble(),
    );
  }
}