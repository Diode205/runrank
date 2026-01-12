import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:runrank/menu/policies_forms_notices_page.dart';

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  String _version = '';
  // Set this when the public URL is available.
  String? _appPrivacyUrl;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _openAppPrivacy() async {
    if (_appPrivacyUrl == null || _appPrivacyUrl!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App privacy policy link coming soon')),
      );
      return;
    }
    final uri = Uri.parse(_appPrivacyUrl!);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  Future<void> _launchEmail({required String subject}) async {
    final uri = Uri(
      scheme: 'mailto',
      // No default recipient to avoid hardcoding; user can choose.
      queryParameters: {'subject': subject},
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No email app available')));
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
            'Removing your profile will permanently delete your data. This action cannot be undone.\n\n'
            'If full account deletion is required (including authentication), please contact the administrators. ',
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
                _launchEmail(subject: 'RunRank account deletion request');
              },
              child: const Text(
                'Request via Email',
                style: TextStyle(color: Colors.amber),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFF0F111A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFF5C542), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFF5C542)),
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
              side: const BorderSide(color: Color(0xFFF5C542), width: 1),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFF5C542), width: 1),
            ),
            leading: const Icon(
              Icons.privacy_tip_outlined,
              color: Color(0xFFF5C542),
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
                      child: const Text(
                        'View Full App Privacy Policy',
                        style: TextStyle(color: Colors.amber),
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
                      child: const Text(
                        'Read more',
                        style: TextStyle(color: Colors.amber),
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
              side: const BorderSide(color: Color(0xFFF5C542), width: 1),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFF5C542), width: 1),
            ),
            leading: const Icon(Icons.gavel_outlined, color: Color(0xFFF5C542)),
            title: const Text(
              'Terms of Use',
              style: TextStyle(color: Colors.white),
            ),
            children: const [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'By using RunRank, you agree to use the app responsibly and comply with your club\'s code of conduct. Do not misuse features, attempt to access other users\' data, or violate local laws.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF0F111A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFF5C542), width: 1),
            ),
            child: ListTile(
              leading: const Icon(Icons.help_outline, color: Color(0xFFF5C542)),
              title: const Text(
                'Help & Feedback',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Open your email app to contact us',
                style: TextStyle(color: Colors.white70),
              ),
              onTap: () => _launchEmail(subject: 'RunRank feedback'),
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
