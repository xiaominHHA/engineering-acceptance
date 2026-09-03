import 'package:flutter/foundation.dart';

import '../../core/error/app_failure.dart';
import '../../models/user.dart';
import 'auth_repository.dart';

class RegisterViewModel extends ChangeNotifier {
  RegisterViewModel(this._repository);

  final AuthRepository _repository;
  bool _disposed = false;
  bool isSubmitting = false;
  String? errorMessage;

  Future<User?> register(
    String username,
    String nickname,
    String password,
  ) async {
    if (isSubmitting) return null;
    isSubmitting = true;
    errorMessage = null;
    _notify();
    try {
      return await _repository.register(username, password, nickname);
    } on AppFailure catch (failure) {
      errorMessage = switch (failure.type) {
        AppFailureType.usernameExists => '登录用户名已存在，请更换后重试',
        AppFailureType.validation => '注册信息不符合要求，请检查后重试',
        AppFailureType.network => '无法连接服务器，请检查网络后重试',
        AppFailureType.server => '服务器暂时无法创建账号，请稍后重试',
        _ => '注册失败，请稍后重试',
      };
      return null;
    } catch (_) {
      errorMessage = '注册失败，请稍后重试';
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
}
