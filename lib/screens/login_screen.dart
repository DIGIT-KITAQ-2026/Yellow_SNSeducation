import 'package:flutter/material.dart';

import '../models/signup_draft.dart';
import '../services/auth_service.dart';
import '../supabase_config.dart';
import '../utils/auth_errors.dart';
import '../utils/validators.dart';
import 'account_type_dialog.dart';

const _cyan = Color(0xFF33F7FF);

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

  InputDecoration _fieldDecoration(String label, IconData icon, {String? errorText}) {
    return InputDecoration(
      labelText: label,
      errorText: errorText,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
      errorStyle: const TextStyle(color: Colors.redAccent),
      prefixIcon: Icon(icon, color: _cyan),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: _cyan, width: 2),
      ),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141416), Color(0xFF2A2A2E)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 56, color: _cyan),
                  const SizedBox(height: 12),
                  Text(
                    'アカウントログイン',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration(
                      'メールアドレス',
                      Icons.mail_outline,
                      errorText: _emailError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration(
                      'パスワード',
                      Icons.lock_outline,
                      errorText: _passwordError,
                    ),
                  ),
                  if (_formError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _formError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : _handleNewAccount,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: _cyan),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('新規'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _busy ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _cyan,
                            foregroundColor: const Color(0xFF0B0A24),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(_busy ? '処理中...' : 'ログイン'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'テスト用ログイン(登録済みのデモアカウント)',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed:
                          _busy ? null : () => _testLogin(SupabaseConfig.testParentEmail),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('保護者としてテストログイン'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _testLogin(SupabaseConfig.testChild1Email),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('子供1としてテストログイン'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _testLogin(SupabaseConfig.testChild2Email),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('子供2としてテストログイン'),
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
