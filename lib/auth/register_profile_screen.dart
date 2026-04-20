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
  static const String _appPrivacyUrl =
      'https://docs.google.com/document/d/e/2PACX-1vSTrQ3pEMf5sGX1EItOjY4U72Am2R0ORxdJFzzEy2U2zNXDc1WFFo7Qp-JuTLctrwuwG6eMQAEyMdf7/pub';

  final email = TextEditingController();
  final name = TextEditingController();
  final dob = TextEditingController();
  final uka = TextEditingController();
  final password = TextEditingController();
  final emergencyContactName = TextEditingController();
  final emergencyContactNumber = TextEditingController();
  DateTime? _selectedDob;

  bool loading = false;
  String? selectedMembershipType;
  String _selectedGender = 'M';
  String? _selectedEmergencyRelation;
  bool agreeClubPolicy = false;
  bool agreeAppPolicy = false;
  bool agreeEmergencyConsent = false;

  final membershipOptions = [
    "1st Claim",
    "2nd Claim",
    "Social",
    "Full-Time Education",
  ];

  static const emergencyRelations = [
    'Spouse',
    'Parent',
    'Friend',
    'Child',
    'Kin',
    'Carer',
  ];

  String _formatDobDisplay(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');
    return '$day-$month-$year';
  }

  String _formatDobForStorage(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');
    return '$year-$month-$day';
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initialDate =
        _selectedDob ?? DateTime(now.year - 30, now.month, now.day);
    final firstDate = DateTime(now.year - 120, 1, 1);
    final lastDate = now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(lastDate) ? lastDate : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select date of birth',
    );

    if (picked == null) return;

    setState(() {
      _selectedDob = picked;
      dob.text = _formatDobDisplay(picked);
    });
  }

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
              readOnly: true,
              onTap: _pickDateOfBirth,
              decoration: InputDecoration(
                labelText: "Date of Birth (DD-MM-YYYY)",
                hintText: 'Tap to select',
                suffixIcon: IconButton(
                  onPressed: _pickDateOfBirth,
                  icon: const Icon(Icons.calendar_today),
                  tooltip: 'Select date of birth',
                ),
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
            const Text(
              "Emergency Contact",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emergencyContactName,
              decoration: const InputDecoration(labelText: "ICE contact name"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emergencyContactNumber,
              decoration: const InputDecoration(
                labelText: "ICE contact number",
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedEmergencyRelation,
              decoration: const InputDecoration(labelText: 'Relationship'),
              items: emergencyRelations
                  .map(
                    (relation) => DropdownMenuItem<String>(
                      value: relation,
                      child: Text(relation),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedEmergencyRelation = value);
              },
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: agreeEmergencyConsent,
              onChanged: (value) {
                setState(() => agreeEmergencyConsent = value ?? false);
              },
              title: const Text(
                'I consent to my emergency contact details being accessed by club admins and members in a training or racing emergency.',
                style: TextStyle(fontSize: 13),
              ),
              controlAffinity: ListTileControlAffinity.leading,
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

                      if (emergencyContactName.text.trim().isEmpty ||
                          emergencyContactNumber.text.trim().isEmpty ||
                          _selectedEmergencyRelation == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please complete all emergency contact details',
                            ),
                          ),
                        );
                        return;
                      }

                      if (!agreeEmergencyConsent) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please confirm emergency access consent',
                            ),
                          ),
                        );
                        return;
                      }

                      if (_selectedDob == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select your date of birth'),
                          ),
                        );
                        return;
                      }

                      setState(() => loading = true);

                      final success = await AuthService.register(
                        email: email.text.trim(),
                        password: password.text.trim(),
                        fullName: name.text.trim(),
                        dob: _formatDobForStorage(_selectedDob!),
                        ukaNumber: uka.text.trim(),
                        club: widget.selectedClub,
                        membershipType: selectedMembershipType!,
                        gender: _selectedGender,
                        emergencyContactName: emergencyContactName.text.trim(),
                        emergencyContactNumber: emergencyContactNumber.text
                            .trim(),
                        emergencyContactRelation: _selectedEmergencyRelation!,
                        emergencyDetailsConsent: agreeEmergencyConsent,
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
                        builder: (_) => PoliciesFormsNoticesPage(
                          initialClubName: widget.selectedClub,
                        ),
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
    await launchUrl(
      Uri.parse(_appPrivacyUrl),
      mode: LaunchMode.inAppWebView,
      webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
    );
  }
}
