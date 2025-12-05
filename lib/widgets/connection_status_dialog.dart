// widgets/connection_status_dialog.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../user/provider/mine_provider.dart';
import '../user/my_instance.dart';
import '../p2p/pg_tunnel_service.dart';
import '../services/transfer_speed_service.dart';

/// 连接状态弹窗
class ConnectionStatusDialog extends StatefulWidget {
  const ConnectionStatusDialog({super.key});

  @override
  State<ConnectionStatusDialog> createState() => _ConnectionStatusDialogState();
}

class _ConnectionStatusDialogState extends State<ConnectionStatusDialog> {
  // 网络状态
  bool _isNetworkConnected = false;
  StreamSubscription? _connectivitySubscription;

  // 各项状态
  bool _isLoading = true;
  bool _serverConnected = false;
  bool _deviceConnected = false;
  bool _deviceStatusOk = true;
  bool _p2pConnected = true;
  String _p2pConnectionType = '';

  // 速度
  String _uploadSpeed = '0B/s';
  String _downloadSpeed = '0B/s';
  late final TransferSpeedService _speedService;

  @override
  void initState() {
    super.initState();
    _speedService = TransferSpeedService.instance;
    _speedService.addListener(_onSpeedChanged);
    _initNetworkListener();
    _updateSpeedDisplay();
    _checkAllStatus();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _speedService.removeListener(_onSpeedChanged);
    super.dispose();
  }

  /// 速度变化回调
  void _onSpeedChanged() {
    if (mounted) {
      _updateSpeedDisplay();
    }
  }

  /// 更新速度显示
  void _updateSpeedDisplay() {
    setState(() {
      _uploadSpeed = _speedService.formattedUploadSpeed;
      _downloadSpeed = _speedService.formattedDownloadSpeed;
    });
  }

  /// 初始化网络监听
  void _initNetworkListener() async {
    try {
      // 先检查当前状态
      final result = await Connectivity().checkConnectivity();
      _updateNetworkStatus(result);

      // 监听变化
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
        if (mounted) {
          _updateNetworkStatus(result);
        }
      });
    } catch (e) {
      debugPrint('初始化网络监听失败: $e');
    }
  }

  void _updateNetworkStatus(List<ConnectivityResult> result) {
    final isConnected = result.isNotEmpty && !result.contains(ConnectivityResult.none);
    if (mounted) {
      setState(() {
        _isNetworkConnected = isConnected;
      });
    }
  }

  /// 检查所有状态
  Future<void> _checkAllStatus() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 串行检查，避免并发问题导致崩溃
      final serverStatus = await _checkServerStatus();
      if (!mounted) return;

      final deviceStatus = await _checkDeviceStatus();
      if (!mounted) return;

      // final deviceLoginStatus = await _checkDeviceLoginStatus();
      // if (!mounted) return;

      // final p2pStatus = await _checkP2pStatus();
      // if (!mounted) return;

      setState(() {
        _serverConnected = serverStatus;
        _deviceConnected = deviceStatus;
        // _deviceStatusOk = deviceLoginStatus;
        // _p2pConnected = p2pStatus['isConnected'] ?? false;
        // _p2pConnectionType = p2pStatus['connectionType'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('检查状态失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 1. 检查服务器状态（调用 getUser 接口）
  Future<bool> _checkServerStatus() async {
    try {
      return await MyNetworkProvider().checkServerStatus();
    } catch (e) {
      debugPrint('检查服务器状态失败: $e');
      return false;
    }
  }

  /// 2. 检查亲选相册设备（调用 getUploadPath）
  Future<bool> _checkDeviceStatus() async {
    try {
      return await MyNetworkProvider().getUploadPath();
    } catch (e) {
      debugPrint('检查设备状态失败: $e');
      return false;
    }
  }

  /// 3. 检查亲选相册设备状态（调用 getLoginStatus，0表示正常）
  Future<bool> _checkDeviceLoginStatus() async {
    // try {
    //   final p2pService = PgTunnelService();
    //   if (!p2pService.isRunning) {
    //     return false;
    //   }
    //   final status = await p2pService.getLoginStatus();
    //   return status == 0; // 0 表示正常
    // } catch (e) {
    //   debugPrint('检查设备登录状态失败: $e');
    //   return false;
    // }
    return true;
  }

  /// 4. 检查 P2P 连接状态（调用 getPeerInfo，使用 deviceCode）
  Future<Map<String, dynamic>> _checkP2pStatus() async {
    try {
      final p2pService = PgTunnelService();
      if (!p2pService.isRunning) {
        return {'isConnected': false, 'connectionType': ''};
      }

      // 使用 MyInstance().deviceCode 作为参数
      final deviceCode = MyInstance().deviceCode;
      if (deviceCode.isEmpty) {
        return {'isConnected': false, 'connectionType': ''};
      }

      try {
        final peerInfo = await p2pService.getPeerInfo(deviceCode);
        return {
          'isConnected': true,
          'connectionType': peerInfo.connectionTypeName,
        };
      } catch (e) {
        debugPrint('getPeerInfo 调用失败: $e');
        return {'isConnected': false, 'connectionType': ''};
      }
    } catch (e) {
      debugPrint('检查 P2P 状态失败: $e');
      return {'isConnected': false, 'connectionType': ''};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            _buildTitleBar(),
            const SizedBox(height: 24),

            // 状态列表
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              _buildStatusRow(label: '服务器', isConnected: _serverConnected),
              const SizedBox(height: 16),
              _buildStatusRow(label: '亲选相册设备', isConnected: _deviceConnected),
              const SizedBox(height: 16),
              _buildStatusRow(label: '亲选相册设备状态', isConnected: _deviceStatusOk),
              const SizedBox(height: 16),
              _buildStatusRow(
                label: '亲选相册设备P2P状态',
                isConnected: _p2pConnected,
                extraInfo: _p2pConnectionType.isNotEmpty ? _p2pConnectionType : null,
              ),
              const SizedBox(height: 24),
              _buildSpeedRow(),
            ],

            const SizedBox(height: 16),

            // 刷新按钮
            Center(
              child: TextButton.icon(
                onPressed: _isLoading ? null : _checkAllStatus,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('刷新状态'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildTitleBar() {
    return Row(
      children: [
        const Text(
          '连接状态',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 16),
        // 网络状态指示器
        _buildNetworkIndicator(),
        const Spacer(),
        // 关闭按钮
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          iconSize: 24,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  /// 构建网络状态指示器
  Widget _buildNetworkIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _isNetworkConnected
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isNetworkConnected ? Icons.wifi : Icons.wifi_off,
            size: 16,
            color: _isNetworkConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            _isNetworkConnected ? '网络已连接' : '网络未连接',
            style: TextStyle(
              fontSize: 12,
              color: _isNetworkConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建状态行
  Widget _buildStatusRow({
    required String label,
    required bool isConnected,
    String? extraInfo,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // 橙色标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFFF9800),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          // 状态文字
          Text(
            isConnected ? '已连接' : '未连接',
            style: TextStyle(
              fontSize: 15,
              color: isConnected ? Colors.black87 : Colors.red,
            ),
          ),
          // 额外信息（如连接类型）
          if (extraInfo != null && extraInfo.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              '($extraInfo)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(width: 16),
          // 状态图标
          _buildStatusIcon(isConnected),
        ],
      ),
    );
  }

  /// 构建状态图标
  Widget _buildStatusIcon(bool isConnected) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isConnected ? Colors.green : Colors.transparent,
        border: Border.all(
          color: isConnected ? Colors.green : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: isConnected
          ? const Icon(Icons.check, size: 18, color: Colors.white)
          : null,
    );
  }

  /// 构建速度行
  Widget _buildSpeedRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // 标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '上传/下载速度',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFFF9800),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          // 上传速度
          const Icon(Icons.upload, size: 16, color: Colors.green),
          const SizedBox(width: 4),
          Text(
            _uploadSpeed,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 24),
          // 下载速度
          const Icon(Icons.download, size: 16, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            _downloadSpeed,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 显示连接状态弹窗的快捷方法
void showConnectionStatusDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (context) => const ConnectionStatusDialog(),
  );
}