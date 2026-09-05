import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _networkMessage = '通信に失敗しました。接続を確認してください';

/// Turns a Supabase failure into the Japanese message shown under a field.
String authErrorMessage(Object error) {
  // The messages below are deliberately vague, so keep the raw failure
  // visible while developing.
  if (kDebugMode) debugPrint('authErrorMessage: $error');

  if (error is AuthRetryableFetchException) return _networkMessage;

  if (error is AuthException) {
    final message = error.message;
    if (error.code == 'email_not_confirmed') {
      return 'メールアドレスの確認が完了していません。確認メールのリンクを開いてください';
    }
    if (error.code == 'over_email_send_rate_limit') {
      return 'しばらく待ってから再度お試しください';
    }
    // Supabase側でメールプロバイダが無効。ユーザー操作では解消できない。
    if (error.code == 'email_provider_disabled' ||
        message.contains('Email signups are disabled')) {
      return 'サーバー側でメール登録が無効になっています。管理者にお問い合わせください';
    }
    if (message.contains('Invalid login credentials')) {
      return 'メールアドレスまたはパスワードが正しくありません';
    }
    if (message.contains('already registered')) {
      return 'このメールアドレスは既に登録されています';
    }
    if (message.contains('Password should be at least')) {
      return 'パスワードは6文字以上で入力してください';
    }
    if (message.contains('is invalid')) {
      return 'メールアドレスの形式が正しくありません';
    }
    if (message.contains('rate limit')) {
      return 'しばらく待ってから再度お試しください';
    }
    return 'ログインに失敗しました';
  }

  if (error is PostgrestException) {
    final message = error.message;
    if (message.contains('No group found for code')) {
      return 'グループコードが見つかりません';
    }
    if (message.contains('already has a profile')) {
      return 'このアカウントは既に登録済みです';
    }
    // 23502 here means the RPC ran without auth.uid(), i.e. no session.
    if (error.code == '23502' ||
        message.contains('created_by') ||
        message.contains('not-null')) {
      return '登録処理でセッションが確立できませんでした。ログインし直してから再度お試しください';
    }
    return '登録に失敗しました。時間をおいて再度お試しください';
  }

  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('ClientException')) {
    return _networkMessage;
  }
  return 'エラーが発生しました';
}
