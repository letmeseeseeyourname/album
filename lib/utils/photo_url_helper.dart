// album/utils/photo_url_helper.dart
// 统一处理图片 URL 的工具类
// 解决不同场景下 URL 构建不一致的问题

import '../../../network/constant_sign.dart';

/// 图片 URL 辅助类
/// 统一处理 MinIO/P2P 图片 URL 的构建
class PhotoUrlHelper {
  /// 获取完整的图片 URL
  /// [path] 可能是：
  ///   1. 完整的 URL (http:// 或 https:// 开头)
  ///   2. 相对路径 (需要拼接 baseUrl)
  ///   3. null 或空字符串
  static String? getFullUrl(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }

    // 如果已经是完整 URL，直接返回
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    // 获取基础 URL
    final baseUrl = AppConfig.minio();

    // 确保 path 不以 / 开头（避免双斜杠）
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;

    // 确保 baseUrl 不以 / 结尾
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    return '$cleanBaseUrl/$cleanPath';
  }

  /// 获取缩略图 URL
  static String? getThumbnailUrl(String? thumbnailPath) {
    return getFullUrl(thumbnailPath);
  }

  /// 获取中等尺寸图片 URL
  static String? getMediumUrl(String? mediumPath) {
    return getFullUrl(mediumPath);
  }

  /// 获取原图 URL
  static String? getOriginUrl(String? originPath) {
    return getFullUrl(originPath);
  }

  /// 获取预览用的最佳 URL（优先高清）
  static String? getPreviewUrl({
    String? originPath,
    String? mediumPath,
    String? thumbnailPath,
  }) {
    // 优先使用原图，其次中等尺寸，最后缩略图
    return getFullUrl(originPath) ??
        getFullUrl(mediumPath) ??
        getFullUrl(thumbnailPath);
  }

  /// 获取网格/列表显示用的 URL（优先缩略图）
  static String? getGridUrl({
    String? thumbnailPath,
    String? mediumPath,
  }) {
    // 优先使用缩略图，其次中等尺寸
    return getFullUrl(thumbnailPath) ?? getFullUrl(mediumPath);
  }
}