// widgets/qr_code_login.dart
import 'package:flutter/material.dart';

class QRCodeLogin extends StatelessWidget {
  const QRCodeLogin({super.key});

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
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.network(
              'https://api.qrserver.com/v1/create-qr-code/?size=280x280&data=LoginQRCode',
              fit: BoxFit.cover,
            ),
          ),
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