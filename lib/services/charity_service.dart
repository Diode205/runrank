import 'package:supabase_flutter/supabase_flutter.dart';

class CharityService {
  static final _supabase = Supabase.instance.client;

  /// Fetch the current charity record (only 1 row expected)
  static Future<Map<String, dynamic>?> getCharity() async {
    final response = await _supabase
        .from('charity_fundraising')
        .select()
        .limit(1)
        .maybeSingle();

    return response;
  }

  /// Update total raised (admin-only)
  static Future<void> updateTotalRaised(double newTotal) async {
    await _supabase
        .from('charity_fundraising')
        .update({
          'total_raised': newTotal,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .neq('id', ''); // update first row only
  }

  /// Initialise charity row once per year (admin-only)
  static Future<void> setupCharity({
    required String name,
    required String donateUrl,
  }) async {
    await _supabase.from('charity_fundraising').insert({
      'charity_name': name,
      'donate_url': donateUrl,
      'total_raised': 0,
    });
  }
}
