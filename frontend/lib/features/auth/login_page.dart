import 'package:flutter/material.dart';

import '../../models/user.dart';
import 'login_view_model.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.viewModel, required this.onLogin});

  final LoginViewModel viewModel;
  final ValueChanged<User> onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final username = TextEditingController();
  final password = TextEditingController();
  final nickname = TextEditingController();
  final usernameFocus = FocusNode();
  final passwordFocus = FocusNode();
  final nicknameFocus = FocusNode();
  bool registering = false;
  bool obscurePassword = true;

  Future<void> submit() async {
    if (widget.viewModel.isSubmitting ||
        !(formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    final user = registering
        ? await widget.viewModel.register(
            username.text.trim(),
            password.text,
            nickname.text.trim(),
          )
        : await widget.viewModel.login(username.text.trim(), password.text);
    if (mounted && user != null) widget.onLogin(user);
  }

  void switchMode() {
    setState(() => registering = !registering);
    widget.viewModel.clearError();
    formKey.currentState?.reset();
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    nickname.dispose();
    usernameFocus.dispose();
    passwordFocus.dispose();
    nicknameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AutofillGroup(
                  child: Form(
                    key: formKey,
                    child: AnimatedBuilder(
                      animation: widget.viewModel,
                      builder: (context, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Identity(registering: registering),
                          const SizedBox(height: 32),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    registering ? '创建账号' : '欢迎回来',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: username,
                                    focusNode: usernameFocus,
                                    keyboardType: TextInputType.text,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    autofillHints: const [
                                      AutofillHints.username,
                                    ],
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) => registering
                                        ? nicknameFocus.requestFocus()
                                        : passwordFocus.requestFocus(),
                                    decoration: const InputDecoration(
                                      labelText: '用户名',
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                    validator: (value) {
                                      final text = value?.trim() ?? '';
                                      if (text.isEmpty) return '用户名不能为空';
                                      if (registering && text.length > 100) {
                                        return '用户名不能超过 100 位';
                                      }
                                      return null;
                                    },
                                  ),
                                  if (registering) ...[
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: nickname,
                                      focusNode: nicknameFocus,
                                      keyboardType: TextInputType.name,
                                      autocorrect: true,
                                      enableSuggestions: true,
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: (_) =>
                                          passwordFocus.requestFocus(),
                                      decoration: const InputDecoration(
                                        labelText: '昵称',
                                        prefixIcon: Icon(Icons.badge_outlined),
                                      ),
                                      validator: (value) {
                                        final text = value?.trim() ?? '';
                                        if (text.isEmpty) return '昵称不能为空';
                                        if (text.length > 100) {
                                          return '昵称不能超过 100 位';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: password,
                                    focusNode: passwordFocus,
                                    obscureText: obscurePassword,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    autofillHints: [
                                      registering
                                          ? AutofillHints.newPassword
                                          : AutofillHints.password,
                                    ],
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => submit(),
                                    decoration: InputDecoration(
                                      labelText: '密码',
                                      helperText: registering
                                          ? '密码长度 8～72 位'
                                          : null,
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      suffixIcon: IconButton(
                                        tooltip: obscurePassword
                                            ? '显示密码'
                                            : '隐藏密码',
                                        onPressed: () => setState(
                                          () => obscurePassword =
                                              !obscurePassword,
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
                                      if (registering &&
                                          (text.length < 8 ||
                                              text.length > 72)) {
                                        return '密码长度必须为 8～72 位';
                                      }
                                      return null;
                                    },
                                  ),
                                  if (widget.viewModel.errorMessage
                                      case final message?) ...[
                                    const SizedBox(height: 16),
                                    _ErrorMessage(message: message),
                                  ],
                                  const SizedBox(height: 20),
                                  FilledButton(
                                    onPressed: widget.viewModel.isSubmitting
                                        ? null
                                        : submit,
                                    child: widget.viewModel.isSubmitting
                                        ? const SizedBox.square(
                                            dimension: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(registering ? '注册并进入' : '登录'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: widget.viewModel.isSubmitting
                                ? null
                                : switchMode,
                            child: Text(
                              registering ? '已有账号？返回登录' : '第一次使用？创建账号',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Identity extends StatelessWidget {
  const _Identity({required this.registering});

  final bool registering;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CircleAvatar(
        radius: 34,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          Icons.forum_outlined,
          size: 34,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Engineering Acceptance',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        registering ? '创建你的个人资料，加入校园论坛' : '登录后管理资料并参与校园论坛',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
