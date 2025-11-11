// utils/video_debug_helper.dart
// 网络视频播放调试辅助工具

import 'dart:io';
import 'package:http/http.dart' as http;

class VideoDebugHelper {
  /// 检查视频 URL 是否可访问
  static Future<VideoUrlCheckResult> checkVideoUrl(String url) async {
    try {
      print('🔍 检查视频 URL: $url');

      final uri = Uri.parse(url);

      // 1. 检查 URL 格式
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return VideoUrlCheckResult(
          isValid: false,
          error: 'URL 格式错误：缺少 http:// 或 https:// 协议',
          suggestion: '确保 URL 包含完整的协议头',
        );
      }

      // 2. 检查主机名
      if (uri.host.isEmpty) {
        return VideoUrlCheckResult(
          isValid: false,
          error: 'URL 格式错误：缺少主机名',
          suggestion: '确保 URL 包含域名或 IP 地址',
        );
      }

      // 3. 发送 HEAD 请求检查资源是否存在
      print('📡 发送 HEAD 请求...');
      final response = await http.head(uri).timeout(
        const Duration(seconds: 10),
      );

      print('📊 响应状态码: ${response.statusCode}');
      print('📋 响应头:');
      response.headers.forEach((key, value) {
        print('  $key: $value');
      });

      // 4. 检查响应状态
      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';
        final contentLength = response.headers['content-length'];

        // 5. 检查内容类型
        if (!contentType.contains('video')) {
          return VideoUrlCheckResult(
            isValid: false,
            error: '内容类型错误：$contentType (应该是 video/*)',
            suggestion: '这个 URL 指向的不是视频文件',
            statusCode: response.statusCode,
            contentType: contentType,
            contentLength: contentLength != null ? int.tryParse(contentLength) : null,
          );
        }

        return VideoUrlCheckResult(
          isValid: true,
          message: '✅ 视频 URL 有效',
          statusCode: response.statusCode,
          contentType: contentType,
          contentLength: contentLength != null ? int.tryParse(contentLength) : null,
          headers: response.headers,
        );
      } else if (response.statusCode == 401) {
        return VideoUrlCheckResult(
          isValid: false,
          error: '认证失败 (401)',
          suggestion: '需要登录凭证或访问令牌',
          statusCode: response.statusCode,
        );
      } else if (response.statusCode == 403) {
        return VideoUrlCheckResult(
          isValid: false,
          error: '访问被拒绝 (403)',
          suggestion: '没有权限访问此资源',
          statusCode: response.statusCode,
        );
      } else if (response.statusCode == 404) {
        return VideoUrlCheckResult(
          isValid: false,
          error: '资源不存在 (404)',
          suggestion: '检查 URL 是否正确，资源是否已被删除',
          statusCode: response.statusCode,
        );
      } else {
        return VideoUrlCheckResult(
          isValid: false,
          error: '服务器错误 (${response.statusCode})',
          suggestion: '服务器返回异常状态码',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      return VideoUrlCheckResult(
        isValid: false,
        error: '网络连接失败',
        suggestion: '检查网络连接或服务器地址是否正确\n详情: ${e.message}',
      );
    } on http.ClientException catch (e) {
      return VideoUrlCheckResult(
        isValid: false,
        error: 'HTTP 请求失败',
        suggestion: '无法连接到服务器\n详情: ${e.message}',
      );
    } catch (e) {
      return VideoUrlCheckResult(
        isValid: false,
        error: '未知错误',
        suggestion: '检查 URL 格式和网络连接\n详情: $e',
      );
    }
  }

  /// 获取视频格式信息
  static String getVideoFormatFromUrl(String url) {
    final uri = Uri.parse(url);
    final path = uri.path.toLowerCase();

    if (path.endsWith('.mp4')) return 'MP4';
    if (path.endsWith('.webm')) return 'WebM';
    if (path.endsWith('.mkv')) return 'MKV';
    if (path.endsWith('.mov')) return 'MOV';
    if (path.endsWith('.avi')) return 'AVI';
    if (path.endsWith('.flv')) return 'FLV';

    return '未知';
  }

  /// 检查视频格式是否受支持
  static bool isVideoFormatSupported(String url) {
    final format = getVideoFormatFromUrl(url);
    // media_kit 主要支持 MP4, WebM, MKV
    return ['MP4', 'WEBM', 'MKV'].contains(format);
  }

  /// 生成完整的视频 URL
  static String buildFullVideoUrl(String baseUrl, String path) {
    // 移除 baseUrl 末尾的斜杠
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    // 确保 path 以斜杠开头
    final cleanPath = path.startsWith('/') ? path : '/$path';

    final fullUrl = '$cleanBaseUrl$cleanPath';

    print('🔧 URL 构建:');
    print('  Base URL: $baseUrl');
    print('  Path: $path');
    print('  Full URL: $fullUrl');

    return fullUrl;
  }

  /// 格式化文件大小
  static String formatFileSize(int? bytes) {
    if (bytes == null) return '未知';

    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}

/// 视频 URL 检查结果
class VideoUrlCheckResult {
  final bool isValid;
  final String? message;
  final String? error;
  final String? suggestion;
  final int? statusCode;
  final String? contentType;
  final int? contentLength;
  final Map<String, String>? headers;

  VideoUrlCheckResult({
    required this.isValid,
    this.message,
    this.error,
    this.suggestion,
    this.statusCode,
    this.contentType,
    this.contentLength,
    this.headers,
  });

  /// 生成详细报告
  String generateReport() {
    final buffer = StringBuffer();

    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('       视频 URL 检查报告');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln();

    if (isValid) {
      buffer.writeln('✅ 状态: 有效');
      if (message != null) {
        buffer.writeln('📝 消息: $message');
      }
    } else {
      buffer.writeln('❌ 状态: 无效');
      if (error != null) {
        buffer.writeln('❌ 错误: $error');
      }
      if (suggestion != null) {
        buffer.writeln('💡 建议: $suggestion');
      }
    }

    buffer.writeln();
    buffer.writeln('───────────────────────────────────────');
    buffer.writeln('       详细信息');
    buffer.writeln('───────────────────────────────────────');

    if (statusCode != null) {
      buffer.writeln('📊 状态码: $statusCode');
    }

    if (contentType != null) {
      buffer.writeln('📄 内容类型: $contentType');
    }

    if (contentLength != null) {
      buffer.writeln('📦 文件大小: ${VideoDebugHelper.formatFileSize(contentLength)}');
    }

    if (headers != null && headers!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('📋 响应头:');
      headers!.forEach((key, value) {
        buffer.writeln('  • $key: $value');
      });
    }

    buffer.writeln('═══════════════════════════════════════');

    return buffer.toString();
  }
}

/// 使用示例
///
/// ```dart
/// // 1. 检查视频 URL
/// final result = await VideoDebugHelper.checkVideoUrl(videoUrl);
/// print(result.generateReport());
///
/// // 2. 在 initState 中使用
/// @override
/// void initState() {
///   super.initState();
///   _checkVideoUrlBeforePlay();
/// }
///
/// Future<void> _checkVideoUrlBeforePlay() async {
///   final item = widget.mediaItems[currentIndex];
///   final url = item.getMediaSource();
///
///   final result = await VideoDebugHelper.checkVideoUrl(url);
///
///   if (!result.isValid) {
///     print('⚠️ 视频 URL 检查失败');
///     print(result.generateReport());
///
///     // 显示错误给用户
///     if (mounted) {
///       ScaffoldMessenger.of(context).showSnackBar(
///         SnackBar(
///           content: Text(result.error ?? '视频 URL 无效'),
///           backgroundColor: Colors.red,
///         ),
///       );
///     }
///   } else {
///     print('✅ 视频 URL 有效，准备播放');
///     _initializeVideo(url);
///   }
/// }
/// ```