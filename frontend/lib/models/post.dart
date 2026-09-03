class Post {
  const Post({
    required this.id,
    required this.authorUserId,
    this.authorNickname,
    required this.title,
    required this.content,
    this.createdAt,
    this.updatedAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByCurrentUser = false,
  });
  final String id;
  final int authorUserId;
  final String? authorNickname;
  final String title;
  final String content;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int likeCount;
  final int commentCount;
  final bool likedByCurrentUser;
  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as String,
    authorUserId: json['authorUserId'] as int,
    authorNickname: json['authorNickname'] as String?,
    title: json['title'] as String,
    content: json['content'] as String,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
    commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
    likedByCurrentUser: json['likedByCurrentUser'] as bool? ?? false,
  );

  Post copyWith({
    int? likeCount,
    int? commentCount,
    bool? likedByCurrentUser,
  }) => Post(
    id: id,
    authorUserId: authorUserId,
    authorNickname: authorNickname,
    title: title,
    content: content,
    createdAt: createdAt,
    updatedAt: updatedAt,
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
    likedByCurrentUser: likedByCurrentUser ?? this.likedByCurrentUser,
  );
}
