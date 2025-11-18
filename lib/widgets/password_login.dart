// widgets/password_login.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PasswordLogin extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final String? phoneErrorText;  // 🆕 手机号错误提示
  final String? passwordErrorText;  // 🆕 密码错误提示
  final VoidCallback onTogglePasswordVisibility;

  const PasswordLogin({
    super.key,
    required this.phoneController,
    required this.passwordController,
    required this.obscurePassword,
    this.phoneErrorText,  // 🆕
    this.passwordErrorText,  // 🆕
    required this.onTogglePasswordVisibility,
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

        // 密码输入框
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          // 🆕 添加输入格式限制
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),  // 只允许字母和数字
            LengthLimitingTextInputFormatter(20),  // 限制最大长度
          ],
          decoration: InputDecoration(
            labelText: '密码',
            hintText: '请输入密码',
            prefixIcon: const Icon(Icons.lock_outline),
            // 🆕 显示错误提示
            errorText: passwordErrorText,
            errorStyle: const TextStyle(
              fontSize: 12,
              height: 0.8,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: onTogglePasswordVisibility,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: passwordErrorText != null ? Colors.red : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: passwordErrorText != null ? Colors.red : Colors.orange,
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
      ],
    );
  }
}