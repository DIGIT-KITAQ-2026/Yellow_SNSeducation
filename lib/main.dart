import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_gate.dart';
import 'screens/child_signup_screen.dart';
import 'screens/missing_config_screen.dart';
import 'screens/parent_signup_screen.dart';
import 'services/daily_notification_service.dart';
import 'supabase_config.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load();
  } catch (_) {
    // No .env file yet: MissingConfigScreen below explains what to do.
  }
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    // ai-review Edge Function 経由でGeminiによる実際のAI講評を生成する
    // (ScreenTimeRegistry.aiCommentaryService の既定が SupabaseAiCommentaryService
    // のため、ここでの差し替えは不要)。
  }
  // 毎朝8時のスクリーンタイム確認通知の初期化。実際のスケジュールは
  // ログイン後に AuthGate から syncForSession で行う。
  await DailyNotificationService.instance.init();
  runApp(const YellowSnsEducationApp());
}

class YellowSnsEducationApp extends StatelessWidget {
  const YellowSnsEducationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ドパデト',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) =>
            SupabaseConfig.isConfigured ? const AuthGate() : const MissingConfigScreen(),
        '/signup/parent': (_) => const ParentSignupScreen(),
        '/signup/child': (_) => const ChildSignupScreen(),
      },
    );
  }
}
