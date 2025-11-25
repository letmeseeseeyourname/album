// widgets/qr_code_login.dart
import 'package:ablumwin/utils/win_helper.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart'; // 引入二维码库
import 'package:uuid/uuid.dart'; // 示例：用于生成临时的 deviceCode
import '../services/login_service.dart';
import '../user/native_bridge.dart'; // 引入登录服务

class QRCodeLogin extends StatefulWidget {
  const QRCodeLogin({super.key});

  @override
  State<QRCodeLogin> createState() => _QRCodeLoginState();
}

class _QRCodeLoginState extends State<QRCodeLogin> {
  // 状态变量
  String? _qrCodeString;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchQrCodeData();
  }



  // 异步请求二维码数据
  Future<void> _fetchQrCodeData() async {
    try {
      // 1. 获取 deviceCode
      final deviceCode = await WinHelper.uuid();

      // 2. 调用服务接口
      final result = await LoginService.getQrCode(deviceCode);

      if (result.success && result.qrCodeData?.qrCode != null) {
        // 成功获取数据
        setState(() {
          _qrCodeString = result.qrCodeData!.qrCode;
          _isLoading = false;
        });
      } else {
        // 接口返回失败
        setState(() {
          _errorMessage = result.message ?? '获取二维码数据失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      // 网络或程序异常
      setState(() {
        _errorMessage = '获取二维码异常：${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // 构建二维码显示区域 Widget
  Widget _buildQrCodeView() {
    // 正在加载中
    if (_isLoading) {
      return const SizedBox(
        width: 200,
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // 加载失败或错误信息
    if (_errorMessage != null) {
      return Container(
        width: 200,
        height: 200,
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red.shade900),
        ),
      );
    }

    // 成功获取数据，显示 QrImageView
    if (_qrCodeString != null) {
      return Container(
        width: 200,
        height: 200,
        // 添加边框和白色背景以确保二维码清晰
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: QrImageView(
          data: _qrCodeString!, // 替换为从 API 获取的二维码数据
          version: QrVersions.auto, // 自动选择最佳版本
          size: 200.0, // 尺寸与容器匹配
          // 您可以根据需要配置二维码的颜色、眼睛样式等
          errorStateBuilder: (cxt, err) {
            return const Center(child: Text('二维码生成错误'));
          },
        ),
      );
    }

    // 默认空状态（理论上不会到达这里）
    return const SizedBox(width: 200, height: 200);
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

          // 【替换点】使用 _buildQrCodeView() 替换原来的 Image.network
          _buildQrCodeView(),

          const SizedBox(height: 20),
          Text(
            '打开APP，点击"扫一扫"，扫码登录设备',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}