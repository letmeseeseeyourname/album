/// 上传配置
class LocalUploadConfig {
  static const int maxConcurrentUploads = 5;
  static const int imageChunkSize = 10;
  static const int videoChunkSize = 1;
  static const int maxRetryAttempts = 5;       // 单文件最大重试次数
  static const int maxRetryRounds = 10;         // 失败队列最大重试轮次
  static const int retryDelaySeconds = 2;
  static const int retryRoundDelaySeconds = 5; // 每轮重试前的等待时间
  static const double reservedStorageGB = 8.0;
  static const int md5ReadSizeBytes = 1024 * 1024;
  static const int thumbnailWidth = 300;
  static const int thumbnailHeight = 300;
  static const int thumbnailQuality = 35;
  static const int mediumWidth = 1080;
  static const int mediumHeight = 1920;
  static const int mediumQuality = 75;
}