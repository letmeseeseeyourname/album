import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'pg_tunnel_types.dart';

/// pgTunnelCallbackSet 函数类型
typedef PgTunnelCallbackSetNative = Void Function(
    Pointer<NativeFunction<TunnelEventProcNative>> callback);
typedef PgTunnelCallbackSetDart = void Function(
    Pointer<NativeFunction<TunnelEventProcNative>> callback);

/// pgTunnelStart 函数类型
typedef PgTunnelStartNative = Int32 Function(
    Pointer<Utf8> lpszCfgFile,
    Pointer<Utf8> lpszSysInfo,
    Uint32 uOption,
    Pointer<NativeFunction<DebugOutNative>> lpfnDebugOut,
    );
typedef PgTunnelStartDart = int Function(
    Pointer<Utf8> lpszCfgFile,
    Pointer<Utf8> lpszSysInfo,
    int uOption,
    Pointer<NativeFunction<DebugOutNative>> lpfnDebugOut,
    );

/// pgTunnelStop 函数类型
typedef PgTunnelStopNative = Void Function();
typedef PgTunnelStopDart = void Function();

/// pgTunnelVersionGet 函数类型
typedef PgTunnelVersionGetNative = Int32 Function(
    Pointer<PgTunnelVersion> lpstVersion);
typedef PgTunnelVersionGetDart = int Function(
    Pointer<PgTunnelVersion> lpstVersion);

/// pgTunnelCommentGet 函数类型
typedef PgTunnelCommentGetNative = Int32 Function(
    Pointer<PgTunnelComment> lpstComment);
typedef PgTunnelCommentGetDart = int Function(
    Pointer<PgTunnelComment> lpstComment);

/// pgTunnelStatusGet 函数类型
typedef PgTunnelStatusGetNative = Int32 Function(
    Uint32 uOption, Pointer<PgTunnelStatus> lpstStatus);
typedef PgTunnelStatusGetDart = int Function(
    int uOption, Pointer<PgTunnelStatus> lpstStatus);

/// pgTunnelConnectAdd 函数类型
typedef PgTunnelConnectAddNative = Int32 Function(
    Pointer<Utf8> lpszSession,
    Pointer<Utf8> lpszPeerID,
    Uint32 uType,
    Uint32 uEncrypt,
    Pointer<Utf8> lpszListenAddr,
    Pointer<Utf8> lpszClientAddr,
    Pointer<PgTunnelClientAddr> lpstClientAddr,
    );
typedef PgTunnelConnectAddDart = int Function(
    Pointer<Utf8> lpszSession,
    Pointer<Utf8> lpszPeerID,
    int uType,
    int uEncrypt,
    Pointer<Utf8> lpszListenAddr,
    Pointer<Utf8> lpszClientAddr,
    Pointer<PgTunnelClientAddr> lpstClientAddr,
    );

/// pgTunnelConnectDelete 函数类型
typedef PgTunnelConnectDeleteNative = Int32 Function(
    Pointer<Utf8> lpszSession,
    Pointer<Utf8> lpszPeerID,
    Uint32 uType,
    Uint32 uEncrypt,
    Pointer<Utf8> lpszListenAddr,
    Pointer<Utf8> lpszClientAddr,
    );
typedef PgTunnelConnectDeleteDart = int Function(
    Pointer<Utf8> lpszSession,
    Pointer<Utf8> lpszPeerID,
    int uType,
    int uEncrypt,
    Pointer<Utf8> lpszListenAddr,
    Pointer<Utf8> lpszClientAddr,
    );

/// pgTunnelConnectLocalDelete 函数类型
typedef PgTunnelConnectLocalDeleteNative = Int32 Function(
    Pointer<Utf8> lpszSession,
    Pointer<Utf8> lpszClientAddr,
    );
typedef PgTunnelConnectLocalDeleteDart = int Function(
    Pointer<Utf8> lpszSession,
    Pointer<Utf8> lpszClientAddr,
    );

/// pgTunnelConnectLocalQuery 函数类型
typedef PgTunnelConnectLocalQueryNative = Int32 Function(
    Pointer<Utf8> lpszClientAddr,
    Pointer<PgTunnelConnectInfo> lpstConnectInfo,
    );
typedef PgTunnelConnectLocalQueryDart = int Function(
    Pointer<Utf8> lpszClientAddr,
    Pointer<PgTunnelConnectInfo> lpstConnectInfo,
    );

/// pgTunnelPeerInfoGet 函数类型
typedef PgTunnelPeerInfoGetNative = Int32 Function(
    Pointer<Utf8> lpszPeerID,
    Pointer<PgTunnelPeerInfo> lpstPeerInfo,
    );
typedef PgTunnelPeerInfoGetDart = int Function(
    Pointer<Utf8> lpszPeerID,
    Pointer<PgTunnelPeerInfo> lpstPeerInfo,
    );

/// pgTunnelSelfGet 函数类型
typedef PgTunnelSelfGetNative = Int32 Function(
    Pointer<PgTunnelSelf> lpstSelf);
typedef PgTunnelSelfGetDart = int Function(Pointer<PgTunnelSelf> lpstSelf);

/// PgTunnel FFI Bindings
class PgTunnelBindings {
  late final DynamicLibrary _dylib;
  static PgTunnelBindings? _instance;

  PgTunnelBindings._() {
    // Load the dynamic library
    if (Platform.isWindows) {
      // 尝试多个可能的路径
      final possiblePaths = [
        'pgDllTunnel.dll', // 当前目录
        '${Directory.current.path}\\pgDllTunnel.dll',
        '${Directory.current.path}\\windows\\pgDllTunnel.dll',
      ];

      DynamicLibrary? loadedLib;
      for (final path in possiblePaths) {
        try {
          loadedLib = DynamicLibrary.open(path);
          print('Successfully loaded DLL from: $path');
          break;
        } catch (e) {
          print('Failed to load from $path: $e');
        }
      }

      if (loadedLib == null) {
        throw Exception(
            'Failed to load pgDllTunnel.dll from any known location');
      }
      _dylib = loadedLib;
    } else {
      throw UnsupportedError('This platform is not supported');
    }
  }

  factory PgTunnelBindings() {
    _instance ??= PgTunnelBindings._();
    return _instance!;
  }

  // Bind functions
  late final pgTunnelCallbackSet = _dylib.lookupFunction<
      PgTunnelCallbackSetNative,
      PgTunnelCallbackSetDart>('pgTunnelCallbackSet');

  late final pgTunnelStart = _dylib.lookupFunction<PgTunnelStartNative,
      PgTunnelStartDart>('pgTunnelStart');

  late final pgTunnelStop =
  _dylib.lookupFunction<PgTunnelStopNative, PgTunnelStopDart>(
      'pgTunnelStop');

  late final pgTunnelVersionGet = _dylib.lookupFunction<
      PgTunnelVersionGetNative,
      PgTunnelVersionGetDart>('pgTunnelVersionGet');

  late final pgTunnelCommentGet = _dylib.lookupFunction<
      PgTunnelCommentGetNative,
      PgTunnelCommentGetDart>('pgTunnelCommentGet');

  late final pgTunnelStatusGet = _dylib.lookupFunction<
      PgTunnelStatusGetNative,
      PgTunnelStatusGetDart>('pgTunnelStatusGet');

  late final pgTunnelConnectAdd = _dylib.lookupFunction<
      PgTunnelConnectAddNative,
      PgTunnelConnectAddDart>('pgTunnelConnectAdd');

  late final pgTunnelConnectDelete = _dylib.lookupFunction<
      PgTunnelConnectDeleteNative,
      PgTunnelConnectDeleteDart>('pgTunnelConnectDelete');

  late final pgTunnelConnectLocalDelete = _dylib.lookupFunction<
      PgTunnelConnectLocalDeleteNative,
      PgTunnelConnectLocalDeleteDart>('pgTunnelConnectLocalDelete');

  late final pgTunnelConnectLocalQuery = _dylib.lookupFunction<
      PgTunnelConnectLocalQueryNative,
      PgTunnelConnectLocalQueryDart>('pgTunnelConnectLocalQuery');

  late final pgTunnelPeerInfoGet = _dylib.lookupFunction<
      PgTunnelPeerInfoGetNative,
      PgTunnelPeerInfoGetDart>('pgTunnelPeerInfoGet');

  late final pgTunnelSelfGet = _dylib.lookupFunction<PgTunnelSelfGetNative,
      PgTunnelSelfGetDart>('pgTunnelSelfGet');
}