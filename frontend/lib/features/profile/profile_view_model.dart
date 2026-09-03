import 'package:flutter/foundation.dart';

import '../../core/error/app_failure.dart';
import '../../models/user.dart';
import 'user_repository.dart';

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel(this._repository, this.user);

  final UserRepository _repository;
  bool _disposed = false;

  User user;
  bool isSaving = false;
  String? errorMessage;
  bool sessionExpired = false;

  bool hasChanges({
    required String nickname,
    String? birthday,
    String? school,
    String? className,
  }) =>
      nickname.trim() != user.nickname.trim() ||
      _optional(birthday) != _optional(user.birthday) ||
      _optional(school) != _optional(user.school) ||
      _optional(className) != _optional(user.className);

  Future<User?> save({
    required String nickname,
    String? birthday,
    String? school,
    String? className,
  }) async {
    if (isSaving) return null;
    isSaving = true;
    errorMessage = null;
    sessionExpired = false;
    _notify();
    try {
      user = await _repository.update(
        user.id,
        nickname: nickname,
        birthday: birthday,
        school: school,
        className: className,
      );
      return user;
    } on AppFailure catch (failure) {
      errorMessage = _messageFor(failure);
      sessionExpired = failure.type == AppFailureType.sessionExpired;
      return null;
    } catch (_) {
      errorMessage = '保存失败，请稍后重试';
      return null;
    } finally {
      isSaving = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static String? _optional(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String _messageFor(AppFailure failure) => switch (failure.type) {
    AppFailureType.validation => '资料输入不符合要求，请检查后重试',
    AppFailureType.network => '无法连接服务器，请检查网络后重试',
    AppFailureType.notFound => '用户不存在或已被删除',
    AppFailureType.sessionExpired => '登录已失效，请重新登录',
    AppFailureType.forbidden => '没有权限修改该用户资料',
    AppFailureType.server => '服务器暂时无法处理请求，请稍后重试',
    _ => '保存失败，请稍后重试',
  };
}
