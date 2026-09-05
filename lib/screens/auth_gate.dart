import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Root route: shows the login screen or the home screen depending on the
/// current session, so no screen has to navigate on sign-in/sign-out itself.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthService.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? AuthService.currentSession;
        if (session == null) return const LoginScreen();

        return ValueListenableBuilder<int>(
          valueListenable: AuthService.profileRevision,
          builder: (context, revision, _) {
            return _ProfileLoader(key: ValueKey('${session.user.id}-$revision'));
          },
        );
      },
    );
  }
}

class _ProfileLoader extends StatefulWidget {
  const _ProfileLoader({super.key});

  @override
  State<_ProfileLoader> createState() => _ProfileLoaderState();
}

class _ProfileLoaderState extends State<_ProfileLoader> {
  late Future<UserProfile?> _profile = AuthService.fetchProfile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Message(child: CircularProgressIndicator(color: AppColors.accent));
        }
        if (snapshot.hasError) {
          return _Message(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '通信に失敗しました。接続を確認してください',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: '再試行',
                  onPressed: () => setState(() => _profile = AuthService.fetchProfile()),
                ),
              ],
            ),
          );
        }

        final profile = snapshot.data;
        if (profile == null) {
          // Signed in but no profile row: signup was interrupted before the
          // create_parent_account / join_group RPC ran.
          return _Message(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'アカウント登録が完了していません。\nもう一度登録をやり直してください。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 20),
                PrimaryButton(label: 'ログイン画面に戻る', onPressed: AuthService.signOut),
              ],
            ),
          );
        }

        return HomeScreen(profile: profile);
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
