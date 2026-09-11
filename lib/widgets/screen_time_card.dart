import 'package:flutter/material.dart';

import '../models/screen_time_day.dart';
import '../theme/app_palette.dart';
import '../theme/theme_controller.dart';
import 'glass_card.dart';
import 'screen_time_charts.dart';

/// 「先日のスクリーンタイム」カード。直近7日間の推移とアプリ別の内訳を表示する。
class ScreenTimeCard extends StatelessWidget {
  final List<ScreenTimeDay>? days;
  final bool isLoading;

  /// 取得失敗時の、画面にそのまま出せる日本語メッセージ。null なら未失敗。
  final String? error;

  /// [error] の原因が「使用状況へのアクセス」未許可かどうか。true なら
  /// [onOpenSettings] を促すボタンを、false なら [onRetry] の再試行ボタンを出す。
  final bool needsPermission;

  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;

  const ScreenTimeCard({
    super.key,
    required this.days,
    this.isLoading = false,
    this.error,
    this.needsPermission = false,
    this.onRetry,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final palette = ThemeController.instance.currentPalette;
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '先日のスクリーンタイム',
                style: TextStyle(fontWeight: FontWeight.w600, color: palette.textPrimary),
              ),
              const SizedBox(height: 12),
              if (isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: palette.accent)),
                )
              else if (error != null)
                _ErrorState(
                  message: error!,
                  // 未対応端末の案内は理由が変わらないため、ボタンを出さない。
                  actionLabel: needsPermission
                      ? '設定を開く'
                      : (onRetry != null ? '再試行' : null),
                  onPressed: needsPermission ? onOpenSettings : onRetry,
                  palette: palette,
                )
              else if (days == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: palette.accent)),
                )
              else ...[
                WeeklyScreenTimeChart(days: days!, palette: palette),
                const SizedBox(height: 8),
                Divider(color: palette.cardBorder.withValues(alpha: palette.isDark ? 0.3 : 0.6)),
                const SizedBox(height: 8),
                Text(
                  'アプリ別の内訳(昨日)',
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                ),
                const SizedBox(height: 8),
                AppBreakdownList(weekDays: days!, palette: palette),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;
  final AppPalette palette;

  const _ErrorState({
    required this.message,
    this.actionLabel,
    this.onPressed,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message,
          style: TextStyle(fontSize: 12, color: palette.textSecondary),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.textPrimary,
              side: BorderSide(color: palette.accent),
            ),
            onPressed: onPressed,
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}
