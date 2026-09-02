import 'package:flutter/material.dart';

import '../../models/post.dart';
import 'forum_view_model.dart';

class ForumPage extends StatefulWidget {
  const ForumPage({super.key, required this.viewModel, this.currentUserId});

  final ForumViewModel viewModel;
  final int? currentUserId;

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final content = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.viewModel.load();
  }

  Future<void> openComposer() async {
    widget.viewModel.clearPublishError();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => AnimatedBuilder(
        animation: widget.viewModel,
        builder: (context, _) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '发布新帖子',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '分享一段值得交流的校园内容',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: title,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: '标题'),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return '标题不能为空';
                      if (text.length > 200) return '标题不能超过 200 位';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: content,
                    minLines: 4,
                    maxLines: 8,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: '内容',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return '内容不能为空';
                      if (text.length > 10000) return '内容不能超过 10000 位';
                      return null;
                    },
                  ),
                  if (widget.viewModel.publishErrorMessage
                      case final message?) ...[
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: widget.viewModel.isPublishing
                        ? null
                        : () => publish(sheetContext),
                    icon: widget.viewModel.isPublishing
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(
                      widget.viewModel.isPublishing ? '正在发布' : '发布帖子',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> publish(BuildContext sheetContext) async {
    if (widget.viewModel.isPublishing ||
        !(formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(sheetContext).unfocus();
    final published = await widget.viewModel.publish(
      title.text.trim(),
      content.text.trim(),
    );
    if (!mounted || widget.viewModel.sessionExpired) return;
    if (published) {
      title.clear();
      content.clear();
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('发布成功')));
    }
  }

  @override
  void dispose() {
    title.dispose();
    content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    floatingActionButton: FloatingActionButton.extended(
      onPressed: widget.viewModel.isPublishing ? null : openComposer,
      icon: const Icon(Icons.edit_outlined),
      label: const Text('发布'),
    ),
    body: AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) => RefreshIndicator(
        onRefresh: widget.viewModel.load,
        child: _buildFeed(context),
      ),
    ),
  );

  Widget _buildFeed(BuildContext context) {
    if (widget.viewModel.loadState == ForumLoadState.loading) {
      return const _ScrollableState(child: CircularProgressIndicator());
    }
    if (widget.viewModel.loadState == ForumLoadState.failure) {
      return _ScrollableState(
        child: _StateMessage(
          icon: Icons.cloud_off_outlined,
          title: '帖子暂时加载失败',
          message: widget.viewModel.loadErrorMessage ?? '请稍后重试',
          action: TextButton.icon(
            onPressed: widget.viewModel.load,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ),
      );
    }
    if (widget.viewModel.loadState == ForumLoadState.empty) {
      return const _ScrollableState(
        child: _StateMessage(
          icon: Icons.forum_outlined,
          title: '还没有帖子',
          message: '成为第一个分享校园内容的人吧',
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount:
          widget.viewModel.posts.length +
          (widget.viewModel.loadErrorMessage == null ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (widget.viewModel.loadErrorMessage != null && index == 0) {
          return _RefreshWarning(
            message: widget.viewModel.loadErrorMessage!,
            onRetry: widget.viewModel.load,
          );
        }
        final postIndex =
            index - (widget.viewModel.loadErrorMessage == null ? 0 : 1);
        return _PostCard(
          post: widget.viewModel.posts[postIndex],
          isCurrentUser:
              widget.viewModel.posts[postIndex].authorUserId ==
              widget.currentUserId,
        );
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.isCurrentUser});

  final Post post;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                child: Icon(
                  isCurrentUser ? Icons.person : Icons.person_outline,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isCurrentUser ? '我' : '社区用户',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (post.createdAt case final createdAt?)
                Text(
                  _formatTime(createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            post.title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(post.content, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    ),
  );

  static String _formatTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.month}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _ScrollableState extends StatelessWidget {
  const _ScrollableState({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(
          height: (constraints.maxHeight - 48)
              .clamp(180.0, double.infinity)
              .toDouble(),
          child: Center(child: child),
        ),
      ],
    ),
  );
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
      const SizedBox(height: 16),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      if (action case final value?) ...[const SizedBox(height: 8), value],
    ],
  );
}

class _RefreshWarning extends StatelessWidget {
  const _RefreshWarning({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.sync_problem_outlined),
          const SizedBox(width: 10),
          Expanded(child: Text('$message，已保留现有帖子')),
          IconButton(
            tooltip: '重试刷新',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    ),
  );
}
