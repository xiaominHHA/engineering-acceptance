class User {
  const User({
    required this.id,
    required this.username,
    required this.nickname,
    this.birthday,
    this.school,
    this.className,
  });
  final int id;
  final String username;
  final String nickname;
  final String? birthday;
  final String? school;
  final String? className;
  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    username: json['username'] as String,
    nickname: json['nickname'] as String,
    birthday: json['birthday'] as String?,
    school: json['school'] as String?,
    className: json['className'] as String?,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'username': username,
    'nickname': nickname,
    'birthday': birthday,
    'school': school,
    'className': className,
  };
}
