import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yellow_sns_education/screens/child_signup_screen.dart';
import 'package:yellow_sns_education/screens/login_screen.dart';
import 'package:yellow_sns_education/screens/parent_signup_screen.dart';

/// Mirrors MyApp's routes minus the AuthGate at '/', which needs a live
/// Supabase client. These tests only cover the login screen's local
/// validation and its navigation into the signup flow.
Widget buildApp() {
  return MaterialApp(
    initialRoute: '/',
    routes: {
      '/': (_) => const LoginScreen(),
      '/signup/parent': (_) => const ParentSignupScreen(),
      '/signup/child': (_) => const ChildSignupScreen(),
    },
  );
}

void main() {
  testWidgets('Login screen shows email/password fields and buttons', (tester) async {
    await tester.pumpWidget(buildApp());

    expect(find.text('アカウントログイン'), findsOneWidget);
    expect(find.text('メールアドレス'), findsOneWidget);
    expect(find.text('パスワード'), findsOneWidget);
    expect(find.text('新規'), findsOneWidget);
    expect(find.text('ログイン'), findsOneWidget);
  });

  testWidgets('Login validates empty fields with an error message', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.text('ログイン'));
    await tester.pump();

    expect(find.text('入力されていません'), findsNWidgets(2));
  });

  testWidgets('Login rejects a malformed email address', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.enterText(find.widgetWithText(TextField, 'メールアドレス'), 'not-an-email');
    await tester.enterText(find.widgetWithText(TextField, 'パスワード'), 'password123');
    await tester.tap(find.text('ログイン'));
    await tester.pump();

    expect(find.text('メールアドレスの形式が正しくありません'), findsOneWidget);
  });

  testWidgets('新規 opens the account type dialog, and a role leads to its signup screen', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.text('新規'));
    await tester.pumpAndSettle();

    expect(find.text('タイプを選択'), findsOneWidget);

    await tester.tap(find.text('保護者'));
    await tester.pump();
    await tester.tap(find.text('アカウント作成'));
    await tester.pumpAndSettle();

    expect(find.text('親アカウント作成'), findsOneWidget);
  });
}
