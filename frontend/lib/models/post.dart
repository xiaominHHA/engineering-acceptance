class Post {
  const Post({
    required this.id,
    required this.authorUserId,
    this.authorNickname,
    required this.title,
    required this.content,
    this.createdAt,
    this.updatedAt,
  });
  final String id;
  final int authorUserId;
  final String? authorNickname;
  final String title;
  final String content;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as String,
    authorUserId: json['authorUserId'] as int,
    authorNickname: json['authorNickname'] as String?,
    title: json['title'] as String,
    content: json['content'] as String,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
  );
}
