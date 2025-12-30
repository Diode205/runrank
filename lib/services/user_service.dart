import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  static final _client = Supabase.instance.client;

  static Future<bool> isAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final row = await _client
        .from('user_profiles')
        .select('is_admin')
        .eq('id', user.id)
        .maybeSingle();

    return row != null && row['is_admin'] == true;
  }

  static Future<bool> isBlocked({
    BuildContext? context,
    bool showMessage = true,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final row = await _client
        .from('user_profiles')
        .select('is_blocked, block_reason')
        .eq('id', user.id)
        .maybeSingle();

    final blocked = row != null && row['is_blocked'] == true;
    if (blocked && context != null && showMessage) {
      final reason = (row['block_reason'] as String?)?.trim();
      final message = reason != null && reason.isNotEmpty
          ? reason
          : 'Posting is blocked';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    return blocked;
  }
}
