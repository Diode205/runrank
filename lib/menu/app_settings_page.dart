import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/menu/policies_forms_notices_page.dart';
import 'package:runrank/services/notification_service.dart';

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  static const String _appPrivacyUrl =
      'https://docs.google.com/document/d/e/2PACX-1vSTrQ3pEMf5sGX1EItOjY4U72Am2R0ORxdJFzzEy2U2zNXDc1WFFo7Qp-JuTLctrwuwG6eMQAEyMdf7/pub';
  static const String _termsOfUseUrl =
      'https://docs.google.com/document/d/e/2PACX-1vQWuKHlmIfJWxZiyr-sT2pXhGaU4zTAGFL3G1Cm_keLnja76E6eXzkUYFyPkyR4rL95JftlQK63FV8N/pub';

  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _openAppPrivacy() async {
    final uri = Uri.parse(_appPrivacyUrl);
    await launchUrl(
      uri,
      mode: LaunchMode.inAppWebView,
      webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
    );
  }

  Future<void> _openTermsOfUse() async {
    final uri = Uri.parse(_termsOfUseUrl);
    await launchUrl(
      uri,
      mode: LaunchMode.inAppWebView,
      webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _launchEmail({
    String? to,
    required String subject,
    String? body,
  }) async {
    final encodedSubject = Uri.encodeComponent(subject);
    final encodedBody = body != null && body.isNotEmpty
        ? Uri.encodeComponent(body)
        : null;
    final query = [
      'subject=$encodedSubject',
      if (encodedBody != null) 'body=$encodedBody',
    ].join('&');

    final uri = Uri(scheme: 'mailto', path: to, query: query);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No email app available')));
    }
  }

  Future<void> _requestAccountDeletion() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to delete.')),
      );
      return;
    }

    try {
      final profile = await client
          .from('user_profiles')
          .select('full_name, email, club')
          .eq('id', user.id)
          .maybeSingle();

      final fullName = (profile?['full_name'] as String?)?.trim();
      final email = (profile?['email'] as String?)?.trim();
      final clubName = (profile?['club'] as String?)?.trim();

      if (clubName == null || clubName.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to determine your club. Please contact an administrator.',
            ),
          ),
        );
        return;
      }

      final displayName = (fullName != null && fullName.isNotEmpty)
          ? fullName
          : 'Unknown member';
      final emailText = (email != null && email.isNotEmpty)
          ? email
          : 'no email on file';
      // Work out committee recipients (Membership Secretary and
      // Club Secretary) for targeted notifications.
      Map<String, dynamic>? membershipRow;
      Map<String, dynamic>? secretaryRow;
      try {
        final committeeRows = await client
            .from('committee_roles')
            .select('role, name, email, user_id')
            .eq('club', clubName);

        for (final row in committeeRows) {
          final roleRaw = (row['role'] as String?) ?? '';
          final roleLower = roleRaw.toLowerCase();

          if (roleLower.contains('membership secretary')) {
            membershipRow ??= row;
          } else if (roleLower.contains('secretary') &&
              !roleLower.contains('membership')) {
            secretaryRow ??= row;
          }
        }
      } catch (e) {
        // If committee lookup fails we fall back to notifying all admins.
      }

      final today = DateTime.now();
      final requestDate =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final notificationBody =
          '$displayName ($emailText) has requested member-initiated full deletion of their RunRank club account for $clubName on $requestDate. '
          'Please process this deletion within seven (7) days of the request date in line with club policy. '
          'After this 7-day window there is no additional grace period and the member will no longer be able to log in.';

      final targetUserIds = <String>{};
      for (final row in [membershipRow, secretaryRow]) {
        if (row == null) continue;
        final rawUserId = row['user_id'];
        final userId = rawUserId?.toString().trim();
        if (userId != null && userId.isNotEmpty) {
          targetUserIds.add(userId);
        }
      }

      if (targetUserIds.isNotEmpty) {
        for (final userId in targetUserIds) {
          await NotificationService.notifyUser(
            userId: userId,
            title: 'Account deletion requested',
            body: notificationBody,
            route: 'club_committee',
          );
        }
      } else {
        // If no specific committee holders are configured, fall back
        // to notifying all admins in the club.
        await NotificationService.notifyClubAdminsInClub(
          clubName: clubName,
          title: 'Account deletion requested',
          body: notificationBody,
          route: 'club_committee',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your request has been sent. Contact your club admins to cancel within seven (7) days.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to request deletion: $e')));
    }
  }

  void _confirmRemoveProfile() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F111A),
          title: const Text(
            'Remove Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Deleting your profile will request removal of your data from the club. '
            'This action cannot be undone once processed within a week.\n\n'
            'Do you want to delete your account?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _requestAccountDeletion();
              },
              child: const Text(
                'Yes, send request',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFF0F111A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: primary, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App logo aligned to the left of About/Version
                  Image.asset(
                    'assets/images/screenrank_logo.png',
                    width: 44,
                    height: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'About RunRank',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Version: ${_version.isEmpty ? '—' : _version}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '''RunRank is a modern, cross-platform mobile app created to simplify running club management wherever you are. What began as a tool for calculating Club Standards and Age-Grading has grown into a powerful, all-in-one platform for clubs of all sizes.

From race schedules and results to club records, history, and performance tracking for individuals and teams, RunRank keeps everything organised in one place. Built-in communications, membership administration, and kit management help clubs stay connected and efficient, both on and off the track.

Designed by runners, for running clubs — RunRank puts your club in your pocket.''',
                          style: TextStyle(color: Colors.white70, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            collapsedBackgroundColor: const Color(0xFF0F111A),
            backgroundColor: const Color(0xFF0F111A),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: primary, width: 1),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: primary, width: 1),
            ),
            leading: const Icon(
              Icons.privacy_tip_outlined,
              color: Colors.white,
            ),
            title: const Text(
              'Privacy Policy',
              style: TextStyle(color: Colors.white),
            ),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'We respect your privacy. RunRank collects only the minimum personal information required to deliver the service, such as your name, email, and membership details. Data is stored securely and is never sold. ',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  'Privacy at a Glance',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bullet(
                      'Access is provided by your running club using a registration code',
                    ),
                    _bullet(
                      "You have already agreed to your club's Privacy Policy",
                    ),
                    _bullet(
                      "This app has its own Privacy Policy, which may differ from your club's",
                    ),
                    _bullet('By registering, you agree to both policies'),
                    _bullet(
                      'Location is used only to show directions to training sessions, races, and events',
                    ),
                    _bullet('No run tracking, no ads, no analytics'),
                    _bullet('Payments are processed securely by Stripe'),
                    _bullet(
                      'Photos and posts are published only after admin approval',
                    ),
                    _bullet('You can delete your profile at any time'),
                    _bullet(
                      'Club admins may remove profiles for inactive or unpaid memberships',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _openAppPrivacy,
                      child: Text(
                        'View Full App Privacy Policy',
                        style: TextStyle(color: primary),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PoliciesFormsNoticesPage(),
                          ),
                        );
                      },
                      child: Text(
                        'View Club Policy',
                        style: TextStyle(color: primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            collapsedBackgroundColor: const Color(0xFF0F111A),
            backgroundColor: const Color(0xFF0F111A),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: primary, width: 1),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: primary, width: 1),
            ),
            leading: const Icon(Icons.gavel_outlined, color: Colors.white),
            title: const Text(
              'Terms of Use',
              style: TextStyle(color: Colors.white),
            ),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'By using RunRank, you agree to use the app responsibly and comply with your club\'s code of conduct. Do not misuse features, attempt to access other users\' data, or violate local laws.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _openTermsOfUse,
                    child: Text(
                      'View Full Terms of Use',
                      style: TextStyle(color: primary),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF0F111A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: primary, width: 1),
            ),
            child: ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.white),
              title: const Text(
                'Help & Feedback',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Contact diodefernan@gmail.com for help or feedback',
                style: TextStyle(color: Colors.white70),
              ),
              onTap: () => _launchEmail(
                to: 'diodefernan@gmail.com',
                subject: 'RunRank feedback',
              ),
              trailing: const Icon(Icons.open_in_new, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            color: const Color(0xFF1A0F0F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.redAccent, width: 1),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.delete_forever_outlined,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Remove Profile',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'Permanently delete your profile data',
                style: TextStyle(color: Colors.white70),
              ),
              onTap: _confirmRemoveProfile,
            ),
          ),
        ],
      ),
    );
  }
}
