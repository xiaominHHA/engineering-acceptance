import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.api, required this.onLogin});
  final ApiService api;
  final ValueChanged<User> onLogin;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final username = TextEditingController();
  final password = TextEditingController();
  final nickname = TextEditingController();
  bool registering = false;
  String? error;
  Future<void> submit() async {
    try {
      final user = registering
          ? await widget.api.register(
              username.text,
              password.text,
              nickname.text,
            )
          : await widget.api.login(username.text, password.text);
      if (mounted) widget.onLogin(user);
    } catch (_) {
      if (mounted) setState(() => error = '请求失败，请检查输入和后端地址');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Engineering Acceptance')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          TextField(
            controller: username,
            decoration: const InputDecoration(labelText: '用户名'),
          ),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: '密码'),
          ),
          if (registering)
            TextField(
              controller: nickname,
              decoration: const InputDecoration(labelText: '昵称'),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: submit,
            child: Text(registering ? '注册' : '登录'),
          ),
          TextButton(
            onPressed: () => setState(() {
              registering = !registering;
              error = null;
            }),
            child: Text(registering ? '已有账号，去登录' : '没有账号，去注册'),
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    ),
  );
}
