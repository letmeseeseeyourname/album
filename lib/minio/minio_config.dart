// config/minio_config.dart
// Minio 对象存储配置

class MinioConfig {
  // Minio 服务器地址（不包含协议）
  static const String host = "127.0.0.1";

  // Minio 服务器端口
  static const int port = 9000;

  // 是否使用 SSL
  static const bool useSSL = false;

  // 访问密钥
  static const String accessKey = 'IPK4kCZVBeyjYSvPmGDa';
  static const String secretKey = 'ZKHULHBypLfLvpwJdGtuc8seAgO2ivVe4vcuhq5a';

  // 默认存储桶名称
  static const String defaultBucket = 'my-bucket';

  // 用户头像存储桶
  static const String avatarBucket = 'avatars';

  // 视频文件存储桶
  static const String videoBucket = 'videos';

  // 图片文件存储桶
  static const String imageBucket = 'images';

  // 完整的 endpoint（包含协议，用于生成 URL）
  static String get endpoint {
    final protocol = useSSL ? 'https' : 'http';
    return '$protocol://$host:$port';
  }

  // 文件 URL 前缀
  static String getFileUrl(String bucket, String objectName) {
    return '$endpoint/$bucket/$objectName';
  }

  // 获取完整的 Minio 地址（向后兼容）
  static String get fullEndpoint => endpoint;
}