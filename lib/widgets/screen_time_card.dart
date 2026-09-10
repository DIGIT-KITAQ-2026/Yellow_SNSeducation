import 'package:flutter/material.dart';

import '../models/screen_time_day.dart';
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
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '先日のスクリーンタイム',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (error != null)
            _ErrorState(
              message: error!,
              // 未対応端末の案内は理由が変わらないため、ボタンを出さない。
              actionLabel: needsPermission
                  ? '設定を開く'
                  : (onRetry != null ? '再試行' : null),
              onPressed: needsPermission ? onOpenSettings : onRetry,
            )
          else if (days == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            WeeklyScreenTimeChart(days: days!),
            const SizedBox(height: 8),
            Divider(color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 8),
            Text(
              'アプリ別の内訳(昨日)',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 8),
            AppBreakdownList(day: days!.first),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  const _ErrorState({required this.message, this.actionLabel, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message,
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF33F7FF)),
            ),
            onPressed: onPressed,
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}
