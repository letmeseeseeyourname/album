// eventbus/p2p_events.dart

/// P2P 连接状态枚举
enum P2pConnectionStatus {
  connecting,    // 连接中
  connected,     // 连接成功
  failed,        // 连接失败
  disconnected,  // 已断开
}

/// P2P 连接事件
class P2pConnectionEvent {
  final P2pConnectionStatus status;
  final String? p2pName;
  final String? errorMessage;

  P2pConnectionEvent({
    required this.status,
    this.p2pName,
    this.errorMessage,
  });

  @override
  String toString() {
    return 'P2pConnectionEvent(status: $status, p2pName: $p2pName, error: $errorMessage)';
  }
}