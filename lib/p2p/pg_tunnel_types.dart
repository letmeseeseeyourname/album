import 'dart:ffi';
import 'package:ffi/ffi.dart';

/// 辅助函数：从Array<Int8>读取C字符串
String _readCString(Array<Int8> array, int maxLength) {
  final buffer = StringBuffer();
  for (int i = 0; i < maxLength; i++) {
    final char = array[i];
    if (char == 0) break; // null terminator
    buffer.writeCharCode(char);
  }
  return buffer.toString();
}

/// 错误码定义
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

  static String getErrorMessage(int code) {
    switch (code) {
      case ok:
        return 'Success';
      case system:
        return 'System error';
      case badParam:
        return 'Invalid parameter';
      case badStatus:
        return 'Bad status';
      case badFile:
        return 'Invalid file';
      case badUser:
        return 'User does not exist';
      case badPass:
        return 'Wrong password';
      case noLogin:
        return 'Not logged in';
      case network:
        return 'Network failure';
      case timeout:
        return 'Operation timeout';
      case reject:
        return 'Operation rejected';
      case busy:
        return 'System is busy';
      case exist:
        return 'Resource already exists';
      case noExist:
        return 'Resource does not exist';
      default:
        return 'Unknown error: $code';
    }
  }
}

/// 事件ID定义
class PgTunnelEvent {
  static const int exit = 0;
  static const int error = 1;
  static const int login = 2;
  static const int logout = 3;
  static const int kickout = 4;
  static const int peerUp = 5;
  static const int peerDown = 6;
  static const int peerOffline = 7;
  static const int connectAdd = 8;
  static const int connectDelete = 9;
  static const int connectUp = 10;
  static const int connectDown = 11;
  static const int serverPush = 12;
  static const int peerInfo = 13;
  static const int connectUsed = 14;
  static const int peerFwdStatus = 15;
  static const int peerFwdStatistic = 16;
  static const int peerFwdStatUsed = 17;
  static const int sessionFailed = 18;
  static const int peerAuthRequest = 19;
  static const int peerAuthResult = 20;
  static const int sessionStatistic = 21;
  static const int peerStatistic = 22;
  static const int relayError = 23;

  static String getEventName(int eventId) {
    switch (eventId) {
      case exit:
        return 'EXIT';
      case error:
        return 'ERROR';
      case login:
        return 'LOGIN';
      case logout:
        return 'LOGOUT';
      case kickout:
        return 'KICKOUT';
      case peerUp:
        return 'PEER_UP';
      case peerDown:
        return 'PEER_DOWN';
      case peerOffline:
        return 'PEER_OFFLINE';
      case connectAdd:
        return 'CONNECT_ADD';
      case connectDelete:
        return 'CONNECT_DELETE';
      case connectUp:
        return 'CONNECT_UP';
      case connectDown:
        return 'CONNECT_DOWN';
      default:
        return 'UNKNOWN_EVENT';
    }
  }
}

/// 版本信息结构体
final class PgTunnelVersion extends Struct {
  @Array(64)
  external Array<Int8> szVersion;

  String get version => _readCString(szVersion, 64);
}

/// 状态信息结构体
final class PgTunnelStatus extends Struct {
  @Uint32()
  external int uStatus;
}

/// 域名称结构体
final class PgTunnelDomain extends Struct {
  @Array(128)
  external Array<Int8> szDomain;

  String get domain => _readCString(szDomain, 128);
}

/// 客户端说明结构体
final class PgTunnelComment extends Struct {
  @Array(256)
  external Array<Int8> szComment;

  String get comment => _readCString(szComment, 256);
}

/// 客户端连接地址端口信息结构体
final class PgTunnelClientAddr extends Struct {
  @Array(128)
  external Array<Int8> szClientAddr;

  String get clientAddr => _readCString(szClientAddr, 128);
}

/// P2P通道信息结构体
final class PgTunnelPeerInfo extends Struct {
  @Array(128)
  external Array<Int8> szPeerID;
  @Uint32()
  external int uCnntType;
  @Array(128)
  external Array<Int8> szPeerAddr;
  @Uint32()
  external int uTunnelCount;

  String get peerId => _readCString(szPeerID, 128);
  String get peerAddr => _readCString(szPeerAddr, 128);
}

/// 隧道连接信息结构体
final class PgTunnelConnectInfo extends Struct {
  @Array(128)
  external Array<Int8> szPeerID;
  @Uint32()
  external int uType;
  @Uint32()
  external int uEncrypt;
  @Array(128)
  external Array<Int8> szListenAddr;
  @Array(128)
  external Array<Int8> szClientAddr;
  @Uint32()
  external int uCnntType;
  @Array(128)
  external Array<Int8> szPeerAddr;

  String get peerId => _readCString(szPeerID, 128);
  String get listenAddr => _readCString(szListenAddr, 128);
  String get clientAddr => _readCString(szClientAddr, 128);
  String get peerAddr => _readCString(szPeerAddr, 128);
}

/// 本端用户ID结构体
final class PgTunnelSelf extends Struct {
  @Array(128)
  external Array<Int8> szSelfID;

  String get selfId => _readCString(szSelfID, 128);
}

/// 数据结构体
final class PgTunnelData extends Struct {
  @Array(4096)
  external Array<Int8> szData;

  String get data => _readCString(szData, 4096);
}

/// 调试输出回调函数类型
typedef DebugOutNative = Void Function(Uint32 uLevel, Pointer<Utf8> lpszOut);
typedef DebugOutDart = void Function(int uLevel, Pointer<Utf8> lpszOut);

/// 事件回调函数类型
typedef TunnelEventProcNative = Void Function(
    Uint32 uEvent, Pointer<Utf8> lpszParam);
typedef TunnelEventProcDart = void Function(
    int uEvent, Pointer<Utf8> lpszParam);