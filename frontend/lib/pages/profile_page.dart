import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.api,
    required this.user,
    required this.onUpdate,
  });
  final ApiService api;
  final User user;
  final ValueChanged<User> onUpdate;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final nickname = TextEditingController(text: widget.user.nickname);
  late final birthday = TextEditingController(text: widget.user.birthday ?? '');
  late final school = TextEditingController(text: widget.user.school ?? '');
  late final className = TextEditingController(
    text: widget.user.className ?? '',
  );
  Future<void> save() async {
    final user = await widget.api.updateUser(
      widget.user,
      nickname: nickname.text,
      birthday: birthday.text.isEmpty ? null : birthday.text,
      school: school.text,
      className: className.text,
    );
    widget.onUpdate(user);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存')));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('账号：${widget.user.username}'),
      TextField(
        controller: nickname,
        decoration: const InputDecoration(labelText: '昵称'),
      ),
      TextField(
        controller: birthday,
        decoration: const InputDecoration(labelText: '生日（YYYY-MM-DD）'),
      ),
      TextField(
        controller: school,
        decoration: const InputDecoration(labelText: '学校'),
      ),
      TextField(
        controller: className,
        decoration: const InputDecoration(labelText: '班级'),
      ),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: save, child: const Text('保存资料')),
    ],
  );
}
