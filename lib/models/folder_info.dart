// models/folder_info.dart
class FolderInfo {
  final String name;
  final String path;
  final int imageCount;
  final int videoCount;

  FolderInfo({
    required this.name,
    required this.path,
    required this.imageCount,
    required this.videoCount,
  });
}