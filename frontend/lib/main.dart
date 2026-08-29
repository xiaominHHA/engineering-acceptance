import 'package:flutter/material.dart';

import 'models/user.dart';
import 'pages/forum_page.dart';
import 'pages/login_page.dart';
import 'pages/profile_page.dart';
import 'services/api_service.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final api = ApiService();
  User? user;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Engineering Acceptance',
    theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.indigo)),
    home: user == null
        ? LoginPage(api: api, onLogin: (value) => setState(() => user = value))
        : HomePage(
            api: api,
            user: user!,
            onUpdate: (value) => setState(() => user = value),
            onLogout: () => setState(() => user = null),
          ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.api,
    required this.user,
    required this.onUpdate,
    required this.onLogout,
  });
  final ApiService api;
  final User user;
  final ValueChanged<User> onUpdate;
  final VoidCallback onLogout;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      ProfilePage(
        api: widget.api,
        user: widget.user,
        onUpdate: widget.onUpdate,
      ),
      ForumPage(api: widget.api, user: widget.user),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(index == 0 ? '个人资料' : '论坛'),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person), label: '资料'),
          NavigationDestination(icon: Icon(Icons.forum), label: '论坛'),
        ],
      ),
    );
  }
}
