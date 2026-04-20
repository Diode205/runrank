import 'package:supabase_flutter/supabase_flutter.dart';

class RunnersBanquetService {
  static final _supabase = Supabase.instance.client;

  static String canonicalClubName(String? clubName) {
    final normalized = (clubName ?? '').trim();
    final lower = normalized.toLowerCase();
    if (lower == 'nrr' ||
        lower == 'norwich-road-runners' ||
        lower.contains('norwich road runners')) {
      return 'Norwich Road Runners';
    }
    if (lower == 'nnbr' ||
        lower == 'north-norfolk-beach-runners' ||
        lower.contains('north norfolk beach runners')) {
      return 'NNBR (North Norfolk Beach Runners)';
    }
    return normalized;
  }

  /// Load the current banquet configuration.
  /// If [eventId] is provided we scope to that event, otherwise
  /// we use the most recent configuration across all events.
  static Future<Map<String, dynamic>?> getConfig({
    String? eventId,
    required String clubName,
  }) async {
    final canonicalClub = canonicalClubName(clubName);
    if (canonicalClub.isEmpty) return null;
    try {
      dynamic query = _supabase
          .from('runners_banquet_config')
          .select()
          .eq('club_name', canonicalClub);
      if (eventId != null) {
        query = query.eq('event_id', eventId);
      } else {
        // When no event is specified, fall back to the most
        // recently created/updated banquet configuration.
        query = query.order('created_at', ascending: false);
      }
      final result = await query.limit(1).maybeSingle();
      return result == null ? null : Map<String, dynamic>.from(result);
    } catch (e) {
      // ignore: avoid_print
      print('Error loading runners banquet config: $e');
      return null;
    }
  }

  static Future<bool> saveConfig({
    String? eventId,
    required String clubName,
    required String menuText,
    required List<String> optionLabels,
    required int memberPricePence,
    required int partnerPricePence,
    required int otherPricePence,
  }) async {
    final canonicalClub = canonicalClubName(clubName);
    if (canonicalClub.isEmpty) return false;
    try {
      final payload = <String, dynamic>{
        'club_name': canonicalClub,
        'menu_text': menuText,
        'option1_label': optionLabels.isNotEmpty ? optionLabels[0] : null,
        'option2_label': optionLabels.length > 1 ? optionLabels[1] : null,
        'option3_label': optionLabels.length > 2 ? optionLabels[2] : null,
        // Backwards-compatible base price; keep equal to member price.
        'ticket_price_pence': memberPricePence,
        'ticket_price_member_pence': memberPricePence,
        'ticket_price_partner_pence': partnerPricePence,
        'ticket_price_other_pence': otherPricePence,
      };
      if (eventId != null) {
        payload['event_id'] = eventId;
      }

      if (eventId != null) {
        // Find existing config for this event so we can update
        // without relying on a unique constraint on event_id.
        final existing = await _supabase
            .from('runners_banquet_config')
            .select('id')
            .eq('event_id', eventId)
            .eq('club_name', canonicalClub)
            .maybeSingle();

        if (existing != null && existing['id'] != null) {
          await _supabase
              .from('runners_banquet_config')
              .update(payload)
              .eq('id', existing['id']);
        } else {
          await _supabase.from('runners_banquet_config').insert(payload);
        }
      } else {
        await _supabase.from('runners_banquet_config').insert(payload);
      }
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error saving runners banquet config: $e');
      return false;
    }
  }

  static Future<bool> addReservation({
    String? eventId,
    required String clubName,
    required String optionLabel,
    required int quantity,
    String? specialRequirements,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    final canonicalClub = canonicalClubName(clubName);
    if (canonicalClub.isEmpty) return false;

    try {
      await _supabase.from('runners_banquet_reservations').insert({
        'event_id': eventId,
        'club_name': canonicalClub,
        'user_id': user.id,
        'option_label': optionLabel,
        'quantity': quantity,
        'special_requirements': specialRequirements,
      });
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error adding runners banquet reservation: $e');
      return false;
    }
  }

  /// Remove the current user's reservations for a given event so that
  /// a fresh booking can replace them.
  static Future<void> clearMyReservationsForEvent({
    String? eventId,
    required String clubName,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final canonicalClub = canonicalClubName(clubName);
    if (canonicalClub.isEmpty) return;

    try {
      dynamic query = _supabase
          .from('runners_banquet_reservations')
          .delete()
          .eq('user_id', user.id)
          .eq('club_name', canonicalClub);

      if (eventId != null) {
        query = query.eq('event_id', eventId);
      }

      await query;
    } catch (e) {
      // ignore: avoid_print
      print('Error clearing my runners banquet reservations: $e');
    }
  }

  /// Current user's reservations for this banquet (for confirmation UI).
  static Future<List<Map<String, dynamic>>> getMyReservations({
    String? eventId,
    required String clubName,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];
    final canonicalClub = canonicalClubName(clubName);
    if (canonicalClub.isEmpty) return [];

    try {
      dynamic query = _supabase
          .from('runners_banquet_reservations')
          .select('option_label, quantity, created_at, special_requirements')
          .eq('user_id', user.id)
          .eq('club_name', canonicalClub)
          .order('created_at', ascending: false);

      if (eventId != null) {
        query = query.eq('event_id', eventId);
      }

      final rows = await query;
      return (rows as List)
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error loading my runners banquet reservations: $e');
      return [];
    }
  }

  /// Admin summary: list of reservations with user names for export.
  static Future<List<Map<String, dynamic>>> getAdminSummary({
    String? eventId,
    required String clubName,
  }) async {
    final canonicalClub = canonicalClubName(clubName);
    if (canonicalClub.isEmpty) return [];
    try {
      dynamic query = _supabase
          .from('runners_banquet_reservations')
          .select(
            'option_label, quantity, created_at, special_requirements, user_profiles!inner(full_name)',
          )
          .eq('club_name', canonicalClub)
          .order('option_label')
          .order('created_at');

      if (eventId != null) {
        query = query.eq('event_id', eventId);
      }

      final rows = await query;
      return (rows as List)
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error loading runners banquet summary: $e');
      return [];
    }
  }

  /// Admin-only reset of all banquet configuration and reservations.
  ///
  /// This clears runners_banquet_reservations and runners_banquet_config
  /// (optionally scoped to a specific event when [eventId] is provided).
  static Future<void> adminResetAll({
    String? eventId,
    required String clubName,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Please log in');
    }
    final canonicalClub = canonicalClubName(clubName);
    if (canonicalClub.isEmpty) {
      throw Exception('Unable to determine your club');
    }

    try {
      // Delete reservations first so reports drop to zero immediately.
      var reservationsDelete = _supabase
          .from('runners_banquet_reservations')
          .delete()
          .eq('club_name', canonicalClub);
      if (eventId != null) {
        reservationsDelete = reservationsDelete.eq('event_id', eventId);
      }
      await reservationsDelete;

      // Then clear the corresponding menu/config rows.
      var configDelete = _supabase
          .from('runners_banquet_config')
          .delete()
          .eq('club_name', canonicalClub);
      if (eventId != null) {
        configDelete = configDelete.eq('event_id', eventId);
      }
      await configDelete;
    } on PostgrestException catch (e) {
      // If RLS blocks this, surface a friendly error.
      if (e.code == '42501' || e.code == 'PGRST301') {
        throw Exception('Admin permissions are required to reset the banquet');
      }
      rethrow;
    }
  }
}
