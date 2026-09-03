import 'package:flutter/material.dart';

import '../../models/post.dart';
import 'forum_view_model.dart';
import 'post_detail_page.dart';
import 'post_detail_view_model.dart';

class ForumPage extends StatefulWidget {
  const ForumPage({
    super.key,
    required this.viewModel,
    required this.createDetailViewModel,
    required this.onSessionExpired,
    this.currentUserId,
  });

  final ForumViewModel viewModel;
  final PostDetailViewModel Function(Post) createDetailViewModel;
  final Future<void> Function() onSessionExpired;
  final int? currentUserId;

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  final title = TextEditingController();
  final content = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_loadMoreIfNeeded);
    widget.viewModel.loadInitial();
  }

  void _loadMoreIfNeeded() {
    if (scrollController.position.extentAfter < 320) {
      widget.viewModel.loadMore();
    }
  }

  Future<void> openDetail(Post post) async {
    final detailViewModel = widget.createDetailViewModel(post);
    void syncPostToFeed() => widget.viewModel.mergePost(detailViewModel.post);
    detailViewModel.addListener(syncPostToFeed);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PostDetailPage(
          viewModel: detailViewModel,
          currentUserId: widget.currentUserId,
          onSessionExpired: widget.onSessionExpired,
        ),
      ),
    );
    detailViewModel.removeListener(syncPostToFeed);
    detailViewModel.dispose();
  }

  Future<void> openComposer() async {
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
                  if (widget.viewModel.actionErrorMessage
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

  Future<void> confirmDelete(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除帖子？'),
        content: const Text('帖子及其评论和点赞将一并删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await widget.viewModel.delete(post.id);
    if (!mounted || widget.viewModel.sessionExpired) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? '帖子已删除'
              : widget.viewModel.actionErrorMessage ?? '删除失败，请稍后重试',
        ),
      ),
    );
  }

  @override
  void dispose() {
    scrollController.dispose();
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
        onRefresh: widget.viewModel.refresh,
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
            onPressed: widget.viewModel.loadInitial,
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
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount:
          widget.viewModel.posts.length +
          (widget.viewModel.loadErrorMessage == null ? 0 : 1) +
          (widget.viewModel.isLoadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (widget.viewModel.loadErrorMessage != null && index == 0) {
          return Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.cloud_off_outlined),
              title: Text(widget.viewModel.loadErrorMessage!),
              trailing: TextButton(
                onPressed: widget.viewModel.refresh,
                child: const Text('重试'),
              ),
            ),
          );
        }
        final postIndex =
            index - (widget.viewModel.loadErrorMessage == null ? 0 : 1);
        if (postIndex == widget.viewModel.posts.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final post = widget.viewModel.posts[postIndex];
        return _PostCard(
          post: post,
          isCurrentUser: post.authorUserId == widget.currentUserId,
          deleting: widget.viewModel.deletingPostIds.contains(post.id),
          liking: widget.viewModel.likingPostIds.contains(post.id),
          onOpen: () => openDetail(post),
          onLike: () => widget.viewModel.toggleLike(post),
          onDelete: post.authorUserId == widget.currentUserId
              ? () => confirmDelete(post)
              : null,
        );
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.isCurrentUser,
    required this.deleting,
    required this.liking,
    required this.onOpen,
    required this.onLike,
    this.onDelete,
  });
  final Post post;
  final bool isCurrentUser;
  final bool deleting;
  final bool liking;
  final VoidCallback onOpen;
  final VoidCallback onLike;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
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
                    post.authorNickname ?? (isCurrentUser ? '我' : '社区用户'),
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (post.createdAt case final value?)
                  Text(
                    formatPostTime(value),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (onDelete != null)
                  deleting
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : PopupMenuButton<String>(
                          tooltip: '帖子操作',
                          onSelected: (_) => onDelete!(),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'delete', child: Text('删除帖子')),
                          ],
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
            Text(post.content, maxLines: 4, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: liking ? null : onLike,
                  icon: Icon(
                    post.likedByCurrentUser
                        ? Icons.favorite
                        : Icons.favorite_border,
                  ),
                  label: Text('${post.likeCount}'),
                ),
                TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text('${post.commentCount}'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

String formatPostTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.month}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
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
          height: (constraints.maxHeight - 48).clamp(180.0, double.infinity),
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
      Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 12),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      Text(message, textAlign: TextAlign.center),
      ?action,
    ],
  );
}
