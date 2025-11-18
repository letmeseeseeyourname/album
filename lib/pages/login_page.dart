// pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../widgets/qr_code_login.dart';
import '../widgets/password_login.dart';
import '../widgets/verify_code_login.dart';
import '../widgets/custom_title_bar.dart';
import '../services/login_service.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  int selectedTab = 1; // 0: 扫码, 1: 密码, 2: 验证码
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final verifyCodeController = TextEditingController();
  bool agreeToTerms = true;
  bool obscurePassword = true;
  bool isLoading = false;

  int countdown = 0;
  Timer? countdownTimer;

  // 🆕 手机号错误提示
  String? phoneErrorText;
  // 🆕 密码错误提示
  String? passwordErrorText;
  // 🆕 验证码错误提示
  String? verifyCodeErrorText;

  @override
  void initState() {
    super.initState();

    // 🆕 添加输入监听器
    phoneController.addListener(_validatePhone);
    passwordController.addListener(_validatePassword);
    verifyCodeController.addListener(_validateVerifyCode);

    Future.delayed(Duration(seconds: 1), () {
      phoneController.text = "15323783167";
      passwordController.text = "123456";
    });
  }


  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    verifyCodeController.dispose();
    countdownTimer?.cancel();
    super.dispose();
  }

  // 🆕 实时验证手机号
  void _validatePhone() {
    final phone = phoneController.text;
    setState(() {
      if (phone.isEmpty) {
        phoneErrorText = null;
      } else if (phone.length < 11) {
        phoneErrorText = '手机号应为11位';
      } else if (!isValidPhone(phone)) {
        phoneErrorText = '手机号格式不正确';
      } else {
        phoneErrorText = null;
      }
    });
  }

  // 🆕 实时验证密码
  void _validatePassword() {
    final password = passwordController.text;
    setState(() {
      if (password.isEmpty) {
        passwordErrorText = null;
      } else if (password.length < 6) {
        passwordErrorText = '密码至少6位';
      } else if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(password)) {
        passwordErrorText = '密码只能包含字母和数字';
      } else {
        passwordErrorText = null;
      }
    });
  }

  // 🆕 实时验证验证码
  void _validateVerifyCode() {
    final code = verifyCodeController.text;
    setState(() {
      if (code.isEmpty) {
        verifyCodeErrorText = null;
      } else if (code.length < 4) {
        verifyCodeErrorText = '验证码应为4-6位';
      } else if (!RegExp(r'^[0-9]+$').hasMatch(code)) {
        verifyCodeErrorText = '验证码只能包含数字';
      } else {
        verifyCodeErrorText = null;
      }
    });
  }

  bool isValidPhone(String phone) {
    if (phone.isEmpty) return false;
    final regex = RegExp(r'^1[3-9]\d{9}$');
    return regex.hasMatch(phone);
  }

  void startCountdown() {
    setState(() {
      countdown = 60;
    });

    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (countdown > 0) {
          countdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void handleGetVerifyCode() async {
    final phone = phoneController.text.trim();

    if (!isValidPhone(phone)) {
      showErrorDialog('请输入有效的手机号码');
      return;
    }

    // 调用真实的发送验证码接口
    try {
      final result = await LoginService.sendVerifyCode(phone);

      if (result.success) {
        startCountdown();
        showSuccessDialog(result.message);
      } else {
        showErrorDialog(result.message);
      }
    } catch (e) {
      showErrorDialog('验证码发送失败，请稍后重试');
    }
  }

  void handleLogin() async {
    final phone = phoneController.text.trim();

    // 检查手机号
    if (!isValidPhone(phone)) {
      showErrorDialog('请输入有效的手机号码');
      return;
    }

    // 检查密码或验证码
    if (selectedTab == 1) {
      if (passwordController.text.isEmpty) {
        showErrorDialog('请输入密码');
        return;
      }
      if (passwordController.text.length < 6) {
        showErrorDialog('密码至少6位');
        return;
      }
    } else if (selectedTab == 2) {
      if (verifyCodeController.text.isEmpty) {
        showErrorDialog('请输入验证码');
        return;
      }
      if (verifyCodeController.text.length < 4) {
        showErrorDialog('验证码长度不正确');
        return;
      }
    }

    // 检查隐私条款
    if (!agreeToTerms) {
      showErrorDialog('请阅读并同意用户协议和隐私政策');
      return;
    }

    // 调用真实的登录接口
    setState(() {
      isLoading = true;
    });

    try {
      LoginResult result;

      if (selectedTab == 1) {
        // 密码登录
        result = await LoginService.loginWithPassword(
          phone,
          passwordController.text,
        );
      } else {
        // 验证码登录
        result = await LoginService.loginWithVerifyCode(
          phone,
          verifyCodeController.text,
        );
      }

      setState(() {
        isLoading = false;
      });

      if (result.success) {
        // 登录成功，跳转到主页面
        if (mounted) {
          showSuccessDialog('登录成功');

          // 延迟一下再跳转，让用户看到成功提示
          await Future.delayed(const Duration(milliseconds: 500));

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) =>  HomePage()),
            );
          }
        }
      } else {
        // 登录失败，显示错误信息
        showErrorDialog(result.message);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      showErrorDialog('登录失败，请稍后重试');
    }
  }

  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('提示'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void showSuccessDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomTitleBar(
        rightTitleBgColor: const Color(0xFFF5F5F5),
        backgroundColor:  const Color(0xFFF5F5F5),
        showToolbar: false, // 登录页面不显示工具栏
        child: Row(
          children: [
            // 左侧扫码登录区域 - flex: 2
            Expanded(
              flex: 2,
              child: Container(
                color: const Color(0xFFF5F5F5),
                child: QRCodeLogin(),
              ),
            ),

            // 中间分割线 - 不占满整个高度
            Container(
              margin: const EdgeInsets.symmetric(vertical: 80),
              width: 1,
              color: Colors.grey.shade300,
            ),

            // 右侧密码/验证码登录区域 - flex: 3
            Expanded(
              flex: 3,
              child: Container(
                color: const Color(0xFFF5F5F5),
                padding: const EdgeInsets.symmetric(horizontal: 100),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    // 标签切换
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTabButton('密码登录', 1),
                        const SizedBox(width: 40),
                        _buildTabButton('验证码登录', 2),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // 根据选择显示不同的登录表单
                    if (selectedTab == 1)
                      PasswordLogin(
                        phoneController: phoneController,
                        passwordController: passwordController,
                        obscurePassword: obscurePassword,
                        phoneErrorText: phoneErrorText,  // 🆕 传递错误提示
                        passwordErrorText: passwordErrorText,  // 🆕 传递错误提示
                        onTogglePasswordVisibility: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      )
                    else
                      VerifyCodeLogin(
                        phoneController: phoneController,
                        verifyCodeController: verifyCodeController,
                        countdown: countdown,
                        phoneErrorText: phoneErrorText,  // 🆕 传递错误提示
                        verifyCodeErrorText: verifyCodeErrorText,  // 🆕 传递错误提示
                        onGetVerifyCode: handleGetVerifyCode,
                      ),

                    const SizedBox(height: 30),

                    // 登录按钮
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C2C2C),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          '登录',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 隐私条款
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: agreeToTerms,
                          onChanged: (value) {
                            setState(() {
                              agreeToTerms = value ?? false;
                            });
                          },
                          activeColor: Colors.orange,
                        ),
                        Flexible(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('我已阅读并同意 '),
                              const Text(
                                '用户协议',
                                style: TextStyle(color: Colors.orange),
                              ),
                              const Text(' 和 '),
                              const Text(
                                '隐私政策',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String text, int index) {
    final isSelected = selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTab = index;
        });
      },
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.black : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          if (isSelected)
            Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}