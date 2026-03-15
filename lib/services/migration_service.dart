import 'package:supabase_flutter/supabase_flutter.dart';

class MigrationService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Validates a migration code for the given destination club.
  ///
  /// For now this only checks that there is an approved
  /// membership_migrations row for the code and club. The actual
  /// data movement (profile + race records) will be implemented
  /// in a follow-up step.
  static Future<bool> validateMigrationCode({
    required String migrationCode,
    required String newClub,
  }) async {
    try {
      final result = await _supabase
          .from('membership_migrations')
          .select('id, status, to_club')
          .eq('migration_code', migrationCode)
          .eq('to_club', newClub)
          .eq('status', 'approved')
          .maybeSingle();

      return result != null;
    } catch (e) {
      // Log in debug output; return false so UI can show a generic error.
      // ignore: avoid_print
      print('MigrationService.validateMigrationCode error: $e');
      return false;
    }
  }

  /// Applies a membership migration by calling the database function
  /// `apply_membership_migration`.
  ///
  /// On success, this will update the user's club and mark the
  /// migration as completed so it cannot be reused.
  static Future<bool> applyMigration({
    required String migrationCode,
    required String newClub,
  }) async {
    try {
      final result = await _supabase.rpc(
        'apply_membership_migration',
        params: {'p_migration_code': migrationCode, 'p_new_club': newClub},
      );

      // If the function returns a JSON object, treat that as success.
      return result != null;
    } catch (e) {
      // ignore: avoid_print
      print('MigrationService.applyMigration error: $e');
      return false;
    }
  }
}
