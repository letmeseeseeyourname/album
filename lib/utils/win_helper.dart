import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';

class WinHelper {
  static String? _cachedUuid;

  static Future<String> uuid() async {
    if (_cachedUuid != null) return _cachedUuid!;

    final components = <String>[];

    // 1. 主板序列号
    final motherboard = await _runWmic('baseboard', 'serialnumber');
    if (motherboard.isNotEmpty) components.add(motherboard);

    // 2. BIOS 序列号
    final bios = await _runWmic('bios', 'serialnumber');
    if (bios.isNotEmpty) components.add(bios);

    // 3. CPU ID
    final cpu = await _runWmic('cpu', 'processorid');
    if (cpu.isNotEmpty) components.add(cpu);

    // 4. 硬盘序列号
    final disk = await _runWmic('diskdrive', 'serialnumber');
    if (disk.isNotEmpty) components.add(disk);


    // 组合并哈希
    final combined = components.join('|');
    final hash = md5.convert(utf8.encode(combined)).toString();
    _cachedUuid = 'device-win-${hash.substring(0, 20)}';

    return _cachedUuid!;
  }

  static Future<String> _runWmic(String alias, String property) async {
    try {
      final result = await Process.run(
        'wmic',
        [alias, 'get', property],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        if (lines.length >= 2) {
          return lines[1].trim();
        }
      }
    } catch (e) {
      print('WMIC 查询失败 ($alias): $e');
    }
    return '';
  }

  /// 获取设备型号
  static Future<String> getDeviceModel() async {
    try {
      // Windows 平台获取设备型号
      if (Platform.isWindows) {
        final result = await Process.run(
          'wmic',
          ['computersystem', 'get', 'model'],
          runInShell: true,
        );
        if (result.exitCode == 0) {
          final lines = result.stdout.toString().split('\n');
          if (lines.length >= 2) {
            return lines[1].trim();
          }
        }
      }
    } catch (e) {
      debugPrint('获取设备型号失败: $e');
    }
    return 'Windows PC';
  }

}