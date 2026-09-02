import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_page.dart';
import 'features/auth/login_view_model.dart';
import 'features/forum/forum_page.dart';
import 'features/forum/forum_view_model.dart';
import 'features/forum/post_repository.dart';
import 'features/profile/profile_page.dart';
import 'features/profile/profile_view_model.dart';
import 'features/profile/user_repository.dart';
import 'models/user.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ApiClient apiClient;
  late final LoginViewModel loginViewModel;
  late final UserRepository userRepository;
  late final PostRepository postRepository;
  ProfileViewModel? profileViewModel;
  ForumViewModel? forumViewModel;
  User? user;

  @override
  void initState() {
    super.initState();
    apiClient = ApiClient();
    loginViewModel = LoginViewModel(HttpAuthRepository(apiClient));
    userRepository = HttpUserRepository(apiClient);
    postRepository = HttpPostRepository(apiClient);
  }

  void login(User value) {
    profileViewModel?.dispose();
    forumViewModel?.dispose();
    setState(() {
      user = value;
      profileViewModel = ProfileViewModel(userRepository, value);
      forumViewModel = ForumViewModel(postRepository);
    });
  }

  void logout({bool sessionExpired = false}) {
    profileViewModel?.dispose();
    forumViewModel?.dispose();
    profileViewModel = null;
    forumViewModel = null;
    apiClient.clearSession();
    setState(() => user = null);
    if (sessionExpired) loginViewModel.showSessionExpired();
  }

  @override
  void dispose() {
    loginViewModel.dispose();
    profileViewModel?.dispose();
    forumViewModel?.dispose();
    apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Engineering Acceptance',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: user == null
        ? LoginPage(viewModel: loginViewModel, onLogin: login)
        : HomePage(
            profileViewModel: profileViewModel!,
            forumViewModel: forumViewModel!,
            onUpdate: (value) => setState(() => user = value),
            currentUserId: user!.id,
            onLogout: () => logout(),
            onSessionExpired: () => logout(sessionExpired: true),
          ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.profileViewModel,
    required this.forumViewModel,
    required this.currentUserId,
    required this.onUpdate,
    required this.onLogout,
    required this.onSessionExpired,
  });
  final ProfileViewModel profileViewModel;
  final ForumViewModel forumViewModel;
  final int currentUserId;
  final ValueChanged<User> onUpdate;
  final VoidCallback onLogout;
  final VoidCallback onSessionExpired;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;
  bool handlingSessionExpiry = false;

  @override
  void initState() {
    super.initState();
    widget.profileViewModel.addListener(_handleSessionExpiry);
    widget.forumViewModel.addListener(_handleSessionExpiry);
  }

  void _handleSessionExpiry() {
    if (handlingSessionExpiry ||
        (!widget.profileViewModel.sessionExpired &&
            !widget.forumViewModel.sessionExpired)) {
      return;
    }
    handlingSessionExpiry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSessionExpired();
    });
  }

  @override
  void dispose() {
    widget.profileViewModel.removeListener(_handleSessionExpiry);
    widget.forumViewModel.removeListener(_handleSessionExpiry);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ProfilePage(
        key: const ValueKey('profile'),
        viewModel: widget.profileViewModel,
        onUpdate: widget.onUpdate,
      ),
      ForumPage(
        key: const ValueKey('forum'),
        viewModel: widget.forumViewModel,
        currentUserId: widget.currentUserId,
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(index == 0 ? '个人资料' : '论坛'),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            tooltip: '退出登录',
          ),
        ],
      ),
      body: IndexedStack(index: index, children: pages),
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
