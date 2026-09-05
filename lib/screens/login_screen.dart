import 'package:flutter/material.dart';

import '../models/signup_draft.dart';
import '../theme/app_colors.dart';
import '../utils/validators.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';
import 'account_type_dialog.dart';
import 'home_screen.dart';

/// Screen ① of the wireframe (初期画面・親子共通): email/password login,
/// entry point into the 新規登録 flow, plus dev-only test login shortcuts.
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    setState(() {
      _emailError = validateEmail(_emailController.text);
      _passwordError = _passwordController.text.isEmpty ? '入力されていません' : null;
    });
    if (_emailError != null || _passwordError != null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HomeScreen(displayName: _emailController.text.trim()),
      ),
    );
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

  void _testLogin(String name) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HomeScreen(displayName: name)),
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
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(label: '新規', onPressed: _handleNewAccount),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(label: 'ログイン', onPressed: _handleLogin),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'テスト用ログイン(メール・パスワード不要)',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: '保護者としてテストログイン',
                    onPressed: () => _testLogin('保護者(テスト)'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: '子供1としてテストログイン',
                          onPressed: () => _testLogin('子供1(テスト)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SecondaryButton(
                          label: '子供2としてテストログイン',
                          onPressed: () => _testLogin('子供2(テスト)'),
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
