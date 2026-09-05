import 'package:flutter/material.dart';

const _cyan = Color(0xFF33F7FF);

class CredentialsStep extends StatefulWidget {
  const CredentialsStep({super.key, required this.onSubmit});

  final void Function(String email, String password) onSubmit;

  @override
  State<CredentialsStep> createState() => _CredentialsStepState();
}

class _CredentialsStepState extends State<CredentialsStep> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _emailError = false;
  bool _passwordError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _emailError = email.isEmpty;
      _passwordError = password.isEmpty;
    });
    if (_emailError || _passwordError) return;
    widget.onSubmit(email, password);
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
      prefixIcon: Icon(icon, color: _cyan),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: _cyan, width: 2),
      ),
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _emailController,
          style: const TextStyle(color: Colors.white),
          onChanged: (_) {
            if (_emailError) setState(() => _emailError = false);
          },
          decoration: _fieldDecoration('メールアドレス', Icons.mail_outline),
        ),
        if (_emailError) ...[
          const SizedBox(height: 4),
          const Text(
            '入力されていません',
            style: TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          onChanged: (_) {
            if (_passwordError) setState(() => _passwordError = false);
          },
          decoration: _fieldDecoration('パスワード', Icons.lock_outline),
        ),
        if (_passwordError) ...[
          const SizedBox(height: 4),
          const Text(
            '入力されていません',
            style: TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _cyan,
            foregroundColor: const Color(0xFF0B0A24),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('登録'),
        ),
      ],
    );
  }
}
