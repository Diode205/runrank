import 'package:supabase_flutter/supabase_flutter.dart';

class PasswordResetService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<String?> applyResetCode({
    required String ukaNumber,
    required String resetCode,
    required String newPassword,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'reset-password-with-code',
        body: {
          'ukaNumber': ukaNumber.trim(),
          'resetCode': resetCode.trim().toUpperCase(),
          'newPassword': newPassword,
        },
      );

      if (response.status == 200) {
        return null;
      }

      final data = response.data;
      if (data is Map && data['error'] is String) {
        return data['error'] as String;
      }

      return 'Could not reset password right now.';
    } catch (e) {
      return 'Could not reset password right now: $e';
    }
  }
}
