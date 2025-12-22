import 'package:flutter/material.dart';
import 'package:runrank/services/auth_service.dart';
import 'package:runrank/root_navigation.dart';

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
            ElevatedButton(
              onPressed: loading
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
}
