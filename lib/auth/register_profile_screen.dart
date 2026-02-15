import 'package:flutter/material.dart';
import 'package:runrank/services/auth_service.dart';
import 'package:runrank/root_navigation.dart';
import 'package:runrank/menu/policies_forms_notices_page.dart';
import 'package:url_launcher/url_launcher.dart';

class RegisterProfileScreen extends StatefulWidget {
  final String selectedClub;

  const RegisterProfileScreen({super.key, required this.selectedClub});

  @override
  State<RegisterProfileScreen> createState() => _RegisterProfileScreenState();
}

class _RegisterProfileScreenState extends State<RegisterProfileScreen> {
  final email = TextEditingController();
  final name = TextEditingController();
  final dob = TextEditingController();
  final uka = TextEditingController();
  final password = TextEditingController();

  bool loading = false;
  String? selectedMembershipType;
  String _selectedGender = 'M';
  bool agreeClubPolicy = false;
  bool agreeAppPolicy = false;
  String? _appPrivacyUrl; // Set when available

  final membershipOptions = [
    "1st Claim",
    "2nd Claim",
    "Social",
    "Full-Time Education",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Your Profile")),

      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: "Full Name"),
            ),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: dob,
              decoration: const InputDecoration(
                labelText: "Date of Birth (YYYY-MM-DD)",
              ),
            ),
            TextField(
              controller: uka,
              decoration: const InputDecoration(labelText: "UKA Member Number"),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(labelText: 'Gender'),
              items: const [
                DropdownMenuItem(value: 'M', child: Text('Male')),
                DropdownMenuItem(value: 'F', child: Text('Female')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedGender = value);
              },
            ),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 16),
            const Text(
              "Select Your Membership Type",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              isExpanded: true,
              value: selectedMembershipType,
              hint: const Text("Choose your membership type"),
              items: membershipOptions.map((String type) {
                return DropdownMenuItem<String>(value: type, child: Text(type));
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedMembershipType = newValue;
                });
              },
            ),

            const SizedBox(height: 20),
            _privacyAtAGlanceCard(context),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: agreeClubPolicy,
              onChanged: (v) => setState(() => agreeClubPolicy = v ?? false),
              title: const Text(
                "I have read and agreed to my club's Privacy Policy",
                style: TextStyle(fontSize: 13),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              value: agreeAppPolicy,
              onChanged: (v) => setState(() => agreeAppPolicy = v ?? false),
              title: const Text(
                "I agree to RunRank's app Privacy Policy",
                style: TextStyle(fontSize: 13),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading || !(agreeClubPolicy && agreeAppPolicy)
                  ? null
                  : () async {
                      if (selectedMembershipType == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please select a membership type"),
                          ),
                        );
                        return;
                      }

                      setState(() => loading = true);

                      final success = await AuthService.register(
                        email: email.text.trim(),
                        password: password.text.trim(),
                        fullName: name.text.trim(),
                        dob: dob.text.trim(),
                        ukaNumber: uka.text.trim(),
                        club: widget.selectedClub,
                        membershipType: selectedMembershipType!,
                        gender: _selectedGender,
                      );

                      setState(() => loading = false);

                      if (success) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RootNavigation(),
                          ),
                          (_) => false,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Registration failed")),
                        );
                      }
                    },
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("Create Account"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _privacyAtAGlanceCard(BuildContext context) {
    return Card(
      color: const Color(0xFF0F111A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFF5C542), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy at a Glance',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _bullet(
              'Access is provided by your running club using a registration code',
            ),
            _bullet("You have already agreed to your club's Privacy Policy"),
            _bullet(
              "This app has its own Privacy Policy, which may differ from your club's",
            ),
            _bullet('By registering, you agree to both policies'),
            _bullet(
              'Location is used only to show directions to training sessions, races, and events',
            ),
            _bullet('No run tracking, no ads, no analytics'),
            _bullet('Payments are processed securely by Stripe'),
            _bullet('Photos and posts are published only after admin approval'),
            _bullet('You can delete your profile at any time'),
            _bullet(
              'Club admins may remove profiles for inactive or unpaid memberships',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: _openAppPrivacy,
                  child: const Text(
                    'View Full App Privacy Policy',
                    style: TextStyle(color: Colors.amber),
                  ),
                ),
                const Spacer(),
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
          ],
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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

  Future<void> _openAppPrivacy() async {
    if (_appPrivacyUrl == null || _appPrivacyUrl!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App privacy policy link coming soon')),
      );
      return;
    }
    await launchUrl(
      Uri.parse(_appPrivacyUrl!),
      mode: LaunchMode.externalApplication,
    );
  }
}
