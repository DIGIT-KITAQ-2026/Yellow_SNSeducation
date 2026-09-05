import 'package:flutter/material.dart';

import '../models/signup_draft.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';

/// Placeholder landing screen reached after a successful login or signup.
/// Stands in for the real dashboard, which isn't built yet.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.profile});

  final UserProfile profile;

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
                    'ようこそ、${profile.displayName}さん',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile.role == AccountRole.parent ? '保護者アカウント' : '子どもアカウント',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'グループ名: ${profile.groupName}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'グループコード: ${profile.groupCode}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '保有ポイント: ${profile.pointBalance}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  PrimaryButton(label: 'ログアウト', onPressed: AuthService.signOut),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
