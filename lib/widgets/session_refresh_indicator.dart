import 'package:flutter/material.dart';

import '../services/session_loader.dart';

/// 各タブの「引っ張って更新」。引くと [SessionLoader.load] でセッション一式を
/// 取り直すので、どのタブで引いてもログイン直後と同じだけ新しい状態になる。
///
/// [child] は縦スクロールするウィジェット。内容が短いときでも引けるように、
/// `physics: AlwaysScrollableScrollPhysics()` を必ず付けておくこと。
class SessionRefreshIndicator extends StatelessWidget {
  const SessionRefreshIndicator({super.key, required this.child, this.onAlsoRefresh});

  final Widget child;

  /// その画面固有の再取得(ホームの画面時間など)。セッションの再取得と並行に走る。
  /// null なら共通のセッション再取得だけを行う。
  final Future<void> Function()? onAlsoRefresh;

  Future<void> _refresh(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Future.wait([
        SessionLoader.load(),
        if (onAlsoRefresh != null) onAlsoRefresh!(),
      ]);
    } catch (_) {
      // 子どもも見る画面なので生のエラーは出さない。失敗しても表示中の内容は
      // そのまま残るため、案内だけ出して何もしない。
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('更新に失敗しました。通信状況を確認してください')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: child,
    );
  }
}
