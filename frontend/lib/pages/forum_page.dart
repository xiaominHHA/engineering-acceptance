import 'package:flutter/material.dart';

import '../models/post.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class ForumPage extends StatefulWidget {
  const ForumPage({super.key, required this.api, required this.user});
  final ApiService api;
  final User user;
  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  List<Post> posts = [];
  final title = TextEditingController();
  final content = TextEditingController();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final value = await widget.api.posts();
    if (mounted) setState(() => posts = value);
  }

  Future<void> publish() async {
    if (title.text.isEmpty || content.text.isEmpty) return;
    await widget.api.createPost(widget.user.id, title.text, content.text);
    title.clear();
    content.clear();
    await load();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: '标题'),
        ),
        TextField(
          controller: content,
          decoration: const InputDecoration(labelText: '内容'),
        ),
        ElevatedButton(onPressed: publish, child: const Text('发布帖子')),
        ...posts.map(
          (post) => Card(
            child: ListTile(
              title: Text(post.title),
              subtitle: Text(post.content),
            ),
          ),
        ),
      ],
    ),
  );
}
