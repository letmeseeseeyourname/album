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


 static Future<String> getLocalIpAddress() async {
    try {
      // 1. 获取所有网络接口列表
      // includeLoopback: 是否包含回环地址 (127.0.0.1)
      // type: 限制只获取 IPv4 地址 (InternetAddress.IPv4)
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      // 2. 遍历所有接口和地址
      for (var interface in interfaces) {
        // 排除虚拟接口或非活动接口 (可选，提高准确性)
        // 在一些平台上，接口名称可能包含 'wlan', 'eth', 'en' 等
        // if (interface.name.startsWith('Wi-Fi') || interface.name.startsWith('Ethernet')) {

        for (var address in interface.addresses) {
          // 3. 检查地址是否为局域网地址 (非私有/回环地址)
          // 通常局域网 IP 是 192.168.x.x, 10.x.x.x, 172.16.x.x 等

          // 简单地返回找到的第一个非回环的 IPv4 地址
          if (address.type == InternetAddressType.IPv4) {
            return address.address;
          }
        }
      }

      // 如果没有找到有效的 IP 地址
      return '未找到有效 IP 地址';

    } catch (e) {
      debugPrint('获取 IP 地址失败: $e');
      return '获取 IP 地址出错';
    }
  }

}