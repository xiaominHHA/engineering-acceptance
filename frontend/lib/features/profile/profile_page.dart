import 'package:flutter/material.dart';

import '../../models/user.dart';
import 'profile_view_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.viewModel,
    required this.onUpdate,
  });

  final ProfileViewModel viewModel;
  final ValueChanged<User> onUpdate;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final formKey = GlobalKey<FormState>();
  late final nickname = TextEditingController(
    text: widget.viewModel.user.nickname,
  );
  late final school = TextEditingController(
    text: widget.viewModel.user.school ?? '',
  );
  late final className = TextEditingController(
    text: widget.viewModel.user.className ?? '',
  );
  late DateTime? selectedBirthday = DateTime.tryParse(
    widget.viewModel.user.birthday ?? '',
  );

  @override
  void initState() {
    super.initState();
    nickname.addListener(_fieldChanged);
    school.addListener(_fieldChanged);
    className.addListener(_fieldChanged);
  }

  void _fieldChanged() {
    if (mounted) setState(() {});
  }

  bool get hasChanges => widget.viewModel.hasChanges(
    nickname: nickname.text,
    birthday: _backendDate(selectedBirthday),
    school: school.text,
    className: className.text,
  );

  Future<void> save() async {
    if (widget.viewModel.isSaving ||
        !(formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    final user = await widget.viewModel.save(
      nickname: nickname.text.trim(),
      birthday: _backendDate(selectedBirthday),
      school: _optional(school.text),
      className: _optional(className.text),
    );
    if (!mounted || widget.viewModel.sessionExpired) return;
    if (user != null) {
      _applyUser(user);
      widget.onUpdate(user);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.viewModel.errorMessage ?? '保存失败，请稍后重试')),
      );
    }
  }

  Future<void> pickBirthday() async {
    final now = DateTime.now();
    final firstDate = DateTime(1900);
    var initialDate = selectedBirthday ?? now;
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(now)) initialDate = now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: now,
      helpText: '选择生日',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null && mounted) {
      setState(() => selectedBirthday = picked);
    }
  }

  void _applyUser(User user) {
    nickname.text = user.nickname;
    school.text = user.school ?? '';
    className.text = user.className ?? '';
    setState(() => selectedBirthday = DateTime.tryParse(user.birthday ?? ''));
  }

  @override
  void dispose() {
    nickname.dispose();
    school.dispose();
    className.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _ProfileIdentity(user: widget.viewModel.user),
          const SizedBox(height: 20),
          _SectionCard(
            title: '基本资料',
            icon: Icons.person_outline,
            children: [
              TextFormField(
                controller: nickname,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '昵称'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return '昵称不能为空';
                  if (text.length > 100) return '昵称不能超过 100 位';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                key: const Key('birthday-picker'),
                borderRadius: BorderRadius.circular(14),
                onTap: widget.viewModel.isSaving ? null : pickBirthday,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '生日',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedBirthday == null
                              ? '未填写'
                              : _displayDate(selectedBirthday!),
                        ),
                      ),
                      if (selectedBirthday != null)
                        IconButton(
                          tooltip: '清除生日',
                          onPressed: widget.viewModel.isSaving
                              ? null
                              : () => setState(() => selectedBirthday = null),
                          icon: const Icon(Icons.close),
                        ),
                      const Icon(Icons.calendar_month_outlined),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '校园信息',
            icon: Icons.school_outlined,
            children: [
              TextFormField(
                controller: school,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '学校'),
                validator: (value) =>
                    (value?.trim().length ?? 0) > 150 ? '学校不能超过 150 位' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: className,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => save(),
                decoration: const InputDecoration(labelText: '班级'),
                validator: (value) =>
                    (value?.trim().length ?? 0) > 100 ? '班级不能超过 100 位' : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: widget.viewModel.isSaving || !hasChanges ? null : save,
            icon: widget.viewModel.isSaving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(widget.viewModel.isSaving ? '正在保存' : '保存资料'),
          ),
        ],
      ),
    ),
  );
}

String? _optional(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

String? _backendDate(DateTime? date) {
  if (date == null) return null;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

String _displayDate(DateTime date) => '${date.year}年${date.month}月${date.day}日';

class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            child: Text(
              user.nickname.trim().isEmpty
                  ? '?'
                  : user.nickname.trim().characters.first.toUpperCase(),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.nickname,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text('@${user.username}'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}
