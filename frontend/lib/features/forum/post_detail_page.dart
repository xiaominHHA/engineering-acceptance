import 'package:flutter/material.dart';

import '../../models/comment.dart';
import '../../models/post.dart';
import 'forum_page.dart';
import 'post_detail_view_model.dart';

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    super.key,
    required this.viewModel,
    required this.onSessionExpired,
    this.currentUserId,
  });

  final PostDetailViewModel viewModel;
  final Future<void> Function() onSessionExpired;
  final int? currentUserId;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final comment = TextEditingController();
  final commentFocus = FocusNode();
  final scrollController = ScrollController();
  bool handlingSessionExpiry = false;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_handleSessionExpiry);
    scrollController.addListener(_loadMoreIfNeeded);
    widget.viewModel.load();
  }

  void _handleSessionExpiry() {
    if (!widget.viewModel.sessionExpired || handlingSessionExpiry) return;
    handlingSessionExpiry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) await widget.onSessionExpired();
    });
  }

  void _loadMoreIfNeeded() {
    if (scrollController.position.extentAfter < 240) {
      widget.viewModel.loadMore();
    }
  }

  Future<void> sendComment() async {
    final value = comment.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('评论不能为空')));
      return;
    }
    if (value.length > 1000) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('评论不能超过 1000 位')));
      return;
    }
    final sent = await widget.viewModel.submitComment(value);
    if (!mounted) return;
    if (sent) {
      comment.clear();
      FocusScope.of(context).unfocus();
    } else if (widget.viewModel.actionErrorMessage case final message?) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> deleteComment(Comment value) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除评论？'),
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
    if (confirmed != true) return;
    final deleted = await widget.viewModel.deleteComment(value);
    if (!mounted || deleted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.viewModel.actionErrorMessage ?? '删除评论失败')),
    );
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_handleSessionExpiry);
    comment.dispose();
    commentFocus.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('帖子详情')),
    body: AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) => Column(
        children: [
          Expanded(child: _content(context)),
          _composer(context),
        ],
      ),
    ),
  );

  Widget _content(BuildContext context) {
    if (widget.viewModel.isLoading && widget.viewModel.comments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _PostDetailCard(
          post: widget.viewModel.post,
          onLike: widget.viewModel.toggleLike,
        ),
        const SizedBox(height: 20),
        Text(
          '评论 ${widget.viewModel.post.commentCount}',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (widget.viewModel.errorMessage case final message?) ...[
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (!widget.viewModel.isLoading &&
            widget.viewModel.comments.isEmpty) ...[
          const SizedBox(height: 28),
          const Center(child: Text('还没有评论，来聊聊吧')),
        ],
        for (final item in widget.viewModel.comments)
          _CommentTile(
            comment: item,
            mine: item.authorUserId == widget.currentUserId,
            deleting: widget.viewModel.deletingCommentIds.contains(item.id),
            onReply: () {
              widget.viewModel.replyTo(item);
              commentFocus.requestFocus();
            },
            onDelete: () => deleteComment(item),
          ),
        if (widget.viewModel.isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _composer(BuildContext context) => SafeArea(
    top: false,
    child: Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.viewModel.replyToNickname case final nickname?)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '回复 @$nickname',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    onPressed: widget.viewModel.clearReply,
                    icon: const Icon(Icons.close),
                    tooltip: '取消回复',
                  ),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: comment,
                    focusNode: commentFocus,
                    maxLength: 1000,
                    maxLines: 4,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: '写下你的评论',
                      counterText: '',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.viewModel.isSubmitting ? null : sendComment,
                  icon: widget.viewModel.isSubmitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  tooltip: '发送评论',
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _PostDetailCard extends StatelessWidget {
  const _PostDetailCard({required this.post, required this.onLike});
  final Post post;
  final VoidCallback onLike;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.authorNickname ?? '社区用户',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          if (post.createdAt case final value?)
            Text(
              formatPostTime(value),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 14),
          Text(
            post.title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(post.content),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: onLike,
                icon: Icon(
                  post.likedByCurrentUser
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
                label: Text('${post.likeCount}'),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chat_bubble_outline, size: 18),
              const SizedBox(width: 4),
              Text('${post.commentCount}'),
            ],
          ),
        ],
      ),
    ),
  );
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.mine,
    required this.deleting,
    required this.onReply,
    required this.onDelete,
  });
  final Comment comment;
  final bool mine;
  final bool deleting;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(child: Text(comment.authorNickname.characters.first)),
    title: Text(comment.authorNickname),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (comment.replyToNickname case final nickname?) Text('回复 @$nickname'),
        Text(comment.content),
        TextButton(onPressed: onReply, child: const Text('回复')),
      ],
    ),
    trailing: mine
        ? deleting
              ? const CircularProgressIndicator()
              : IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '删除评论',
                )
        : null,
  );
}
