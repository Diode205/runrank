import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MembershipRenewalReminderStatus {
  const MembershipRenewalReminderStatus({
    required this.isActive,
    required this.daysRemaining,
    required this.yearStart,
    required this.windowEnd,
  });

  final bool isActive;
  final int daysRemaining;
  final DateTime yearStart;
  final DateTime windowEnd;

  static MembershipRenewalReminderStatus inactive() {
    final now = DateTime.now();
    return MembershipRenewalReminderStatus(
      isActive: false,
      daysRemaining: 0,
      yearStart: DateTime(now.year, 5, 1),
      windowEnd: DateTime(now.year, 6, 30),
    );
  }
}

class MembershipRenewalReminderService {
  MembershipRenewalReminderService._();

  static final _client = Supabase.instance.client;

  static DateTime? _dateOnly(dynamic value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime renewalYearStart([DateTime? date]) {
    final value = date ?? DateTime.now();
    return DateTime(value.year, 5, 1);
  }

  static bool isInRenewalWindow([DateTime? date]) {
    final value = date ?? DateTime.now();
    final today = DateTime(value.year, value.month, value.day);
    final windowStart = DateTime(value.year, 4, 1);
    final windowEnd = DateTime(value.year, 6, 30);
    return !today.isBefore(windowStart) && !today.isAfter(windowEnd);
  }

  static int daysRemaining([DateTime? date]) {
    final value = date ?? DateTime.now();
    final today = DateTime(value.year, value.month, value.day);
    final endExclusive = DateTime(value.year, 7, 1);
    return endExclusive.difference(today).inDays.clamp(0, 91).toInt();
  }

  static Future<MembershipRenewalReminderStatus> status() async {
    final user = _client.auth.currentUser;
    final now = DateTime.now();
    final yearStart = renewalYearStart(now);
    final windowEnd = DateTime(now.year, 6, 30);

    if (user == null || !isInRenewalWindow(now)) {
      return MembershipRenewalReminderStatus.inactive();
    }

    try {
      final profile = await _client
          .from('user_profiles')
          .select('club, member_since')
          .eq('id', user.id)
          .maybeSingle();
      final club = profile?['club']?.toString().trim();
      if (club == null || club.isEmpty) {
        return MembershipRenewalReminderStatus.inactive();
      }

      final memberSince = _dateOnly(profile?['member_since']);
      if (memberSince != null && !memberSince.isBefore(yearStart)) {
        return MembershipRenewalReminderStatus.inactive();
      }

      final renewal = await _client
          .from('membership_renewals')
          .select('id')
          .eq('user_id', user.id)
          .eq('club', club)
          .eq('membership_year_start', _dateKey(yearStart))
          .maybeSingle();

      if (renewal != null) {
        return MembershipRenewalReminderStatus.inactive();
      }

      return MembershipRenewalReminderStatus(
        isActive: true,
        daysRemaining: daysRemaining(now),
        yearStart: yearStart,
        windowEnd: windowEnd,
      );
    } catch (e) {
      debugPrint('MembershipRenewalReminderService.status error: $e');
      return MembershipRenewalReminderStatus.inactive();
    }
  }

  static String _dateKey(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    ).toIso8601String().split('T').first;
  }
}
