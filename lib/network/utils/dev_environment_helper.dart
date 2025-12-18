import 'dart:async';
import 'dart:io';

import 'package:ablumwin/minio/minio_config.dart';
import 'package:ablumwin/minio/minio_service.dart';
import 'package:flutter/cupertino.dart';

import '../../eventbus/event_bus.dart';
import '../../minio/mc_service.dart';
import '../constant_sign.dart';

class EnvironmentResetEvent {
  /// 最终使用的 IP 地址
  final String usedIP;

  /// 是否使用的是主 IP (targetIP1)
  final bool isPrimaryIP;

  EnvironmentResetEvent({
    required this.usedIP,
    required this.isPrimaryIP,
  });
}

class DevEnvironmentHelper {

  /// 重置环境
  /// [targetIP1] 目标IP地址1
  /// [targetIP2] 目标IP地址2
  /// 如果targetIP1和本机处于同一局域网，且checkServerPorts8080And9000(targetIP1)可用则将AppConfig.usedIP设置为targetIP1
  /// 否则将AppConfig.usedIP设置为targetIP2
  Future<void> resetEnvironment(String targetIP1, {
    String targetIP2 = '127.0.0.1',
    Duration timeout = const Duration(seconds: 5),
    bool requireBothPorts = true,
  }) async {
    debugPrint('========== 开始重置环境 ==========');
    debugPrint('目标IP1: $targetIP1');
    debugPrint('目标IP2: $targetIP2');

    // 步骤1: 检测targetIP1是否与本机在同一局域网
    debugPrint('步骤1: 检测 $targetIP1 是否在局域网内...');
    final isInLAN = await isLAN(targetIP1);
    debugPrint('局域网检测结果: ${isInLAN ? "是" : "否"}');

    if (!isInLAN) {
      // 不在同一局域网，直接使用targetIP2
      debugPrint('$targetIP1 不在局域网内，使用备用IP: $targetIP2');
      AppConfig.usedIP = targetIP2;
      // MinioService.instance.reInitializeMinio(targetIP2);
      // McService.instance.reconfigure(
      //     endpoint: 'http://$targetIP2:9000',
      //     accessKey: MinioConfig.accessKey,
      //     secretKey: MinioConfig.secretKey);
      // await McService.instance.initialize();
    }

    // 步骤2: 检测targetIP1的8080和9000端口是否可用
    debugPrint('步骤2: 检测 $targetIP1 的端口可用性...');
    final serverCheck = await checkServerPorts8080And9000(
      targetIP1,
      timeout: timeout,
    );

    // 判断端口是否可用
    final isPortsAvailable = requireBothPorts
        ? serverCheck.isAllAccessible
        : serverCheck.isAnyAccessible;

    debugPrint('端口检测结果: ${isPortsAvailable ? "可用" : "不可用"}');
    debugPrint(
        '  - 8080端口: ${serverCheck.is8080Accessible ? "可用" : "不可用"}');
    debugPrint(
        '  - 9000端口: ${serverCheck.is9000Accessible ? "可用" : "不可用"}');

    if (isPortsAvailable) {
      // 局域网内且端口可用，使用targetIP1
      debugPrint('环境检测通过，使用主IP: $targetIP1');
      AppConfig.usedIP = targetIP1;
    } else {
      // 端口不可用，使用targetIP2
      debugPrint('端口不可用，使用备用IP: $targetIP2');
      AppConfig.usedIP = targetIP2;

      String reason;
      if (!serverCheck.is8080Accessible && !serverCheck.is9000Accessible) {
        reason = '8080和9000端口均不可用';
      } else if (!serverCheck.is8080Accessible) {
        reason = '8080端口不可用';
      } else {
        reason = '9000端口不可用';
      }
      debugPrint('端口不可用，reason: $reason');
    }
    MinioService.instance.reInitializeMinio(AppConfig.usedIP);
    McService.instance.reconfigure(
        endpoint: 'http://${AppConfig.usedIP}:9000',
        accessKey: MinioConfig.accessKey,
        secretKey: MinioConfig.secretKey);
    await McService.instance.initialize();

    MCEventBus.fire(EnvironmentResetEvent(
      usedIP: AppConfig.usedIP,
      isPrimaryIP: AppConfig.usedIP.contains("127.0.0.1"),
    ));
  }

  /// 判断目标IP是否与本机在同一局域网内
  ///
  /// [targetIP] 目标IP地址
  /// [subnetMask] 子网掩码，默认为 255.255.255.0 (即 /24)
  ///
  /// 返回 true 表示在同一局域网，false 表示不在
  Future<bool> isLAN(String targetIP,
      {String subnetMask = '255.255.255.0'}) async {
    try {
      // 验证目标IP格式
      if (!_isValidIPv4(targetIP)) {
        debugPrint('无效的目标IP地址: $targetIP');
        return false;
      }

      // 获取本机所有IPv4地址
      final localAddresses = await getAllLocalIPv4Addresses();
      if (localAddresses.isEmpty) {
        debugPrint('未找到本机IP地址');
        return false;
      }

      debugPrint('本机IP地址列表: $localAddresses');
      debugPrint('目标IP: $targetIP');

      // 检查目标IP是否就是本机IP
      if (localAddresses.contains(targetIP)) {
        debugPrint('目标IP是本机地址');
        return true;
      }

      // 检查是否为回环地址
      if (_isLoopback(targetIP)) {
        debugPrint('目标IP是回环地址');
        return true;
      }

      // 检查目标IP是否与任一本机IP在同一子网
      for (final localIP in localAddresses) {
        if (_isSameSubnet(localIP, targetIP, subnetMask)) {
          debugPrint(
              '$targetIP 与本机 $localIP 在同一子网 (掩码: $subnetMask)');
          return true;
        }
      }

      debugPrint('$targetIP 不在本机局域网内');
      return false;
    } catch (e) {
      debugPrint('判断局域网失败: $e');
      return false;
    }
  }

  /// 判断目标IP是否为私有地址（局域网地址范围）
  ///
  /// 私有IP范围:
  /// - 10.0.0.0 ~ 10.255.255.255 (A类)
  /// - 172.16.0.0 ~ 172.31.255.255 (B类)
  /// - 192.168.0.0 ~ 192.168.255.255 (C类)
  bool isPrivateIP(String ip) {
    if (!_isValidIPv4(ip)) return false;

    final parts = ip.split('.').map(int.parse).toList();

    // 10.x.x.x
    if (parts[0] == 10) return true;

    // 172.16.x.x ~ 172.31.x.x
    if (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) return true;

    // 192.168.x.x
    if (parts[0] == 192 && parts[1] == 168) return true;

    return false;
  }

  /// 判断是否为回环地址
  bool _isLoopback(String ip) {
    return ip.startsWith('127.');
  }

  /// 判断是否为链路本地地址 (169.254.x.x)
  bool isLinkLocal(String ip) {
    if (!_isValidIPv4(ip)) return false;
    final parts = ip.split('.').map(int.parse).toList();
    return parts[0] == 169 && parts[1] == 254;
  }

  /// 验证IPv4地址格式
  bool _isValidIPv4(String ip) {
    final regex = RegExp(
        r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
    );
    return regex.hasMatch(ip);
  }

  /// 判断两个IP是否在同一子网
  bool _isSameSubnet(String ip1, String ip2, String subnetMask) {
    try {
      final ip1Parts = ip1.split('.').map(int.parse).toList();
      final ip2Parts = ip2.split('.').map(int.parse).toList();
      final maskParts = subnetMask.split('.').map(int.parse).toList();

      for (int i = 0; i < 4; i++) {
        if ((ip1Parts[i] & maskParts[i]) != (ip2Parts[i] & maskParts[i])) {
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('子网比较失败: $e');
      return false;
    }
  }

  /// 根据CIDR前缀长度生成子网掩码
  ///
  /// 例如: prefixLength = 24 返回 '255.255.255.0'
  String cidrToSubnetMask(int prefixLength) {
    if (prefixLength < 0 || prefixLength > 32) {
      throw ArgumentError('CIDR前缀长度必须在0-32之间');
    }

    int mask = prefixLength == 0 ? 0 : (~0 << (32 - prefixLength)) & 0xFFFFFFFF;
    return [
      (mask >> 24) & 0xFF,
      (mask >> 16) & 0xFF,
      (mask >> 8) & 0xFF,
      mask & 0xFF,
    ].join('.');
  }

  /// 获取本机所有IPv4地址（不包含回环地址）
  Future<List<String>> getAllLocalIPv4Addresses() async {
    final List<String> addresses = [];

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (var interface in interfaces) {
        for (var address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 && !address.isLoopback) {
            addresses.add(address.address);
          }
        }
      }
    } catch (e) {
      debugPrint('获取本机IP地址列表失败: $e');
    }

    return addresses;
  }

  /// 获取本机主要的IPv4地址
  ///
  /// 优先返回私有地址，按以下优先级:
  /// 1. 192.168.x.x (最常见的家庭/办公网络)
  /// 2. 10.x.x.x (企业网络)
  /// 3. 172.16-31.x.x (企业网络)
  /// 4. 其他非回环地址
  Future<String> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      String? class192Address;
      String? class10Address;
      String? class172Address;
      String? otherAddress;

      for (var interface in interfaces) {
        for (var address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4) {
            final ip = address.address;
            final parts = ip.split('.').map(int.parse).toList();

            // 192.168.x.x - 最高优先级
            if (parts[0] == 192 && parts[1] == 168) {
              class192Address ??= ip;
            }
            // 10.x.x.x
            else if (parts[0] == 10) {
              class10Address ??= ip;
            }
            // 172.16-31.x.x
            else if (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) {
              class172Address ??= ip;
            }
            // 其他地址
            else if (!ip.startsWith('169.254.')) { // 排除链路本地地址
              otherAddress ??= ip;
            }
          }
        }
      }

      // 按优先级返回
      final result = class192Address ?? class10Address ?? class172Address ??
          otherAddress;

      if (result != null) {
        debugPrint('本机IP地址: $result');
        return result;
      }

      debugPrint('未找到有效IP地址');
      return '-1';
    } catch (e) {
      debugPrint('获取IP地址失败: $e');
      return '-1';
    }
  }

  /// 获取本机IP及其所属网络接口名称
  Future<Map<String, String>> getLocalIPWithInterface() async {
    final Map<String, String> result = {};

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (var interface in interfaces) {
        for (var address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4) {
            result[address.address] = interface.name;
          }
        }
      }
    } catch (e) {
      debugPrint('获取网络接口信息失败: $e');
    }

    return result;
  }

  /// 判断目标IP是否可达（通过ping测试）
  ///
  /// 注意: 此方法在某些平台可能不可用
  Future<bool> isReachable(String targetIP,
      {Duration timeout = const Duration(seconds: 3)}) async {
    try {
      // 尝试建立socket连接来测试可达性
      final socket = await Socket.connect(
        targetIP,
        80, // 尝试连接80端口
        timeout: timeout,
      ).catchError((e) => throw e);

      socket.destroy();
      return true;
    } catch (e) {
      // 连接失败，尝试ICMP ping（需要平台支持）
      try {
        final result = await InternetAddress(targetIP).reverse();
        return result.host.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

  /// 获取网络类型描述
  String getNetworkTypeDescription(String ip) {
    if (!_isValidIPv4(ip)) return '无效地址';
    if (_isLoopback(ip)) return '回环地址';
    if (isLinkLocal(ip)) return '链路本地地址';

    final parts = ip.split('.').map(int.parse).toList();

    if (parts[0] == 10) return 'A类私有地址 (10.0.0.0/8)';
    if (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) {
      return 'B类私有地址 (172.16.0.0/12)';
    }
    if (parts[0] == 192 && parts[1] == 168) {
      return 'C类私有地址 (192.168.0.0/16)';
    }

    return '公网地址';
  }

  /// 计算IP地址的广播地址
  String? getBroadcastAddress(String ip, String subnetMask) {
    try {
      final ipParts = ip.split('.').map(int.parse).toList();
      final maskParts = subnetMask.split('.').map(int.parse).toList();

      final broadcast = List<int>.generate(4, (i) {
        return (ipParts[i] & maskParts[i]) | (~maskParts[i] & 0xFF);
      });

      return broadcast.join('.');
    } catch (e) {
      debugPrint('计算广播地址失败: $e');
      return null;
    }
  }

  /// 计算网络地址
  String? getNetworkAddress(String ip, String subnetMask) {
    try {
      final ipParts = ip.split('.').map(int.parse).toList();
      final maskParts = subnetMask.split('.').map(int.parse).toList();

      final network = List<int>.generate(4, (i) {
        return ipParts[i] & maskParts[i];
      });

      return network.join('.');
    } catch (e) {
      debugPrint('计算网络地址失败: $e');
      return null;
    }
  }

  // ==================== HTTP 可访问性检测 ====================

  /// 检测单个URL是否可访问
  ///
  /// [url] 要检测的URL地址
  /// [timeout] 超时时间，默认5秒
  /// [useHead] 是否使用HEAD请求，默认false（使用GET更兼容）
  ///
  /// 返回 [UrlCheckResult] 包含检测结果详情
  Future<UrlCheckResult> checkUrlAccessible(String url, {
    Duration timeout = const Duration(seconds: 5),
    bool useHead = false,
  }) async {
    final stopwatch = Stopwatch()
      ..start();

    debugPrint('检测URL: $url');

    try {
      final uri = Uri.parse(url);

      // 创建 HttpClient
      final client = HttpClient()
        ..connectionTimeout = timeout
        ..idleTimeout = timeout;

      try {
        HttpClientRequest request;
        if (useHead) {
          // HEAD 请求更轻量，但某些服务器不支持
          request = await client.headUrl(uri).timeout(timeout);
        } else {
          // GET 请求兼容性更好
          request = await client.getUrl(uri).timeout(timeout);
        }

        final response = await request.close().timeout(timeout);

        // 读取并丢弃响应体（避免连接泄漏）
        await response.drain();

        stopwatch.stop();

        // 放宽判定：只要能连接上并返回任何HTTP响应，就认为是可访问的
        // 包括 4xx 和 5xx，因为这说明服务器是运行的
        final isSuccess = response.statusCode > 0;

        debugPrint('检测结果: HTTP ${response.statusCode}, 耗时: ${stopwatch
            .elapsedMilliseconds}ms');

        return UrlCheckResult(
          url: url,
          isAccessible: isSuccess,
          statusCode: response.statusCode,
          responseTime: stopwatch.elapsed,
          message: isSuccess
              ? '连接成功 (HTTP ${response.statusCode})'
              : 'HTTP ${response.statusCode}',
        );
      } finally {
        client.close();
      }
    } on SocketException catch (e) {
      stopwatch.stop();
      debugPrint(
          '检测失败 - SocketException: ${e.message}, osError: ${e.osError}');
      return UrlCheckResult(
        url: url,
        isAccessible: false,
        responseTime: stopwatch.elapsed,
        message: '网络连接失败: ${e.message}',
        error: e,
      );
    } on HttpException catch (e) {
      stopwatch.stop();
      debugPrint('检测失败 - HttpException: ${e.message}');
      return UrlCheckResult(
        url: url,
        isAccessible: false,
        responseTime: stopwatch.elapsed,
        message: 'HTTP错误: ${e.message}',
        error: e,
      );
    } on TimeoutException catch (e) {
      stopwatch.stop();
      debugPrint('检测失败 - 连接超时');
      return UrlCheckResult(
        url: url,
        isAccessible: false,
        responseTime: stopwatch.elapsed,
        message: '连接超时 (${timeout.inSeconds}秒)',
        error: e,
      );
    } on HandshakeException catch (e) {
      stopwatch.stop();
      debugPrint('检测失败 - HandshakeException: ${e.message}');
      return UrlCheckResult(
        url: url,
        isAccessible: false,
        responseTime: stopwatch.elapsed,
        message: 'SSL握手失败: ${e.message}',
        error: e,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('检测失败 - 未知错误: $e');
      return UrlCheckResult(
        url: url,
        isAccessible: false,
        responseTime: stopwatch.elapsed,
        message: '检测失败: $e',
        error: e,
      );
    }
  }

  /// 仅检测TCP端口连通性（最可靠的方式）
  ///
  /// 不发送HTTP请求，仅测试能否建立TCP连接
  /// 这是最基础的检测方式，如果这个都失败，说明网络不通或端口未开放
  Future<UrlCheckResult> checkTcpConnectivity(String ip,
      int port, {
        Duration timeout = const Duration(seconds: 5),
      }) async {
    final stopwatch = Stopwatch()
      ..start();
    final url = '$ip:$port';

    debugPrint('检测TCP连接: $url');

    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: timeout,
      );

      stopwatch.stop();
      socket.destroy();

      debugPrint('TCP连接成功: $url, 耗时: ${stopwatch.elapsedMilliseconds}ms');

      return UrlCheckResult(
        url: url,
        isAccessible: true,
        responseTime: stopwatch.elapsed,
        message: 'TCP连接成功',
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      debugPrint('TCP连接失败: $url - ${e.message}, osError: ${e.osError}');
      return UrlCheckResult(
        url: url,
        isAccessible: false,
        responseTime: stopwatch.elapsed,
        message: 'TCP连接失败: ${e.message}',
        error: e,
      );
    } on TimeoutException catch (e) {
      stopwatch.stop();
      debugPrint('TCP连接超时: $url');
      return UrlCheckResult(
        url: url,
        isAccessible: false,
        responseTime: stopwatch.elapsed,
        message: 'TCP连接超时',
        error: e,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('TCP连接错误: $url - $e');
      return UrlCheckResult(
        url: url,
        isAccessible: false,
        responseTime: stopwatch.elapsed,
        message: '连接错误: $e',
        error: e,
      );
    }
  }

  /// 检测指定IP的多个端口是否可访问
  ///
  /// [ip] IP地址
  /// [ports] 端口列表
  /// [scheme] 协议，默认 http
  /// [timeout] 超时时间
  ///
  /// 返回每个端口的检测结果
  Future<Map<int, UrlCheckResult>> checkPortsAccessible(String ip,
      List<int> ports, {
        String scheme = 'http',
        Duration timeout = const Duration(seconds: 5),
      }) async {
    final results = <int, UrlCheckResult>{};

    // 并行检测所有端口
    final futures = ports.map((port) async {
      final url = '$scheme://$ip:$port';
      final result = await checkUrlAccessible(url, timeout: timeout);
      return MapEntry(port, result);
    });

    final entries = await Future.wait(futures);
    results.addEntries(entries);

    return results;
  }

  /// 检测目标服务器的 8080 和 9000 端口是否可访问
  ///
  /// [targetIP] 目标服务器IP地址
  /// [timeout] 超时时间，默认5秒
  /// [useTcpCheck] 是否使用TCP检测（更可靠），默认true
  ///
  /// 返回包含两个端口检测结果的 [ServerCheckResult]
  Future<ServerCheckResult> checkServerPorts8080And9000(String targetIP, {
    Duration timeout = const Duration(seconds: 5),
    bool useTcpCheck = true,
  }) async {
    const port8080 = 8080;
    const port9000 = 9000;

    debugPrint('========== 开始检测服务器 $targetIP ==========');
    debugPrint('检测方式: ${useTcpCheck ? "TCP连接" : "HTTP请求"}');
    debugPrint('超时时间: ${timeout.inSeconds}秒');

    late UrlCheckResult result8080;
    late UrlCheckResult result9000;

    if (useTcpCheck) {
      // 使用TCP检测（更可靠）
      final results = await Future.wait([
        checkTcpConnectivity(targetIP, port8080, timeout: timeout),
        checkTcpConnectivity(targetIP, port9000, timeout: timeout),
      ]);
      result8080 = results[0];
      result9000 = results[1];
    } else {
      // 使用HTTP检测
      final results = await Future.wait([
        checkUrlAccessible('http://$targetIP:$port8080', timeout: timeout),
        checkUrlAccessible('http://$targetIP:$port9000', timeout: timeout),
      ]);
      result8080 = results[0];
      result9000 = results[1];
    }

    debugPrint('---------- 检测结果 ----------');
    debugPrint('端口 $port8080: ${result8080.isAccessible
        ? "✓ 可用"
        : "✗ 不可用"} - ${result8080.message}');
    debugPrint('端口 $port9000: ${result9000.isAccessible
        ? "✓ 可用"
        : "✗ 不可用"} - ${result9000.message}');
    debugPrint('==============================');

    return ServerCheckResult(
      ip: targetIP,
      port8080Result: result8080,
      port9000Result: result9000,
    );
  }

  /// 完整的服务器诊断（用于调试）
  ///
  /// 同时进行TCP和HTTP检测，输出详细诊断信息
  Future<ServerDiagnosticResult> diagnoseServer(String targetIP, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    debugPrint('');
    debugPrint('╔══════════════════════════════════════════╗');
    debugPrint('║       服务器诊断: $targetIP');
    debugPrint('╚══════════════════════════════════════════╝');

    // 1. 检测是否在同一局域网
    debugPrint('');
    debugPrint('【1. 局域网检测】');
    final isInLAN = await isLAN(targetIP);
    final localIP = await getLocalIpAddress();
    debugPrint('本机IP: $localIP');
    debugPrint('目标IP: $targetIP');
    debugPrint('同一局域网: ${isInLAN ? "是 ✓" : "否 ✗"}');

    // 2. TCP连接检测
    debugPrint('');
    debugPrint('【2. TCP端口检测】');
    final tcp8080 = await checkTcpConnectivity(
        targetIP, 8080, timeout: timeout);
    final tcp9000 = await checkTcpConnectivity(
        targetIP, 9000, timeout: timeout);
    debugPrint(
        'TCP 8080: ${tcp8080.isAccessible ? "✓ 开放" : "✗ 关闭"} (${tcp8080
            .responseTime.inMilliseconds}ms) - ${tcp8080.message}');
    debugPrint(
        'TCP 9000: ${tcp9000.isAccessible ? "✓ 开放" : "✗ 关闭"} (${tcp9000
            .responseTime.inMilliseconds}ms) - ${tcp9000.message}');

    // 3. HTTP检测
    debugPrint('');
    debugPrint('【3. HTTP服务检测】');
    final http8080 = await checkUrlAccessible(
        'http://$targetIP:8080', timeout: timeout);
    final http9000 = await checkUrlAccessible(
        'http://$targetIP:9000', timeout: timeout);
    debugPrint('HTTP 8080: ${http8080.isAccessible
        ? "✓ 可用"
        : "✗ 不可用"} (HTTP ${http8080.statusCode ?? "N/A"}) - ${http8080
        .message}');
    debugPrint('HTTP 9000: ${http9000.isAccessible
        ? "✓ 可用"
        : "✗ 不可用"} (HTTP ${http9000.statusCode ?? "N/A"}) - ${http9000
        .message}');

    // 4. 诊断结论
    debugPrint('');
    debugPrint('【4. 诊断结论】');
    String conclusion;
    if (!isInLAN) {
      conclusion = '目标IP不在同一局域网内，请检查网络配置';
    } else if (!tcp8080.isAccessible && !tcp9000.isAccessible) {
      conclusion = 'TCP连接失败，可能原因：\n'
          '  - 服务器未启动\n'
          '  - 防火墙阻止了连接\n'
          '  - IP地址错误\n'
          '  - 网络不通';
    } else if (tcp8080.isAccessible && !http8080.isAccessible) {
      conclusion = 'TCP连接成功但HTTP请求失败，可能原因：\n'
          '  - 服务不是HTTP服务\n'
          '  - 服务正在启动中\n'
          '  - 服务配置问题';
    } else {
      conclusion = '服务器正常可用 ✓';
    }
    debugPrint(conclusion);
    debugPrint('');

    return ServerDiagnosticResult(
      targetIP: targetIP,
      localIP: localIP,
      isInLAN: isInLAN,
      tcp8080: tcp8080,
      tcp9000: tcp9000,
      http8080: http8080,
      http9000: http9000,
      conclusion: conclusion,
    );
  }

  /// 检测指定服务器的多个端口
  ///
  /// [ip] 服务器IP
  /// [ports] 要检测的端口列表
  /// [timeout] 超时时间
  Future<List<UrlCheckResult>> checkServerPorts(String ip,
      List<int> ports, {
        Duration timeout = const Duration(seconds: 5),
      }) async {
    final futures = ports.map((port) {
      return checkUrlAccessible('http://$ip:$port', timeout: timeout);
    });

    return Future.wait(futures);
  }

  /// 检测TCP端口是否开放（不发送HTTP请求）
  ///
  /// 比HTTP检测更快，仅测试端口是否可连接
  Future<PortCheckResult> checkPortOpen(String ip,
      int port, {
        Duration timeout = const Duration(seconds: 3),
      }) async {
    final stopwatch = Stopwatch()
      ..start();

    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: timeout,
      );

      stopwatch.stop();
      socket.destroy();

      return PortCheckResult(
        ip: ip,
        port: port,
        isOpen: true,
        responseTime: stopwatch.elapsed,
        message: '端口开放',
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      return PortCheckResult(
        ip: ip,
        port: port,
        isOpen: false,
        responseTime: stopwatch.elapsed,
        message: '连接失败: ${e.message}',
      );
    } on TimeoutException {
      stopwatch.stop();
      return PortCheckResult(
        ip: ip,
        port: port,
        isOpen: false,
        responseTime: stopwatch.elapsed,
        message: '连接超时',
      );
    } catch (e) {
      stopwatch.stop();
      return PortCheckResult(
        ip: ip,
        port: port,
        isOpen: false,
        responseTime: stopwatch.elapsed,
        message: '检测失败: $e',
      );
    }
  }

  /// 批量检测多个TCP端口是否开放
  Future<List<PortCheckResult>> checkMultiplePortsOpen(String ip,
      List<int> ports, {
        Duration timeout = const Duration(seconds: 3),
      }) async {
    final futures = ports.map((port) {
      return checkPortOpen(ip, port, timeout: timeout);
    });

    return Future.wait(futures);
  }
}

// ==================== 数据类 ====================

/// URL检测结果
class UrlCheckResult {
  final String url;
  final bool isAccessible;
  final int? statusCode;
  final Duration responseTime;
  final String message;
  final Object? error;

  UrlCheckResult({
    required this.url,
    required this.isAccessible,
    this.statusCode,
    required this.responseTime,
    required this.message,
    this.error,
  });

  @override
  String toString() {
    return 'UrlCheckResult('
        'url: $url, '
        'accessible: $isAccessible, '
        'status: $statusCode, '
        'time: ${responseTime.inMilliseconds}ms, '
        'message: $message)';
  }
}

/// 端口检测结果
class PortCheckResult {
  final String ip;
  final int port;
  final bool isOpen;
  final Duration responseTime;
  final String message;

  PortCheckResult({
    required this.ip,
    required this.port,
    required this.isOpen,
    required this.responseTime,
    required this.message,
  });

  @override
  String toString() {
    return 'PortCheckResult('
        '$ip:$port, '
        'open: $isOpen, '
        'time: ${responseTime.inMilliseconds}ms, '
        'message: $message)';
  }
}

/// 服务器检测结果 (针对 targetIP)
class ServerCheckResult {
  final String ip;
  final UrlCheckResult port8080Result;
  final UrlCheckResult port9000Result;

  ServerCheckResult({
    required this.ip,
    required this.port8080Result,
    required this.port9000Result,
  });

  /// 8080端口是否可访问
  bool get is8080Accessible => port8080Result.isAccessible;

  /// 9000端口是否可访问
  bool get is9000Accessible => port9000Result.isAccessible;

  /// 两个端口是否都可访问
  bool get isAllAccessible => is8080Accessible && is9000Accessible;

  /// 至少一个端口可访问
  bool get isAnyAccessible => is8080Accessible || is9000Accessible;

  @override
  String toString() {
    return 'ServerCheckResult(\n'
        '  ip: $ip,\n'
        '  port 8080: ${is8080Accessible ? "✓" : "✗"} ${port8080Result
        .message},\n'
        '  port 9000: ${is9000Accessible ? "✓" : "✗"} ${port9000Result
        .message}\n'
        ')';
  }
}

/// 服务器诊断结果（用于调试）
class ServerDiagnosticResult {
  final String targetIP;
  final String localIP;
  final bool isInLAN;
  final UrlCheckResult tcp8080;
  final UrlCheckResult tcp9000;
  final UrlCheckResult http8080;
  final UrlCheckResult http9000;
  final String conclusion;

  ServerDiagnosticResult({
    required this.targetIP,
    required this.localIP,
    required this.isInLAN,
    required this.tcp8080,
    required this.tcp9000,
    required this.http8080,
    required this.http9000,
    required this.conclusion,
  });

  /// TCP端口是否都可用
  bool get isTcpAvailable => tcp8080.isAccessible && tcp9000.isAccessible;

  /// HTTP服务是否都可用
  bool get isHttpAvailable => http8080.isAccessible && http9000.isAccessible;

  /// 服务器是否完全可用
  bool get isFullyAvailable => isInLAN && isTcpAvailable;

  @override
  String toString() {
    return '''
ServerDiagnosticResult:
  目标IP: $targetIP
  本机IP: $localIP
  局域网: $isInLAN
  TCP 8080: ${tcp8080.isAccessible}
  TCP 9000: ${tcp9000.isAccessible}
  HTTP 8080: ${http8080.isAccessible} (${http8080.statusCode})
  HTTP 9000: ${http9000.isAccessible} (${http9000.statusCode})
  结论: $conclusion
''';
  }
}