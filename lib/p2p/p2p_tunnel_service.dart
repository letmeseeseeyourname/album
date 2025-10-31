import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'p2p_tunnel_bindings.dart';

class P2PTunnelService {
  static P2PTunnelService? _instance;
  late P2PTunnelBindings _bindings;
  bool _isInitialized = false;
  bool _isLoggedIn = false;

  P2PTunnelService._internal() {
    _bindings = P2PTunnelBindings();
  }

  // 单例模式
  factory P2PTunnelService() {
    _instance ??= P2PTunnelService._internal();
    return _instance!;
  }

  // 获取SDK版本
  String getVersion() {
    final versionPtr = _bindings.pgTunnelVersionGet();
    if (versionPtr.address == 0) {
      return 'Unknown';
    }
    return versionPtr.toDartString();
  }

  // 初始化P2P隧道
  Future<bool> initialize({
    required String domain,
    String? domainBackup,
    String? configFile,
  }) async {
    if (_isInitialized) {
      print('P2P Tunnel already initialized');
      return true;
    }

    final domainPtr = domain.toNativeUtf8();
    final domainBakPtr = (domainBackup ?? '').toNativeUtf8();
    final cfgFilePtr = (configFile ?? '').toNativeUtf8();

    try {
      final result = _bindings.pgTunnelInit(
        domainPtr,
        domainBakPtr,
        cfgFilePtr,
      );

      if (result == PgTunnelError.ok) {
        _isInitialized = true;
        print('P2P Tunnel initialized successfully');
        return true;
      } else {
        print('P2P Tunnel initialization failed: ${P2PTunnelBindings.getErrorMessage(result)}');
        return false;
      }
    } finally {
      malloc.free(domainPtr);
      malloc.free(domainBakPtr);
      malloc.free(cfgFilePtr);
    }
  }

  // 登录P2P服务器
  Future<bool> login({
    required String username,
    required String password,
    int timeout = 30000, // 默认30秒超时
  }) async {
    if (!_isInitialized) {
      print('P2P Tunnel not initialized. Please call initialize() first.');
      return false;
    }

    if (_isLoggedIn) {
      print('Already logged in');
      return true;
    }

    final userPtr = username.toNativeUtf8();
    final passPtr = password.toNativeUtf8();

    try {
      final result = _bindings.pgTunnelLogin(
        userPtr,
        passPtr,
        timeout,
      );

      if (result == PgTunnelError.ok) {
        _isLoggedIn = true;
        print('P2P login successful for user: $username');
        return true;
      } else {
        print('P2P login failed: ${P2PTunnelBindings.getErrorMessage(result)}');
        return false;
      }
    } finally {
      malloc.free(userPtr);
      malloc.free(passPtr);
    }
  }

  // 获取登录状态
  Future<int> getLoginStatus() async {
    if (!_isInitialized) {
      return PgTunnelLoginStatus.initFailed;
    }

    final status = _bindings.pgTunnelStatusGet(0); // 0 = PG_TUNNEL_GET_STA_LOGIN
    return status;
  }

  // 连接到远程对等端
  Future<bool> connectToPeer({
    required String peerID,
    int timeout = 30000, // 默认30秒超时
  }) async {
    if (!_isLoggedIn) {
      print('Not logged in. Please login first.');
      return false;
    }

    final peerIDPtr = peerID.toNativeUtf8();

    try {
      final result = _bindings.pgTunnelConnectAdd(
        peerIDPtr,
        timeout,
      );

      if (result == PgTunnelError.ok) {
        print('Successfully connected to peer: $peerID');
        return true;
      } else {
        print('Failed to connect to peer $peerID: ${P2PTunnelBindings.getErrorMessage(result)}');
        return false;
      }
    } finally {
      malloc.free(peerIDPtr);
    }
  }

  // 断开与远程对等端的连接
  Future<bool> disconnectFromPeer(String peerID) async {
    if (!_isLoggedIn) {
      print('Not logged in');
      return false;
    }

    final peerIDPtr = peerID.toNativeUtf8();

    try {
      final result = _bindings.pgTunnelConnectDelete(peerIDPtr);

      if (result == PgTunnelError.ok) {
        print('Successfully disconnected from peer: $peerID');
        return true;
      } else {
        print('Failed to disconnect from peer $peerID: ${P2PTunnelBindings.getErrorMessage(result)}');
        return false;
      }
    } finally {
      malloc.free(peerIDPtr);
    }
  }

  // 登出
  Future<bool> logout() async {
    if (!_isLoggedIn) {
      print('Not logged in');
      return true;
    }

    final result = _bindings.pgTunnelLogout();

    if (result == PgTunnelError.ok) {
      _isLoggedIn = false;
      print('P2P logout successful');
      return true;
    } else {
      print('P2P logout failed: ${P2PTunnelBindings.getErrorMessage(result)}');
      return false;
    }
  }

  // 反初始化
  Future<bool> uninitialize() async {
    if (!_isInitialized) {
      return true;
    }

    // 如果已登录，先登出
    if (_isLoggedIn) {
      await logout();
    }

    final result = _bindings.pgTunnelUninit();

    if (result == PgTunnelError.ok) {
      _isInitialized = false;
      print('P2P Tunnel uninitialized');
      return true;
    } else {
      print('P2P Tunnel uninitialize failed: ${P2PTunnelBindings.getErrorMessage(result)}');
      return false;
    }
  }

  // 检查是否已初始化
  bool get isInitialized => _isInitialized;

  // 检查是否已登录
  bool get isLoggedIn => _isLoggedIn;

  // 清理资源
  Future<void> dispose() async {
    await uninitialize();
    _instance = null;
  }
}