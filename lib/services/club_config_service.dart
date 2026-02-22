import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClubConfig {
  final String id;
  final String name;
  final Color primaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final String? logoUrl;
  final String? heroImageUrl;

  const ClubConfig({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundColor,
    this.logoUrl,
    this.heroImageUrl,
  });

  ClubConfig copyWith({
    Color? primaryColor,
    Color? accentColor,
    Color? backgroundColor,
    String? logoUrl,
    String? heroImageUrl,
  }) {
    return ClubConfig(
      id: id,
      name: name,
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      logoUrl: logoUrl ?? this.logoUrl,
      heroImageUrl: heroImageUrl ?? this.heroImageUrl,
    );
  }
}

class ClubConfigService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static const _fallback = ClubConfig(
    id: 'fallback',
    name: 'Generic Running Club',
    primaryColor: Color(0xFF0055FF),
    accentColor: Color(0xFFFFD700),
    backgroundColor: Colors.black,
  );

  static Future<ClubConfig> loadForCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return _fallback;

      final profile = await _supabase
          .from('user_profiles')
          .select('club')
          .eq('id', user.id)
          .maybeSingle();

      final clubName = (profile?['club'] ?? '').toString();
      if (clubName.isEmpty) return _fallback;

      final clubRow = await _supabase
          .from('app_clubs')
          .select(
            'id, name, primary_color, accent_color, background_color, logo_url, hero_image_url',
          )
          .eq('name', clubName)
          .maybeSingle();

      if (clubRow == null) {
        return _fallback.copyWith(name: clubName);
      }

      final id = (clubRow['id'] ?? '').toString();
      final name = (clubRow['name'] ?? clubName).toString();

      final primary = _parseColor(
        clubRow['primary_color'] as String?,
        _fallback.primaryColor,
      );
      final accent = _parseColor(
        clubRow['accent_color'] as String?,
        _fallback.accentColor,
      );
      final background = _parseColor(
        clubRow['background_color'] as String?,
        _fallback.backgroundColor,
      );

      return ClubConfig(
        id: id,
        name: name,
        primaryColor: primary,
        accentColor: accent,
        backgroundColor: background,
        logoUrl: clubRow['logo_url'] as String?,
        heroImageUrl: clubRow['hero_image_url'] as String?,
      );
    } catch (e) {
      debugPrint('Error loading club config: $e');
      return _fallback;
    }
  }

  static Color _parseColor(String? hex, Color fallback) {
    if (hex == null) return fallback;
    final value = hex.trim();
    if (value.isEmpty) return fallback;

    var cleaned = value.toUpperCase().replaceAll('#', '');
    if (cleaned.length == 6) {
      cleaned = 'FF$cleaned';
    }
    if (cleaned.length != 8) {
      return fallback;
    }

    try {
      final intColor = int.parse(cleaned, radix: 16);
      return Color(intColor);
    } catch (_) {
      return fallback;
    }
  }
}
