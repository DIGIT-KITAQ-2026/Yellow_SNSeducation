import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/parent_home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const YellowApp());
}

class YellowApp extends StatefulWidget {
  const YellowApp({super.key});

  @override
  State<YellowApp> createState() => _YellowAppState();
}

class _YellowAppState extends State<YellowApp> {
  final AppState _appState = AppState();

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: _appState,
      child: MaterialApp(
        title: 'Yellow SNS Education',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: Scaffold(
          appBar: AppBar(title: const Text('スクリーンタイム / AIによる講評')),
          body: const ParentHomeScreen(),
        ),
      ),
    );
  }
}
