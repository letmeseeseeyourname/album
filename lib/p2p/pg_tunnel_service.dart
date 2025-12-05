import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'pg_tunnel_bindings.dart';
import 'pg_tunnel_types.dart';

/// P2P Tunnel 事件监听器
typedef TunnelEventListener = void Function(int eventId, String param);

/// 事件消息结构
class _EventMessage {
  final int eventId;
  final String param;
  _EventMessage(this.eventId, this.param);
}

/// 对端设备信息结果类
class PgTunnelPeerInfoResult {
  final String peerId;
  final int connectionType;
  final String peerAddr;
  final int tunnelCount;

  PgTunnelPeerInfoResult({
    required this.peerId,
    required this.connectionType,
    required this.peerAddr,
    required this.tunnelCount,
  });

  /// 获取连接类型名称
  String get connectionTypeName {
    switch (connectionType) {
      case 0:
        return 'Unknown';
      case 1:
        return 'Direct (P2P)';
      case 2:
        return 'Relay';
      case 3:
        return 'UPnP';
      default:
        return 'Type($connectionType)';
    }
  }

  /// 是否是直连
  bool get isDirect => connectionType == 1;

  /// 是否是中继
  bool get isRelay => connectionType == 2;

  @override
  String toString() {
    return 'PgTunnelPeerInfoResult(peerId: $peerId, type: $connectionTypeName, '
        'addr: $peerAddr, tunnels: $tunnelCount)';
  }
}

/// P2P Tunnel 服务
class PgTunnelService {
  static final PgTunnelService _instance = PgTunnelService._internal();
  factory PgTunnelService() => _instance;

  final PgTunnelBindings _bindings = PgTunnelBindings();
  final List<TunnelEventListener> _eventListeners = [];

  bool _isRunning = false;
  String _currentAccount = '';

  // NativePort相关
  ReceivePort? _receivePort;
  int? _nativePort;

  PgTunnelService._internal();

  /// 是否正在运行
  bool get isRunning => _isRunning;

  /// 当前账号
  String get currentAccount => _currentAccount;

  /// 添加事件监听器
  void addEventListener(TunnelEventListener listener) {
    _eventListeners.add(listener);
  }

  /// 移除事件监听器
  void removeEventListener(TunnelEventListener listener) {
    _eventListeners.remove(listener);
  }

  /// 初始化NativePort（用于接收native回调）
  void _initNativePort() {
    if (_receivePort != null) return;

    _receivePort = ReceivePort();
    _nativePort = _receivePort!.sendPort.nativePort;

    // 监听来自native的消息
    _receivePort!.listen((dynamic message) {
      if (message is List && message.length == 2) {
        final eventId = message[0] as int;
        final param = message[1] as String;
        _handleEvent(eventId, param);
      }
    });
  }

  /// 处理事件（在Dart isolate中安全执行）
  void _handleEvent(int eventId, String param) {
    debugPrint(
        'Tunnel Event: ${PgTunnelEvent.getEventName(eventId)} ($eventId), Param: $param');

    // 通知所有监听器
    for (final listener in _eventListeners) {
      try {
        listener(eventId, param);
      } catch (e) {
        debugPrint('Error in event listener: $e');
      }
    }
  }

  /// 清理NativePort
  void _cleanupNativePort() {
    _receivePort?.close();
    _receivePort = null;
    _nativePort = null;
  }

  /// 启动隧道
  ///
  /// [localDeviceId] 本地设备ID,例如: "win_device123"
  /// [cfgFilePath] 配置文件路径,如果为空则使用默认路径
  Future<void> start(String localDeviceId, {String? cfgFilePath}) async {
    if (_isRunning) {
      debugPrint('Tunnel is already running');
      return;
    }

    // 确定配置文件路径
    String cfgPath = cfgFilePath ?? '';
    if (cfgPath.isEmpty) {
      // 尝试多个可能的路径
      final currentDir = Directory.current.path;
      final possiblePaths = [
        'demoTunnel.cfg',
        '$currentDir\\demoTunnel.cfg',
        '$currentDir\\assets\\demoTunnel.cfg',
        '$currentDir\\data\\flutter_assets\\assets\\demoTunnel.cfg',
        '$currentDir\\build\\windows\\runner\\Debug\\data\\flutter_assets\\assets\\demoTunnel.cfg',
        '$currentDir\\build\\windows\\runner\\Release\\data\\flutter_assets\\assets\\demoTunnel.cfg',
        'assets\\demoTunnel.cfg',
      ];

      debugPrint('Searching for config file in:');
      for (final path in possiblePaths) {
        debugPrint('  Checking: $path');
        if (await File(path).exists()) {
          cfgPath = path;
          debugPrint('✓ Found config file at: $cfgPath');
          break;
        }
      }

      if (cfgPath.isEmpty) {
        debugPrint('❌ Config file not found. Searched in:');
        for (final path in possiblePaths) {
          debugPrint('  - $path');
        }
        throw Exception(
            'Config file not found. Please ensure demoTunnel.cfg exists in:\n'
                '  1. Project root: $currentDir\\demoTunnel.cfg\n'
                '  2. Assets folder: $currentDir\\assets\\demoTunnel.cfg'
        );
      }
    }

    // 注意：暂时不设置事件回调以避免isolate错误
    // 在Dart FFI中，从native线程调用Dart回调需要特殊处理
    // 未来版本可以使用NativeCallable (Dart 3.1+) 来实现
    debugPrint('⚠️  Event callbacks are disabled to avoid isolate errors');

    // 准备系统信息
    final sysInfo =
        '(DevID){$localDeviceId}(MacAddr){}(CpuMHz){0}(MemSize){0}'
        '(BrwVer){}(OSVer){}(OSSpk){}(OSType){Windows}';

    // 转换为C字符串
    final cfgFilePtr = cfgPath.toNativeUtf8();
    final sysInfoPtr = sysInfo.toNativeUtf8();

    try {
      // 启动隧道（不设置回调以避免isolate错误）
      final result = _bindings.pgTunnelStart(
        cfgFilePtr,
        sysInfoPtr,
        0,
        nullptr, // 暂时不设置debug回调
      );

      if (result != PgTunnelError.ok) {
        throw Exception(
            'Failed to start tunnel: ${PgTunnelError.getErrorMessage(result)}');
      }

      _isRunning = true;
      debugPrint('Tunnel started successfully with device ID: $localDeviceId');

      // 获取版本信息
      await _printVersionInfo();

      // 获取说明信息
      await _printCommentInfo();
    } finally {
      malloc.free(cfgFilePtr);
      malloc.free(sysInfoPtr);
    }
  }

  /// 停止隧道
  Future<void> stop() async {
    if (!_isRunning) {
      debugPrint('Tunnel is not running');
      return;
    }

    _bindings.pgTunnelStop();
    _isRunning = false;
    _currentAccount = '';
    debugPrint('Tunnel stopped');
  }

  /// 添加连接
  ///
  /// [peerId] 对端设备ID
  /// [listenAddr] 监听地址,格式: "ip:port"
  /// [clientAddr] 客户端地址,格式: "ip:port"
  Future<String> connectAdd({
    required String peerId,
    required String listenAddr,
    required String clientAddr,
  }) async {
    if (!_isRunning) {
      throw Exception('Tunnel is not running');
    }

    // 验证地址格式
    if (!listenAddr.contains(':')) {
      throw Exception('Invalid listen address format! Format is "x.x.x.x:y"');
    }

    if (clientAddr.isNotEmpty && !clientAddr.contains(':')) {
      throw Exception('Invalid client address format! Format is "x.x.x.x:y"');
    }

    final sessionPtr = ''.toNativeUtf8();
    final peerIdPtr = peerId.toNativeUtf8();
    final listenAddrPtr = listenAddr.toNativeUtf8();
    final clientAddrPtr = clientAddr.toNativeUtf8();
    final clientAddrResult = malloc<PgTunnelClientAddr>();

    try {
      final result = _bindings.pgTunnelConnectAdd(
        sessionPtr,
        peerIdPtr,
        0, // TCP类型
        0, // 不加密
        listenAddrPtr,
        clientAddrPtr,
        clientAddrResult,
      );

      if (result != PgTunnelError.ok) {
        throw Exception(
            'Failed to add connection: ${PgTunnelError.getErrorMessage(result)}');
      }

      final actualClientAddr = clientAddrResult.ref.clientAddr;
      debugPrint('Connection added successfully: $actualClientAddr');

      // 查询连接信息
      await _queryConnection(actualClientAddr);

      _currentAccount = peerId;
      return actualClientAddr;
    } finally {
      malloc.free(sessionPtr);
      malloc.free(peerIdPtr);
      malloc.free(listenAddrPtr);
      malloc.free(clientAddrPtr);
      malloc.free(clientAddrResult);
    }
  }

  /// 删除连接
  ///
  /// [peerId] 对端设备ID
  /// [clientAddr] 客户端地址
  Future<void> connectDelete({
    required String peerId,
    required String clientAddr,
  }) async {
    if (!_isRunning) {
      throw Exception('Tunnel is not running');
    }

    if (clientAddr.isNotEmpty && !clientAddr.contains(':')) {
      throw Exception('Invalid client address format! Format is "x.x.x.x:y"');
    }

    final sessionPtr = ''.toNativeUtf8();
    final clientAddrPtr = clientAddr.toNativeUtf8();

    try {
      final result = _bindings.pgTunnelConnectLocalDelete(
        sessionPtr,
        clientAddrPtr,
      );

      if (result != PgTunnelError.ok) {
        throw Exception(
            'Failed to delete connection: ${PgTunnelError.getErrorMessage(result)}');
      }

      debugPrint('Connection deleted successfully');
    } finally {
      malloc.free(sessionPtr);
      malloc.free(clientAddrPtr);
    }
  }

  /// 获取版本信息
  Future<String> getVersion() async {
    final versionPtr = malloc<PgTunnelVersion>();
    try {
      final result = _bindings.pgTunnelVersionGet(versionPtr);
      if (result != PgTunnelError.ok) {
        throw Exception(
            'Failed to get version: ${PgTunnelError.getErrorMessage(result)}');
      }
      return versionPtr.ref.version;
    } finally {
      malloc.free(versionPtr);
    }
  }

  /// 获取注释信息
  Future<String> getComment() async {
    final commentPtr = malloc<PgTunnelComment>();
    try {
      final result = _bindings.pgTunnelCommentGet(commentPtr);
      if (result != PgTunnelError.ok) {
        throw Exception(
            'Failed to get comment: ${PgTunnelError.getErrorMessage(result)}');
      }
      return commentPtr.ref.comment;
    } finally {
      malloc.free(commentPtr);
    }
  }

  /// 获取登录状态
  Future<int> getLoginStatus() async {
    final statusPtr = malloc<PgTunnelStatus>();
    try {
      final result = _bindings.pgTunnelStatusGet(0, statusPtr); // 0 = login status
      if (result != PgTunnelError.ok) {
        throw Exception(
            'Failed to get status: ${PgTunnelError.getErrorMessage(result)}');
      }
      return statusPtr.ref.uStatus;
    } finally {
      malloc.free(statusPtr);
    }
  }

  /// 获取对端设备信息
  ///
  /// [peerId] 对端设备ID
  /// 返回 [PgTunnelPeerInfoResult] 包含对端信息
  Future<PgTunnelPeerInfoResult> getPeerInfo(String peerId) async {
    if (!_isRunning) {
      throw Exception('Tunnel is not running');
    }

    final peerIdPtr = peerId.toNativeUtf8();
    final peerInfoPtr = malloc<PgTunnelPeerInfo>();

    try {
      final result = _bindings.pgTunnelPeerInfoGet(peerIdPtr, peerInfoPtr);

      if (result != PgTunnelError.ok) {
        throw Exception(
            'Failed to get peer info: ${PgTunnelError.getErrorMessage(result)}');
      }

      final info = PgTunnelPeerInfoResult(
        peerId: peerInfoPtr.ref.peerId,
        connectionType: peerInfoPtr.ref.uCnntType,
        peerAddr: peerInfoPtr.ref.peerAddr,
        tunnelCount: peerInfoPtr.ref.uTunnelCount,
      );

      debugPrint('Peer Info - ID: ${info.peerId}, '
          'Type: ${info.connectionTypeName}, '
          'Addr: ${info.peerAddr}, '
          'Tunnels: ${info.tunnelCount}');

      return info;
    } finally {
      malloc.free(peerIdPtr);
      malloc.free(peerInfoPtr);
    }
  }

  /// 打印版本信息
  Future<void> _printVersionInfo() async {
    try {
      final version = await getVersion();
      debugPrint('Tunnel Version: $version');
    } catch (e) {
      debugPrint('Failed to get version: $e');
    }
  }

  /// 打印说明信息
  Future<void> _printCommentInfo() async {
    try {
      final comment = await getComment();
      debugPrint('Tunnel Comment: $comment');
    } catch (e) {
      debugPrint('Failed to get comment: $e');
    }
  }

  /// 查询连接信息
  Future<void> _queryConnection(String clientAddr) async {
    final clientAddrPtr = clientAddr.toNativeUtf8();
    final connectInfo = malloc<PgTunnelConnectInfo>();

    try {
      final result = _bindings.pgTunnelConnectLocalQuery(
        clientAddrPtr,
        connectInfo,
      );

      if (result == PgTunnelError.ok) {
        debugPrint(
            'Connection Query - Client: ${connectInfo.ref.clientAddr}, '
                'Peer: ${connectInfo.ref.peerId}, '
                'Listen: ${connectInfo.ref.listenAddr}');
      } else {
        debugPrint(
            'Connection query failed: ${PgTunnelError.getErrorMessage(result)}');
      }
    } finally {
      malloc.free(clientAddrPtr);
      malloc.free(connectInfo);
    }
  }

// 静态回调函数 - 暂时禁用以避免isolate错误
// 未来可以使用NativeCallable (Dart 3.1+) 或 NativePort 来实现
/*
  static void _staticEventCallback(int uEvent, Pointer<Utf8> lpszParam) {
    // 不能在这里直接访问Dart isolate
    // 需要使用NativePort或NativeCallable
  }

  static void _staticDebugOut(int uLevel, Pointer<Utf8> lpszOut) {
    // 不能在这里直接访问Dart isolate
    // 需要使用NativePort或NativeCallable
  }
  */
}