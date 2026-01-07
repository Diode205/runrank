import 'package:supabase_flutter/supabase_flutter.dart';

class RunnersBanquetService {
  static final _supabase = Supabase.instance.client;

  /// Load the current banquet configuration.
  /// If [eventId] is provided we scope to that event, otherwise
  /// we use the most recent configuration across all events.
  static Future<Map<String, dynamic>?> getConfig({String? eventId}) async {
    try {
      dynamic query = _supabase.from('runners_banquet_config').select();
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
    required String menuText,
    required List<String> optionLabels,
    required int memberPricePence,
    required int partnerPricePence,
    required int otherPricePence,
  }) async {
    try {
      final payload = <String, dynamic>{
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
    required String optionLabel,
    required int quantity,
    String? specialRequirements,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      await _supabase.from('runners_banquet_reservations').insert({
        'event_id': eventId,
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
  static Future<void> clearMyReservationsForEvent({String? eventId}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      dynamic query = _supabase
          .from('runners_banquet_reservations')
          .delete()
          .eq('user_id', user.id);

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
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      dynamic query = _supabase
          .from('runners_banquet_reservations')
          .select('option_label, quantity, created_at, special_requirements')
          .eq('user_id', user.id)
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
  }) async {
    try {
      dynamic query = _supabase
          .from('runners_banquet_reservations')
          .select(
            'option_label, quantity, created_at, special_requirements, user_profiles!inner(full_name)',
          )
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
}
