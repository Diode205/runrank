import 'package:supabase_flutter/supabase_flutter.dart';

class MembershipTierConfig {
  const MembershipTierConfig({
    required this.clubName,
    required this.tierName,
    required this.amountPence,
    required this.stripeEnabled,
  });

  final String clubName;
  final String tierName;
  final int amountPence;
  final bool stripeEnabled;

  factory MembershipTierConfig.fromMap(Map<String, dynamic> map) {
    return MembershipTierConfig(
      clubName: map['club_name'] as String,
      tierName: map['tier_name'] as String,
      amountPence: map['amount_pence'] as int,
      stripeEnabled: map['stripe_enabled'] as bool? ?? true,
    );
  }
}

class MembershipTierConfigService {
  MembershipTierConfigService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static String canonicalClubName(String? clubName) {
    final normalized = (clubName ?? '').trim();
    final lower = normalized.toLowerCase();
    if (lower == 'nrr' || lower.contains('norwich road runners')) {
      return 'Norwich Road Runners';
    }
    if (lower == 'nnbr' || lower.contains('north norfolk beach runners')) {
      return 'NNBR (North Norfolk Beach Runners)';
    }
    return normalized;
  }

  Future<Map<String, MembershipTierConfig>> fetchConfigs(
    String? clubName,
  ) async {
    final canonicalClub = canonicalClubName(clubName);
    if (canonicalClub.isEmpty) return const {};

    final rows = await _client
        .from('membership_tier_configs')
        .select('club_name, tier_name, amount_pence, stripe_enabled')
        .eq('club_name', canonicalClub)
        .order('tier_name');

    final configs = <String, MembershipTierConfig>{};
    for (final row in rows as List) {
      final config = MembershipTierConfig.fromMap(row as Map<String, dynamic>);
      configs[config.tierName] = config;
    }
    return configs;
  }

  Future<void> updateAmount({
    required String clubName,
    required String tierName,
    required int amountPence,
  }) async {
    final canonicalClub = canonicalClubName(clubName);
    await _client.from('membership_tier_configs').upsert({
      'club_name': canonicalClub,
      'tier_name': tierName,
      'amount_pence': amountPence,
      'updated_at': DateTime.now().toIso8601String(),
      'updated_by': _client.auth.currentUser?.id,
    });
  }
}
