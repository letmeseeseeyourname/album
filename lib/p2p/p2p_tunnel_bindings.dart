import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

// P2P Tunnel错误码枚举
class PgTunnelError {
  static const int ok = 0;
  static const int system = -1;
  static const int badParam = -2;
  static const int badClass = -3;
  static const int badMethod = -4;
  static const int badObject = -5;
  static const int badStatus = -6;
  static const int badFile = -7;
  static const int badUser = -8;
  static const int badPass = -9;
  static const int noLogin = -10;
  static const int network = -11;
  static const int timeout = -12;
  static const int reject = -13;
  static const int busy = -14;
  static const int opened = -15;
  static const int closed = -16;
  static const int exist = -17;
  static const int noExist = -18;
  static const int noSpace = -19;
  static const int badType = -20;
  static const int checkErr = -21;
  static const int badServer = -22;
  static const int badDomain = -23;
  static const int noData = -24;
  static const int unknown = -255;
  static const int noImp = -256;
}

// P2P连接类型枚举
class PgTunnelCnnt {
  static const int unknown = 0;
  static const int ipv4Pub = 4;
  static const int ipv4NATConeFull = 5;
  static const int ipv4NATConeHost = 6;
  static const int ipv4NATConePort = 7;
  static const int ipv4NATSymmet = 8;
  static const int ipv4Private = 12;
  static const int ipv4NATLoop = 13;
  static const int ipv4TunnelTCP = 16;
  static const int ipv4TunnelHTTP = 17;
  static const int ipv4PeerFwd = 24;
  static const int ipv6Pub = 32;
  static const int ipv6Local = 36;
  static const int ipv6TunnelTCP = 40;
  static const int ipv6TunnelHTTP = 41;
  static const int p2p = 128;
  static const int local = 129;
  static const int peerForward = 130;
  static const int relayForward = 131;
  static const int offline = 65535;
}

// P2P登录状态枚举
class PgTunnelLoginStatus {
  static const int success = 0;
  static const int config = 4;
  static const int sysInfo = 5;
  static const int resolution = 6;
  static const int buildAccount = 7;
  static const int initNode = 8;
  static const int initFailed = 9;
  static const int loginFailed = 10;
  static const int logouted = 11;
  static const int requesting = 16;
  static const int timeout = 17;
  static const int network = 18;
  static const int badUser = 19;
  static const int badPass = 20;
  static const int reject = 21;
  static const int busy = 22;
  static const int failed = 23;
}

// 定义C函数签名类型
typedef PgTunnelVersionGetNative = ffi.Pointer<Utf8> Function();
typedef PgTunnelVersionGetDart = ffi.Pointer<Utf8> Function();

typedef PgTunnelInitNative = ffi.Int32 Function(
    ffi.Pointer<Utf8> lpszDomain,
    ffi.Pointer<Utf8> lpszDomainBak,
    ffi.Pointer<Utf8> lpszCfgFile,
    );
typedef PgTunnelInitDart = int Function(
    ffi.Pointer<Utf8> lpszDomain,
    ffi.Pointer<Utf8> lpszDomainBak,
    ffi.Pointer<Utf8> lpszCfgFile,
    );

typedef PgTunnelUninitNative = ffi.Int32 Function();
typedef PgTunnelUninitDart = int Function();

typedef PgTunnelLoginNative = ffi.Int32 Function(
    ffi.Pointer<Utf8> lpszUser,
    ffi.Pointer<Utf8> lpszPass,
    ffi.Uint32 uTimeout,
    );
typedef PgTunnelLoginDart = int Function(
    ffi.Pointer<Utf8> lpszUser,
    ffi.Pointer<Utf8> lpszPass,
    int uTimeout,
    );

typedef PgTunnelLogoutNative = ffi.Int32 Function();
typedef PgTunnelLogoutDart = int Function();

typedef PgTunnelStatusGetNative = ffi.Int32 Function(
    ffi.Uint32 uOption,
    );
typedef PgTunnelStatusGetDart = int Function(
    int uOption,
    );

typedef PgTunnelConnectAddNative = ffi.Int32 Function(
    ffi.Pointer<Utf8> lpszPeerID,
    ffi.Uint32 uTimeout,
    );
typedef PgTunnelConnectAddDart = int Function(
    ffi.Pointer<Utf8> lpszPeerID,
    int uTimeout,
    );

typedef PgTunnelConnectDeleteNative = ffi.Int32 Function(
    ffi.Pointer<Utf8> lpszPeerID,
    );
typedef PgTunnelConnectDeleteDart = int Function(
    ffi.Pointer<Utf8> lpszPeerID,
    );

// P2P Tunnel FFI绑定类
class P2PTunnelBindings {
  late ffi.DynamicLibrary _dylib;

  // 函数指针
  late PgTunnelVersionGetDart pgTunnelVersionGet;
  late PgTunnelInitDart pgTunnelInit;
  late PgTunnelUninitDart pgTunnelUninit;
  late PgTunnelLoginDart pgTunnelLogin;
  late PgTunnelLogoutDart pgTunnelLogout;
  late PgTunnelStatusGetDart pgTunnelStatusGet;
  late PgTunnelConnectAddDart pgTunnelConnectAdd;
  late PgTunnelConnectDeleteDart pgTunnelConnectDelete;

  P2PTunnelBindings() {
    // 加载DLL
    if (Platform.isWindows) {
      _dylib = ffi.DynamicLibrary.open('pgDllTunnel.dll');
    } else {
      throw UnsupportedError('This platform is not supported');
    }

    // 绑定函数
    pgTunnelVersionGet = _dylib
        .lookup<ffi.NativeFunction<PgTunnelVersionGetNative>>('pgTunnelVersionGet')
        .asFunction();

    pgTunnelInit = _dylib
        .lookup<ffi.NativeFunction<PgTunnelInitNative>>('pgTunnelInit')
        .asFunction();

    pgTunnelUninit = _dylib
        .lookup<ffi.NativeFunction<PgTunnelUninitNative>>('pgTunnelUninit')
        .asFunction();

    pgTunnelLogin = _dylib
        .lookup<ffi.NativeFunction<PgTunnelLoginNative>>('pgTunnelLogin')
        .asFunction();

    pgTunnelLogout = _dylib
        .lookup<ffi.NativeFunction<PgTunnelLogoutNative>>('pgTunnelLogout')
        .asFunction();

    pgTunnelStatusGet = _dylib
        .lookup<ffi.NativeFunction<PgTunnelStatusGetNative>>('pgTunnelStatusGet')
        .asFunction();

    pgTunnelConnectAdd = _dylib
        .lookup<ffi.NativeFunction<PgTunnelConnectAddNative>>('pgTunnelConnectAdd')
        .asFunction();

    pgTunnelConnectDelete = _dylib
        .lookup<ffi.NativeFunction<PgTunnelConnectDeleteNative>>('pgTunnelConnectDelete')
        .asFunction();
  }

  // 获取错误描述
  static String getErrorMessage(int errorCode) {
    switch (errorCode) {
      case PgTunnelError.ok:
        return '成功';
      case PgTunnelError.system:
        return '系统错误';
      case PgTunnelError.badParam:
        return '参数错误';
      case PgTunnelError.badUser:
        return '用户不存在';
      case PgTunnelError.badPass:
        return '密码错误';
      case PgTunnelError.noLogin:
        return '未登录';
      case PgTunnelError.network:
        return '网络故障';
      case PgTunnelError.timeout:
        return '操作超时';
      case PgTunnelError.reject:
        return '拒绝操作';
      case PgTunnelError.busy:
        return '系统正忙';
      default:
        return '未知错误: $errorCode';
    }
  }
}