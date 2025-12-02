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
}
