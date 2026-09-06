import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase connection settings, loaded from the .env file at startup
/// (see main.dart) so no keys are committed. Copy .env.example to .env
/// and fill in the real values.
class SupabaseConfig {
  static String get url => dotenv.get('SUPABASE_URL', fallback: '');
  static String get anonKey => dotenv.get('SUPABASE_ANON_KEY', fallback: '');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Shared password for the seeded demo accounts behind the test login
  /// buttons. Override via TEST_PASSWORD in .env.
  static String get testPassword => dotenv.get('TEST_PASSWORD', fallback: 'test1234');

  static const testParentEmail = 'parent@example.com';
  static const testChild1Email = 'child1@example.com';
  static const testChild2Email = 'child2@example.com';
}
