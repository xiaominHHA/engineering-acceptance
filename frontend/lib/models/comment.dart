class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.authorUserId,
    required this.authorNickname,
    required this.content,
    this.replyToCommentId,
    this.replyToNickname,
    this.createdAt,
  });

  final String id;
  final String postId;
  final int authorUserId;
  final String authorNickname;
  final String content;
  final String? replyToCommentId;
  final String? replyToNickname;
  final DateTime? createdAt;

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'] as String,
    postId: json['postId'] as String,
    authorUserId: json['authorUserId'] as int,
    authorNickname: json['authorNickname'] as String? ?? '社区用户',
    content: json['content'] as String,
    replyToCommentId: json['replyToCommentId'] as String?,
    replyToNickname: json['replyToNickname'] as String?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );
}
