// models/media_item.dart
// 统一的媒体项模型，支持本地文件和网络资源

enum MediaItemType {
  image,
  video,
}

enum MediaSourceType {
  local,   // 本地文件
  network, // 网络URL
}

class MediaItem {
  final String id;           // 唯一标识
  final String name;         // 文件名
  final MediaItemType type;  // 媒体类型
  final MediaSourceType sourceType; // 数据源类型

  // 路径/URL
  final String? localPath;      // 本地文件路径
  final String? networkUrl;     // 网络URL（通用）

  // 网络资源的多级质量路径
  final String? thumbnailPath;  // 缩略图路径
  final String? mediumPath;     // 中等质量路径
  final String? originPath;     // 原始质量路径

  // 元数据
  final int? fileSize;
  final int? duration;  // 视频时长（秒）
  final int? width;
  final int? height;
  final DateTime? photoDate;

  MediaItem({
    required this.id,
    required this.name,
    required this.type,
    required this.sourceType,
    this.localPath,
    this.networkUrl,
    this.thumbnailPath,
    this.mediumPath,
    this.originPath,
    this.fileSize,
    this.duration,
    this.width,
    this.height,
    this.photoDate,
  });

  // 获取实际的媒体路径/URL（用于基本展示）
  String getMediaSource() {
    if (sourceType == MediaSourceType.local) {
      return localPath ?? '';
    } else {
      // 网络资源：优先使用原始路径
      return originPath ?? mediumPath ?? networkUrl ?? '';
    }
  }

  // 获取高质量源（用于全屏查看）
  String getHighQualitySource() {
    if (sourceType == MediaSourceType.local) {
      return localPath ?? '';
    } else {
      // 网络资源：总是使用原始质量
      return originPath ?? networkUrl ?? '';
    }
  }

  // 获取中等质量源（用于预览）
  String getMediumQualitySource() {
    if (sourceType == MediaSourceType.local) {
      return localPath ?? '';
    } else {
      // 网络资源：使用中等质量
      return mediumPath ?? originPath ?? networkUrl ?? '';
    }
  }

  // 获取缩略图路径/URL
  String getThumbnailSource() {
    if (sourceType == MediaSourceType.local) {
      return localPath ?? '';
    } else {
      // 网络资源：使用缩略图
      return thumbnailPath ?? mediumPath ?? networkUrl ?? '';
    }
  }

  // 从本地FileItem创建
  static MediaItem fromFileItem(dynamic fileItem) {
    return MediaItem(
      id: fileItem.path,
      name: fileItem.name,
      type: fileItem.type.toString().contains('image')
          ? MediaItemType.image
          : MediaItemType.video,
      sourceType: MediaSourceType.local,
      localPath: fileItem.path,
      fileSize: fileItem.size,
    );
  }

  // 从网络ResList创建
  static MediaItem fromResList(dynamic resList) {
    return MediaItem(
      id: resList.resId ?? '',
      name: resList.fileName ?? 'Unknown',
      type: resList.fileType == 'V' ? MediaItemType.video : MediaItemType.image,
      sourceType: MediaSourceType.network,
      // 存储完整的路径层级
      thumbnailPath: resList.thumbnailPath,
      mediumPath: resList.mediumPath,
      originPath: resList.originPath,
      // networkUrl 作为备用
      networkUrl: resList.originPath ?? resList.mediumPath,
      // 元数据
      fileSize: resList.fileSize,
      duration: resList.duration,
      width: resList.width,
      height: resList.height,
      photoDate: resList.photoDate,
    );
  }

  // 调试用：打印媒体信息
  @override
  String toString() {
    return 'MediaItem(id: $id, name: $name, type: $type, sourceType: $sourceType, '
        'originPath: $originPath, mediumPath: $mediumPath)';
  }
}