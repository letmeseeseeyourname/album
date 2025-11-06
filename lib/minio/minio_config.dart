// config/minio_config.dart
// Minio 对象存储配置

import '../network/constant_sign.dart';

class MinioConfig {
  // Minio 服务器地址（假设与应用服务器在同一台机器）
  static const String endpoint = 'http://192.168.3.236:9000';

  // 是否使用 SSL
  static const bool useSSL = false;

  // 访问密钥
  static const String accessKey = 'IPK4kCZVBeyjYSvPmGDa';  // 默认用户名
  static const String secretKey = 'ZKHULHBypLfLvpwJdGtuc8seAgO2ivVe4vcuhq5a';  // 默认密码

  // 默认存储桶名称
  static const String defaultBucket = 'my-bucket';

  // 用户头像存储桶
  static const String avatarBucket = 'avatars';

  // 视频文件存储桶
  static const String videoBucket = 'videos';

  // 图片文件存储桶
  static const String imageBucket = 'images';

  // 文件 URL 前缀
  static String getFileUrl(String bucket, String objectName) {
    final protocol = useSSL ? 'https' : 'http';
    return '$protocol://$endpoint/$bucket/$objectName';
  }

  // 获取完整的 Minio 地址
  static String get fullEndpoint {
    final protocol = useSSL ? 'https' : 'http';
    return '$protocol://$endpoint';
  }
}