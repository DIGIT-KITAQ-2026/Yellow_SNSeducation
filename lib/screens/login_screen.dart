import 'package:flutter/material.dart';

import '../models/signup_draft.dart';
import '../services/auth_service.dart';
import '../supabase_config.dart';
import '../theme/app_colors.dart';
import '../utils/auth_errors.dart';
import '../utils/validators.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';
import 'account_type_dialog.dart';

/// Screen ① of the wireframe (初期画面・親子共通): email/password login,
/// entry point into the 新規登録 flow, plus test login shortcuts for the
/// seeded demo accounts.
///
/// Navigation after a successful sign-in is handled by AuthGate, which
/// reacts to the auth state change.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _formError;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _emailError = validateEmail(_emailController.text);
      _passwordError = _passwordController.text.isEmpty ? '入力されていません' : null;
      _formError = null;
    });
    if (_emailError != null || _passwordError != null) return;

    await _signIn(_emailController.text.trim(), _passwordController.text);
  }

  Future<void> _testLogin(String email) =>
      _signIn(email, SupabaseConfig.testPassword);

  Future<void> _signIn(String email, String password) async {
    setState(() => _busy = true);
    try {
      await AuthService.signIn(email: email, password: password);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _formError = authErrorMessage(error);
      });
    }
    // On success AuthGate swaps this screen out; no navigation needed here.
  }

  Future<void> _handleNewAccount() async {
    final role = await showDialog<AccountRole>(
      context: context,
      builder: (_) => const AccountTypeDialog(),
    );
    if (role == null || !mounted) return;

    Navigator.of(context).pushNamed(
      role == AccountRole.parent ? '/signup/parent' : '/signup/child',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.accent, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'アカウントログイン',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    controller: _emailController,
                    label: 'メールアドレス',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    errorText: _emailError,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _passwordController,
                    label: 'パスワード',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    errorText: _passwordError,
                  ),
                  if (_formError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _formError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: '新規',
                          onPressed: _busy ? null : _handleNewAccount,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          label: _busy ? '処理中...' : 'ログイン',
                          onPressed: _busy ? null : _handleLogin,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'テスト用ログイン(登録済みのデモアカウント)',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: '保護者としてテストログイン',
                    onPressed: _busy ? null : () => _testLogin(SupabaseConfig.testParentEmail),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: '子供1としてテストログイン',
                          onPressed: _busy ? null : () => _testLogin(SupabaseConfig.testChild1Email),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SecondaryButton(
                          label: '子供2としてテストログイン',
                          onPressed: _busy ? null : () => _testLogin(SupabaseConfig.testChild2Email),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
