// widgets/verify_code_login.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VerifyCodeLogin extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController verifyCodeController;
  final int countdown;
  final String? phoneErrorText;  // 🆕 手机号错误提示
  final String? verifyCodeErrorText;  // 🆕 验证码错误提示
  final VoidCallback onGetVerifyCode;

  const VerifyCodeLogin({
    super.key,
    required this.phoneController,
    required this.verifyCodeController,
    required this.countdown,
    this.phoneErrorText,  // 🆕
    this.verifyCodeErrorText,  // 🆕
    required this.onGetVerifyCode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 手机号输入框
        TextField(
          controller: phoneController,
          // 🆕 添加输入格式限制
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,  // 只允许数字
            LengthLimitingTextInputFormatter(11),     // 限制长度为11
          ],
          keyboardType: TextInputType.number,  // 数字键盘
          decoration: InputDecoration(
            labelText: '手机号',
            hintText: '请输入手机号',
            prefixIcon: const Icon(Icons.phone_android),
            // 🆕 显示错误提示
            errorText: phoneErrorText,
            errorStyle: const TextStyle(
              fontSize: 12,
              height: 0.8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: phoneErrorText != null ? Colors.red : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: phoneErrorText != null ? Colors.red : Colors.orange,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Colors.red,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 验证码输入框
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: verifyCodeController,
                // 🆕 添加输入格式限制
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,  // 只允许数字
                  LengthLimitingTextInputFormatter(6),     // 限制长度为6
                ],
                keyboardType: TextInputType.number,  // 数字键盘
                decoration: InputDecoration(
                  labelText: '验证码',
                  hintText: '请输入验证码',
                  prefixIcon: const Icon(Icons.message_outlined),
                  // 🆕 显示错误提示
                  errorText: verifyCodeErrorText,
                  errorStyle: const TextStyle(
                    fontSize: 12,
                    height: 0.8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: verifyCodeErrorText != null ? Colors.red : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: verifyCodeErrorText != null ? Colors.red : Colors.orange,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.red,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.red,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 获取验证码按钮
            ElevatedButton(
              onPressed: countdown > 0 ? null : onGetVerifyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                countdown > 0 ? '${countdown}s' : '获取验证码',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }
}