import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';

/// Placeholder landing screen reached after a successful login or signup.
/// Stands in for the real dashboard, which isn't built yet.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.displayName, this.groupName, this.groupCode});

  final String displayName;
  final String? groupName;
  final String? groupCode;

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.accent, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'ようこそ、$displayNameさん',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (groupName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'グループ名: $groupName',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                  if (groupCode != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'グループコード: $groupCode',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 32),
                  PrimaryButton(
                    label: 'ログアウト',
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    ),
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
