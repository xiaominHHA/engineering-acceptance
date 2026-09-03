import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'core/error/app_failure.dart';
import 'core/session/session_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_page.dart';
import 'features/auth/login_view_model.dart';
import 'features/auth/register_view_model.dart';
import 'features/forum/forum_page.dart';
import 'features/forum/forum_view_model.dart';
import 'features/forum/forum_repository.dart';
import 'features/forum/post_detail_view_model.dart';
import 'features/profile/profile_page.dart';
import 'features/profile/profile_view_model.dart';
import 'features/profile/user_repository.dart';
import 'models/user.dart';
import 'models/post.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.apiClient, this.sessionStorage});

  final ApiClient? apiClient;
  final SessionStorage? sessionStorage;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ApiClient apiClient;
  late final HttpAuthRepository authRepository;
  late final LoginViewModel loginViewModel;
  late final UserRepository userRepository;
  late final ForumRepository forumRepository;
  ProfileViewModel? profileViewModel;
  ForumViewModel? forumViewModel;
  User? user;
  bool restoringSession = true;

  @override
  void initState() {
    super.initState();
    apiClient = widget.apiClient ?? ApiClient();
    authRepository = HttpAuthRepository(
      apiClient,
      sessionStorage: widget.sessionStorage,
    );
    loginViewModel = LoginViewModel(authRepository);
    userRepository = HttpUserRepository(apiClient);
    forumRepository = HttpForumRepository(apiClient);
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final session = await authRepository.restoreSession();
      if (!mounted) return;
      if (session == null) {
        setState(() => restoringSession = false);
        return;
      }

      var restoredUser = session.user;
      if (!session.isLegacy) {
        restoredUser = await userRepository.get(restoredUser.id);
        await authRepository.updateUser(restoredUser);
      }
      if (mounted) _activateSession(restoredUser);
    } on AppFailure catch (failure) {
      if (failure.type == AppFailureType.sessionExpired) {
        await authRepository.logout();
        loginViewModel.showSessionExpired();
      } else {
        loginViewModel.showRestoreFailure(failure);
      }
      if (mounted) setState(() => restoringSession = false);
    } catch (_) {
      loginViewModel.showRestoreFailure(
        const AppFailure(AppFailureType.unknown),
      );
      if (mounted) setState(() => restoringSession = false);
    }
  }

  void _activateSession(User value) {
    profileViewModel?.dispose();
    forumViewModel?.dispose();
    setState(() {
      user = value;
      restoringSession = false;
      profileViewModel = ProfileViewModel(userRepository, value);
      forumViewModel = ForumViewModel(forumRepository);
    });
  }

  Future<void> logout({bool sessionExpired = false}) async {
    profileViewModel?.dispose();
    forumViewModel?.dispose();
    profileViewModel = null;
    forumViewModel = null;
    setState(() => user = null);
    await authRepository.logout();
    if (sessionExpired) loginViewModel.showSessionExpired();
  }

  Future<void> updateUser(User value) async {
    setState(() => user = value);
    await authRepository.updateUser(value);
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
    home: restoringSession
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : user == null
        ? LoginPage(
            viewModel: loginViewModel,
            createRegisterViewModel: () => RegisterViewModel(authRepository),
            onLogin: login,
          )
        : HomePage(
            profileViewModel: profileViewModel!,
            forumViewModel: forumViewModel!,
            createDetailViewModel: (post) =>
                PostDetailViewModel(forumRepository, post),
            onUpdate: updateUser,
            currentUserId: user!.id,
            onLogout: logout,
            onSessionExpired: () => logout(sessionExpired: true),
          ),
  );

  void login(User value) => _activateSession(value);
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.profileViewModel,
    required this.forumViewModel,
    required this.createDetailViewModel,
    required this.currentUserId,
    required this.onUpdate,
    required this.onLogout,
    required this.onSessionExpired,
  });
  final ProfileViewModel profileViewModel;
  final ForumViewModel forumViewModel;
  final PostDetailViewModel Function(Post) createDetailViewModel;
  final int currentUserId;
  final Future<void> Function(User) onUpdate;
  final Future<void> Function() onLogout;
  final Future<void> Function() onSessionExpired;
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) await widget.onSessionExpired();
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
        onLogout: widget.onLogout,
      ),
      ForumPage(
        key: const ValueKey('forum'),
        viewModel: widget.forumViewModel,
        currentUserId: widget.currentUserId,
        createDetailViewModel: (post) => widget.createDetailViewModel(post),
        onSessionExpired: widget.onSessionExpired,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(index == 0 ? '个人资料' : '校园社区')),
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
