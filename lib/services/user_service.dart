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

  /// Resolve the current user's club name (e.g. "NNBR", "Norwich Road Runners").
  /// Returns null if no club is set or user is not logged in.
  static Future<String?> currentClubName() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final row = await _client
        .from('user_profiles')
        .select('club')
        .eq('id', user.id)
        .maybeSingle();

    final raw = (row?['club'] as String?)?.trim();
    return (raw != null && raw.isNotEmpty) ? raw : null;
  }

  /// Shared brand gradient for club UI chrome.
  /// - Norwich Road Runners -> red + white (with 30% alpha)
  /// - All other clubs (incl. NNBR) -> NNBR yellow + blue
  static List<Color> clubBrandGradient(String? clubName) {
    final lower = clubName?.toLowerCase() ?? '';
    if (lower.contains('norwich road runners')) {
      // Match app_clubs migration: primary '#D32F2F' (strong red), accent '#FFFFFF' (white)
      return const [Color(0x4DD32F2F), Color(0x4DFFFFFF)];
    }

    // Default NNBR-style yellow/blue
    return const [Color(0x4DFFD300), Color(0x4D0057B7)];
  }
}
