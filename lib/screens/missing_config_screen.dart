import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shown instead of the app when SUPABASE_URL / SUPABASE_ANON_KEY aren't
/// set in .env, so the failure is readable rather than a crash deep inside
/// the Supabase client.
class MissingConfigScreen extends StatelessWidget {
  const MissingConfigScreen({super.key});

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
                  const Icon(Icons.settings_outlined, color: AppColors.error, size: 40),
                  const SizedBox(height: 16),
                  const Text(
                    'Supabase の接続設定がありません',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '.env.example を .env にコピーし、'
                    'SUPABASE_URL と SUPABASE_ANON_KEY を設定してから起動し直してください。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.fieldBorder),
                    ),
                    child: const Text(
                      'SUPABASE_URL=https://<project-ref>.supabase.co\n'
                      'SUPABASE_ANON_KEY=<anon key>',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
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
