import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class CharityService {
  static final _supabase = Supabase.instance.client;

  static String? normalizeClubName(String? clubName) {
    final trimmed = clubName?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final lower = trimmed.toLowerCase();
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

    return trimmed;
  }

  static Map<String, dynamic>? pickCharityForClub(
    List<Map<String, dynamic>> rows,
    String? clubName,
  ) {
    if (rows.isEmpty) return null;

    final normalizedClub = normalizeClubName(clubName);
    if (normalizedClub == null) return null;

    for (final row in rows) {
      final rowClub = normalizeClubName(row['club'] as String?);
      if (rowClub == normalizedClub) {
        return row;
      }
    }

    return null;
  }

  static Stream<List<Map<String, dynamic>>> watchCharities({
    required String? clubName,
  }) {
    final normalizedClub = normalizeClubName(clubName);
    if (normalizedClub == null) {
      return Stream.value(const <Map<String, dynamic>>[]);
    }

    return _supabase
        .from('charity_fundraising')
        .stream(primaryKey: ['id'])
        .eq('club', normalizedClub)
        .order('updated_at')
        .map((rows) => List<Map<String, dynamic>>.from(rows));
  }

  /// Fetch the current charity record (only 1 row expected)
  static Future<Map<String, dynamic>?> getCharity({String? clubName}) async {
    final normalizedClub = normalizeClubName(clubName);
    if (normalizedClub == null) return null;

    final response = await _supabase
        .from('charity_fundraising')
        .select()
        .eq('club', normalizedClub)
        .maybeSingle();

    if (response == null) return null;
    return Map<String, dynamic>.from(response);
  }

  static Future<void> saveCharity({
    required String? clubName,
    required String charityName,
    required String introText,
    required String websiteUrl,
    required String donateUrl,
    required String qrImageUrl,
    required double totalRaised,
  }) async {
    final normalizedClub = normalizeClubName(clubName);
    if (normalizedClub == null) return;

    final existing = await getCharity(clubName: normalizedClub);

    final payload = <String, dynamic>{
      'club': normalizedClub,
      'charity_name': charityName.trim(),
      'intro_text': introText.trim().isEmpty ? null : introText.trim(),
      'website_url': websiteUrl.trim().isEmpty ? null : websiteUrl.trim(),
      'donate_url': donateUrl.trim().isEmpty ? null : donateUrl.trim(),
      'qr_image_url': qrImageUrl.trim().isEmpty ? null : qrImageUrl.trim(),
      'total_raised': totalRaised,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (existing != null && existing['id'] != null) {
      await _supabase
          .from('charity_fundraising')
          .update(payload)
          .eq('id', existing['id']);
      return;
    }

    await _supabase.from('charity_fundraising').insert({
      ...payload,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> saveCharityBasics({
    required String? clubName,
    required String websiteUrl,
  }) async {
    final existing = await getCharity(clubName: clubName);

    await saveCharity(
      clubName: clubName,
      charityName:
          (existing?['charity_name'] as String?)?.trim().isNotEmpty == true
          ? (existing!['charity_name'] as String).trim()
          : 'Charity of the Year',
      introText: (existing?['intro_text'] as String?) ?? '',
      websiteUrl: websiteUrl,
      donateUrl: (existing?['donate_url'] as String?) ?? '',
      qrImageUrl: (existing?['qr_image_url'] as String?) ?? '',
      totalRaised: ((existing?['total_raised'] as num?) ?? 0).toDouble(),
    );
  }

  /// Update total raised (admin-only)
  static Future<void> updateTotalRaised({
    required String? clubName,
    required double newTotal,
  }) async {
    final existing = await getCharity(clubName: clubName);
    if (existing == null) {
      await saveCharity(
        clubName: clubName,
        charityName: 'Charity of the Year',
        introText: '',
        websiteUrl: '',
        donateUrl: '',
        qrImageUrl: '',
        totalRaised: newTotal,
      );
      return;
    }

    await saveCharity(
      clubName: clubName,
      charityName:
          (existing['charity_name'] as String?) ?? 'Charity of the Year',
      introText: (existing['intro_text'] as String?) ?? '',
      websiteUrl: (existing['website_url'] as String?) ?? '',
      donateUrl: (existing['donate_url'] as String?) ?? '',
      qrImageUrl: (existing['qr_image_url'] as String?) ?? '',
      totalRaised: newTotal,
    );
  }

  /// Reset or initialise the current charity season (admin-only).
  static Future<void> setupCharity({
    required String? clubName,
    required String name,
    required String introText,
    required String websiteUrl,
    required String donateUrl,
    required String qrImageUrl,
  }) async {
    await saveCharity(
      clubName: clubName,
      charityName: name,
      introText: introText,
      websiteUrl: websiteUrl,
      donateUrl: donateUrl,
      qrImageUrl: qrImageUrl,
      totalRaised: 0,
    );
  }

  static Future<String> uploadQrImage({
    required File file,
    required String? clubName,
  }) async {
    final normalizedClub = normalizeClubName(clubName) ?? 'general';
    final extension = file.path.split('.').last.toLowerCase();
    final path =
        'charity/${normalizedClub}_${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _supabase.storage.from('club-media').upload(path, file);
    return _supabase.storage.from('club-media').getPublicUrl(path);
  }
}
