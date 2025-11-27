// widgets/qr_code_login.dart
import 'dart:async';
import 'dart:convert';
import 'package:ablumwin/utils/win_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/login_service.dart';
import '../pages/home_page.dart';

class QRCodeLogin extends StatefulWidget {
  const QRCodeLogin({super.key});

  @override
  State<QRCodeLogin> createState() => _QRCodeLoginState();
}

class _QRCodeLoginState extends State<QRCodeLogin> {
  // 二维码状态枚举
  static const int _stateLoading = 0;
  static const int _stateSuccess = 1;
  static const int _stateError = 2;
  static const int _stateExpired = 3;

  // 状态变量
  String? _qrCodeString;      // 二维码显示的完整 JSON 数据
  String? _qrCodeToken;       // 从接口获取的 qrCode token
  String? _deviceCode;        // 设备唯一标识
  int _qrState = _stateLoading;
  String? _errorMessage;

  // 过期计时器
  Timer? _expireTimer;
  Timer? _pollTimer;

  // 二维码有效期（3分钟）
  static const int _qrCodeValidDuration = 180;
  int _remainingSeconds = _qrCodeValidDuration;

  // 轮询间隔（2秒）
  static const int _pollInterval = 2;

  @override
  void initState() {
    super.initState();
    _fetchQrCodeData();
  }

  @override
  void dispose() {
    _expireTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  /// 开始过期倒计时
  void _startExpireTimer() {
    _expireTimer?.cancel();
    _remainingSeconds = _qrCodeValidDuration;

    _expireTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        timer.cancel();
        _onQrCodeExpired();
      }
    });
  }

  /// 开始轮询扫码状态
  void _startPolling() {
    _pollTimer?.cancel();

    _pollTimer = Timer.periodic(const Duration(seconds: _pollInterval), (timer) async {
      if (!mounted || _qrState != _stateSuccess) {
        timer.cancel();
        return;
      }

      await _checkLoginStatus();
    });
  }

  /// 停止所有计时器
  void _stopTimers() {
    _expireTimer?.cancel();
    _pollTimer?.cancel();
  }

  /// 二维码过期处理
  void _onQrCodeExpired() {
    _stopTimers();
    if (mounted) {
      setState(() {
        _qrState = _stateExpired;
      });
    }
  }

  /// 检查扫码登录状态
  Future<void> _checkLoginStatus() async {
    if (_deviceCode == null) return;

    try {
      final result = await LoginService.p6useQRLogin(_deviceCode!);

      if (!mounted) return;

      if (result.success) {
        _stopTimers();
        // 登录成功，跳转到主页
        _showSuccessAndNavigate();
      }
      // 如果返回失败，继续轮询（可能用户还未扫码或未确认）
    } catch (e) {
      debugPrint('轮询扫码状态异常: $e');
    }
  }

  /// 显示成功提示并跳转
  void _showSuccessAndNavigate() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('登录成功'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      }
    });
  }

  /// 异步请求二维码数据
  Future<void> _fetchQrCodeData() async {
    setState(() {
      _qrState = _stateLoading;
      _errorMessage = null;
    });

    try {
      // 获取设备唯一标识
      final deviceCode = await WinHelper.uuid();
      _deviceCode = deviceCode;

      // 调用接口获取 qrCode
      final result = await LoginService.getQrCode(deviceCode);

      if (!mounted) return;

      if (result.success && result.qrCodeData?.qrCode != null) {
        _qrCodeToken = result.qrCodeData!.qrCode;

        // 生成二维码内容：JSON 格式 {"deviceCode":"xxx","qrCode":"xxx"}
        final qrData = {
          "deviceCode": deviceCode,
          "qrCode": _qrCodeToken,
        };

        setState(() {
          _qrCodeString = json.encode(qrData);
          _qrState = _stateSuccess;
        });

        // 启动过期计时器和轮询
        _startExpireTimer();
        _startPolling();
      } else {
        setState(() {
          _errorMessage = result.message ?? '获取二维码数据失败';
          _qrState = _stateError;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '网络异常，请检查网络连接';
        _qrState = _stateError;
      });
    }
  }

  /// 刷新二维码
  void _refreshQrCode() {
    _stopTimers();
    _fetchQrCodeData();
  }

  /// 构建二维码显示区域
  Widget _buildQrCodeView() {
    switch (_qrState) {
      case _stateLoading:
        return _buildLoadingView();
      case _stateError:
        return _buildErrorView();
      case _stateExpired:
        return _buildExpiredView();
      case _stateSuccess:
      default:
        return _buildQrCodeWithLogo();
    }
  }

  /// 加载中状态
  Widget _buildLoadingView() {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFFFF9800),
            ),
            SizedBox(height: 16),
            Text(
              '正在生成二维码...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 错误状态 - 可点击重试
  Widget _buildErrorView() {
    return GestureDetector(
      onTap: _refreshQrCode,
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? '加载失败',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    '点击重试',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 过期状态 - 显示遮罩和刷新按钮
  Widget _buildExpiredView() {
    return GestureDetector(
      onTap: _refreshQrCode,
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 底层：模糊的二维码
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.grey.shade600,
                  BlendMode.saturation,
                ),
                child: Container(
                  width: 220,
                  height: 220,
                  color: Colors.white,
                  child: _qrCodeString != null
                      ? QrImageView(
                    data: _qrCodeString!,
                    version: QrVersions.auto,
                    size: 220,
                  )
                      : const SizedBox(),
                ),
              ),
            ),
            // 遮罩层
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo 刷新图标
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '二维码已过期',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '点击刷新',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 二维码成功状态 - 带Logo
  Widget _buildQrCodeWithLogo() {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 二维码
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: QrImageView(
              data: _qrCodeString!,
              version: QrVersions.auto,
              size: 200,
              // 设置二维码纠错级别为高，以便中间放logo后仍可识别
              errorCorrectionLevel: QrErrorCorrectLevel.H,
              errorStateBuilder: (context, error) {
                return const Center(
                  child: Text('二维码生成错误'),
                );
              },
            ),
          ),
          // 中间 Logo
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SvgPicture.asset(
                'assets/icons/logo.svg',
                width: 37,
                height: 37,
                fit: BoxFit.contain,
                placeholderBuilder: (context) => Container(
                  color: const Color(0xFFFF9800),
                  child: const Icon(
                    Icons.home,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化剩余时间
  String _formatRemainingTime() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '扫码登录',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 40),

          // 二维码区域
          _buildQrCodeView(),

          const SizedBox(height: 20),

          Text(
            '打开APP，点击"扫一扫"，扫码登录设备',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),

          // 刷新按钮（仅在出错时显示）
          if (_qrState == _stateError) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _refreshQrCode,
              icon: Icon(
                Icons.refresh,
                size: 18,
                color: Colors.grey.shade600,
              ),
              label: Text(
                '重新获取',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}