import 'package:flutter/material.dart';

import '../../models/user.dart';
import 'auth_widgets.dart';
import 'register_view_model.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.viewModel});

  final RegisterViewModel viewModel;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final formKey = GlobalKey<FormState>();
  final username = TextEditingController();
  final nickname = TextEditingController();
  final password = TextEditingController();
  final nicknameFocus = FocusNode();
  final passwordFocus = FocusNode();
  bool obscurePassword = true;

  Future<void> submit() async {
    if (widget.viewModel.isSubmitting ||
        !(formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    final user = await widget.viewModel.register(
      username.text.trim(),
      nickname.text.trim(),
      password.text,
    );
    if (!mounted || user == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('账号创建成功，以后使用「${user.username}」和密码登录')),
    );
    Navigator.of(context).pop<User>(user);
  }

  @override
  void dispose() {
    username.dispose();
    nickname.dispose();
    password.dispose();
    nicknameFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('创建账号')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const AuthIdentity(description: '登录用户名用于登录，昵称用于社区展示'),
          const SizedBox(height: 28),
          AutofillGroup(
            child: Form(
              key: formKey,
              child: AnimatedBuilder(
                animation: widget.viewModel,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: username,
                      keyboardType: TextInputType.text,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.newUsername],
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => nicknameFocus.requestFocus(),
                      decoration: const InputDecoration(
                        labelText: '登录用户名',
                        helperText: '以后使用此用户名和密码登录',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return '登录用户名不能为空';
                        if (text.length > 100) return '登录用户名不能超过 100 位';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nickname,
                      focusNode: nicknameFocus,
                      keyboardType: TextInputType.name,
                      autocorrect: true,
                      enableSuggestions: true,
                      autofillHints: const [AutofillHints.nickname],
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => passwordFocus.requestFocus(),
                      decoration: const InputDecoration(
                        labelText: '昵称',
                        helperText: '用于个人资料和论坛展示，可稍后修改',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return '昵称不能为空';
                        if (text.length > 100) return '昵称不能超过 100 位';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: password,
                      focusNode: passwordFocus,
                      obscureText: obscurePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => submit(),
                      decoration: InputDecoration(
                        labelText: '密码',
                        helperText: '8～72 位',
                        suffixIcon: IconButton(
                          tooltip: obscurePassword ? '显示密码' : '隐藏密码',
                          onPressed: () => setState(
                            () => obscurePassword = !obscurePassword,
                          ),
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final text = value ?? '';
                        if (text.isEmpty) return '密码不能为空';
                        if (text.length < 8 || text.length > 72) {
                          return '密码长度必须为 8～72 位';
                        }
                        return null;
                      },
                    ),
                    if (widget.viewModel.errorMessage case final message?) ...[
                      const SizedBox(height: 16),
                      AuthErrorMessage(message: message),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: widget.viewModel.isSubmitting ? null : submit,
                      child: widget.viewModel.isSubmitting
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('创建账号'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
