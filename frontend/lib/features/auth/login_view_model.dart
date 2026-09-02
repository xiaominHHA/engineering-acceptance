import 'package:flutter/foundation.dart';

import '../../core/error/app_failure.dart';
import '../../models/user.dart';
import 'auth_repository.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._repository);

  final AuthRepository _repository;
  bool _disposed = false;

  bool isSubmitting = false;
  String? errorMessage;

  Future<User?> login(String username, String password) =>
      _submit(() => _repository.login(username, password), registering: false);

  Future<User?> register(String username, String password, String nickname) =>
      _submit(
        () => _repository.register(username, password, nickname),
        registering: true,
      );

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    _notify();
  }

  void showSessionExpired() {
    errorMessage = '登录已失效，请重新登录';
    _notify();
  }

  Future<User?> _submit(
    Future<User> Function() request, {
    required bool registering,
  }) async {
    if (isSubmitting) return null;
    isSubmitting = true;
    errorMessage = null;
    _notify();
    try {
      return await request();
    } on AppFailure catch (failure) {
      errorMessage = _messageFor(failure, registering: registering);
      return null;
    } catch (_) {
      errorMessage = '操作失败，请稍后重试';
      return null;
    } finally {
      isSubmitting = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String _messageFor(AppFailure failure, {required bool registering}) =>
      switch (failure.type) {
        AppFailureType.invalidCredentials =>
          registering ? '没有权限执行此操作' : '用户名或密码错误',
        AppFailureType.usernameExists =>
          registering ? '用户名已存在，请更换用户名' : '请求发生冲突，请稍后重试',
        AppFailureType.sessionExpired => '登录已失效，请重新登录',
        AppFailureType.forbidden => '没有权限执行此操作',
        AppFailureType.validation => '输入不符合要求，请检查后重试',
        AppFailureType.network => '无法连接服务器，请检查网络后重试',
        AppFailureType.notFound => '请求的内容不存在',
        AppFailureType.server => '服务器暂时无法处理请求，请稍后重试',
        AppFailureType.unknown => '操作失败，请稍后重试',
      };
}
