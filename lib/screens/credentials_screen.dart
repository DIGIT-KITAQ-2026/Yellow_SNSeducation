import 'package:flutter/material.dart';

import '../models/signup_draft.dart';
import '../theme/app_colors.dart';
import '../utils/validators.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';
import 'home_screen.dart';

/// Screen ④ of the wireframe (メールアドレスとパスワードを登録), shared by
/// both the parent and child signup flows: the final step that attaches
/// login credentials to the account details collected in [draft].
class CredentialsScreen extends StatefulWidget {
  const CredentialsScreen({super.key, required this.draft});

  final SignupDraft draft;

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
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

  void _handleDecide() {
    setState(() {
      _emailError = validateEmail(_emailController.text);
      _passwordError = _passwordController.text.isEmpty ? '入力されていません' : null;
    });
    if (_emailError != null || _passwordError != null) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          displayName: widget.draft.displayName,
          groupName: widget.draft.groupName,
          groupCode: widget.draft.groupCode,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textSecondary, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('メールアドレスとパスワードを登録', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
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
                  const SizedBox(height: 24),
                  PrimaryButton(label: '決定', onPressed: _handleDecide),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
