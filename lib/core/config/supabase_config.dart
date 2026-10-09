import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  static String get url => dotenv.env['SUPABASE_URL']!;

  static String get publishableKey =>
      dotenv.env['SUPABASE_ANON_KEY']!;

  static String get redirectUrl =>
      dotenv.env['REDIRECT_URL']!;
}
