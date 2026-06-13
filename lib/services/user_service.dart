import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  static final _client = Supabase.instance.client;
  static String? _cachedClubName;

  static String? get cachedClubName => _cachedClubName;

  static void cacheClubName(String? clubName) {
    final normalized = clubName?.trim();
    _cachedClubName = normalized != null && normalized.isNotEmpty
        ? normalized
        : null;
  }

  static void clearCachedClubName() {
    _cachedClubName = null;
  }

  static bool _isYcrrClubName(String? clubName) {
    final compact = (clubName ?? '').toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return compact == 'ycrr' || compact.contains('yourclubroadrunners');
  }

  static Future<bool> isAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final row = await _client
        .from('user_profiles')
        .select('is_admin, club')
        .eq('id', user.id)
        .maybeSingle();

    final club = row?['club'] as String?;
    final isYcrrDemo = _isYcrrClubName(club);

    return row != null && (row['is_admin'] == true || isYcrrDemo);
  }

  static String _compactForMatch(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static bool _nameLooksLike(String? profileName, String? committeeName) {
    final profile = _compactForMatch(profileName ?? '');
    final committee = _compactForMatch(committeeName ?? '');
    if (profile.isEmpty || committee.isEmpty) return false;
    if (profile == committee) return true;
    if (profile.contains(committee) || committee.contains(profile)) {
      return true;
    }

    final profileParts = (profileName ?? '')
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((part) => part.length > 1)
        .toSet();
    final committeeParts = (committeeName ?? '')
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((part) => part.length > 1)
        .toSet();
    if (profileParts.isEmpty || committeeParts.isEmpty) return false;
    return committeeParts.difference(profileParts).isEmpty;
  }

  static Future<bool> isAppOwner() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      final ownerRow = await _client
          .from('app_owner_user_ids')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();
      return ownerRow != null;
    } catch (e) {
      debugPrint('App owner access check failed: $e');
      return false;
    }
  }

  static Future<bool> hasCommitteeRoleAccess({
    required List<String> roleIncludes,
    List<String> roleExcludes = const [],
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    if (await isAppOwner()) return true;

    try {
      final profile = await _client
          .from('user_profiles')
          .select('id, full_name, email, club')
          .eq('id', user.id)
          .maybeSingle();

      final clubName = (profile?['club'] as String?)?.trim();
      if (clubName == null || clubName.isEmpty) return false;
      if (_isYcrrClubName(clubName)) return true;

      final profileEmail =
          (profile?['email'] as String?)?.trim().toLowerCase() ??
          user.email?.trim().toLowerCase();
      final profileName = (profile?['full_name'] as String?)?.trim();

      final rows = await _client
          .from('committee_roles')
          .select('role, name, email, user_id, club')
          .eq('club', clubName);

      for (final raw in rows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final role = ((row['role'] as String?) ?? '').trim().toLowerCase();
        final hasAllIncludes = roleIncludes.every(
          (value) => role.contains(value.trim().toLowerCase()),
        );
        final hasAnyExcludes = roleExcludes.any(
          (value) => role.contains(value.trim().toLowerCase()),
        );
        if (!hasAllIncludes || hasAnyExcludes) continue;

        final directUserId = row['user_id']?.toString().trim();
        if (directUserId != null &&
            directUserId.isNotEmpty &&
            directUserId == user.id) {
          return true;
        }

        final roleEmail = (row['email'] as String?)?.trim().toLowerCase();
        if (profileEmail != null &&
            profileEmail.isNotEmpty &&
            roleEmail != null &&
            roleEmail.isNotEmpty &&
            profileEmail == roleEmail) {
          return true;
        }

        final roleName = (row['name'] as String?)?.trim();
        if (_nameLooksLike(profileName, roleName)) {
          return true;
        }
      }
    } catch (e) {
      debugPrint('Committee role access check failed: $e');
    }

    return false;
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
      if (!context.mounted) return blocked;
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
    if (user == null) {
      _cachedClubName = null;
      return null;
    }

    final row = await _client
        .from('user_profiles')
        .select('club')
        .eq('id', user.id)
        .maybeSingle();

    final raw = (row?['club'] as String?)?.trim();
    _cachedClubName = (raw != null && raw.isNotEmpty) ? raw : null;
    return _cachedClubName;
  }

  /// Shared brand gradient for club UI chrome.
  /// - Norwich Road Runners -> red + white (with 30% alpha)
  /// - Your Club Road Runners -> yellow + green
  /// - All other clubs (incl. NNBR) -> NNBR yellow + blue
  static List<Color> clubBrandGradient(String? clubName) {
    final lower = clubName?.toLowerCase() ?? '';
    if (lower.isEmpty) {
      return const [Color(0x4D2A2A2A), Color(0x4D101010)];
    }
    if (lower.contains('norwich road runners')) {
      // Match app_clubs migration: primary '#D32F2F' (strong red), accent '#FFFFFF' (white)
      return const [Color(0x4DD32F2F), Color(0x4DFFFFFF)];
    }
    if (_isYcrrClubName(lower)) {
      return const [Color(0x4DFFD300), Color(0x4D16803A)];
    }

    // Default NNBR-style yellow/blue
    return const [Color(0x4DFFD300), Color(0x4D0057B7)];
  }

  static Color clubPrimaryColor(String? clubName) {
    final lower = clubName?.toLowerCase() ?? '';
    if (lower.contains('norwich road runners')) {
      return const Color(0xFFD32F2F);
    }
    if (_isYcrrClubName(lower)) {
      return const Color(0xFFFFD300);
    }
    if (lower.isEmpty) {
      return const Color(0xFF6B7280);
    }
    return const Color(0xFFFFD300);
  }

  static Color readableOn(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}
