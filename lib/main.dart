import 'package:flutter/material.dart';

import 'screens/child_signup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/parent_signup_screen.dart';
import 'theme/app_colors.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yellow SNS Education',
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
        '/': (_) => const LoginScreen(),
        '/signup/parent': (_) => const ParentSignupScreen(),
        '/signup/child': (_) => const ChildSignupScreen(),
      },
    );
  }
}
