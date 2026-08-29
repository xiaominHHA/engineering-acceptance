class Post {
  const Post({
    required this.id,
    required this.authorUserId,
    required this.title,
    required this.content,
  });
  final String id;
  final int authorUserId;
  final String title;
  final String content;
  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as String,
    authorUserId: json['authorUserId'] as int,
    title: json['title'] as String,
    content: json['content'] as String,
  );
}
