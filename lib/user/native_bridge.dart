import 'dart:io';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('remote_album/native');

  static Future<bool> startp2p(String account) async {
    // await closep2p();
    final bool result = await _channel.invokeMethod('startp2p', {
      // 'server': server,
      'account': account,
    });
    return result;
  }

  static Future<String> uuid() async {
  // Windows/Linux/macOS 平台使用固定值或生成值
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // 方案1: 使用固定的测试值（仅用于开发测试）
      // return 'desktop-test-uuid-${Platform.operatingSystem}';

      // 方案2: 基于时间戳生成（每次运行都不同，不推荐）
      // return 'device-${DateTime.now().millisecondsSinceEpoch}';

      // 方案3: 基于主机名（需要导入 dart:io）
      return 'device-win-${Uuid().v4()}';
    }

    // Android/iOS 平台调用原生方法


    final String result = await _channel.invokeMethod('uuid');
    return result;
  }

  static Future<bool> minio_upload(
      String localFile, String bucketName, String objectKey) async {
    try {
      final bool result = await _channel.invokeMethod('minio_upload', {
        'bucketName': bucketName,
        'objectKey': objectKey,
        "localFile": localFile,
      });
      return result;
    } on PlatformException catch (e) {
      print("Error: ${e.message}");
      rethrow;
    }
  }
}
