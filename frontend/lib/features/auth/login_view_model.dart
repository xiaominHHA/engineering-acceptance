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

  Future<User?> login(String username, String password) async {
    if (isSubmitting) return null;
    isSubmitting = true;
    errorMessage = null;
    _notify();
    try {
      return await _repository.login(username, password);
    } on AppFailure catch (failure) {
      errorMessage = _messageFor(failure);
      return null;
    } catch (_) {
      errorMessage = '登录失败，请稍后重试';
      return null;
    } finally {
      isSubmitting = false;
      _notify();
    }
  }

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    _notify();
  }

  void showSessionExpired() {
    errorMessage = '登录已失效，请重新登录';
    _notify();
  }

  void showRestoreFailure(AppFailure failure) {
    errorMessage = switch (failure.type) {
      AppFailureType.network => '无法恢复登录状态，请检查网络后重新登录',
      AppFailureType.server => '服务器暂时无法验证登录状态，请稍后重试',
      _ => '无法恢复登录状态，请重新登录',
    };
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String _messageFor(AppFailure failure) => switch (failure.type) {
    AppFailureType.invalidCredentials => '登录用户名或密码错误',
    AppFailureType.validation => '请检查登录用户名和密码',
    AppFailureType.network => '无法连接服务器，请检查网络后重试',
    AppFailureType.server => '服务器暂时无法处理登录，请稍后重试',
    _ => '登录失败，请稍后重试',
  };
}
