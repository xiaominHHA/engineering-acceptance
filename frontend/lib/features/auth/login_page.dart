import 'package:flutter/material.dart';

import '../../models/user.dart';
import 'auth_widgets.dart';
import 'login_view_model.dart';
import 'register_page.dart';
import 'register_view_model.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.viewModel,
    required this.createRegisterViewModel,
    required this.onLogin,
  });

  final LoginViewModel viewModel;
  final RegisterViewModel Function() createRegisterViewModel;
  final ValueChanged<User> onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final username = TextEditingController();
  final password = TextEditingController();
  final passwordFocus = FocusNode();
  bool obscurePassword = true;

  Future<void> submit() async {
    if (widget.viewModel.isSubmitting ||
        !(formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    final user = await widget.viewModel.login(
      username.text.trim(),
      password.text,
    );
    if (mounted && user != null) widget.onLogin(user);
  }

  Future<void> openRegistration() async {
    widget.viewModel.clearError();
    final viewModel = widget.createRegisterViewModel();
    final user = await Navigator.of(context).push<User>(
      MaterialPageRoute(builder: (_) => RegisterPage(viewModel: viewModel)),
    );
    viewModel.dispose();
    if (mounted && user != null) widget.onLogin(user);
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    passwordFocus.dispose();
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
                          const AuthIdentity(description: '登录后管理资料并参与校园论坛'),
                          const SizedBox(height: 32),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    '欢迎回来',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '使用注册时设置的登录用户名和密码',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: username,
                                    keyboardType: TextInputType.text,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    autofillHints: const [
                                      AutofillHints.username,
                                    ],
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) =>
                                        passwordFocus.requestFocus(),
                                    decoration: const InputDecoration(
                                      labelText: '登录用户名',
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                    validator: (value) =>
                                        (value?.trim().isEmpty ?? true)
                                        ? '登录用户名不能为空'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: password,
                                    focusNode: passwordFocus,
                                    obscureText: obscurePassword,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => submit(),
                                    decoration: InputDecoration(
                                      labelText: '密码',
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
                                    validator: (value) =>
                                        (value?.isEmpty ?? true)
                                        ? '密码不能为空'
                                        : null,
                                  ),
                                  if (widget.viewModel.errorMessage
                                      case final message?) ...[
                                    const SizedBox(height: 16),
                                    AuthErrorMessage(message: message),
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
                                        : const Text('登录'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: widget.viewModel.isSubmitting
                                ? null
                                : openRegistration,
                            child: const Text('没有账号？创建账号'),
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
