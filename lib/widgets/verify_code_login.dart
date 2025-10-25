// widgets/verify_code_login.dart
import 'package:flutter/material.dart';

class VerifyCodeLogin extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController verifyCodeController;
  final int countdown;
  final VoidCallback onGetVerifyCode;

  const VerifyCodeLogin({
    super.key,
    required this.phoneController,
    required this.verifyCodeController,
    required this.countdown,
    required this.onGetVerifyCode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 手机号输入
        TextField(
          controller: phoneController,
          decoration: InputDecoration(
            hintText: '请输入手机号',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
          keyboardType: TextInputType.phone,
        ),

        const SizedBox(height: 20),

        // 验证码输入
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: verifyCodeController,
                decoration: InputDecoration(
                  hintText: '请输入验证码',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: countdown > 0 ? null : onGetVerifyCode,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              child: Text(
                countdown > 0 ? '${countdown}s' : '获取验证码',
                style: TextStyle(
                  color: countdown > 0 ? Colors.grey : Colors.orange,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
