import 'package:flutter/material.dart';
import 'package:runrank/services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController newName = TextEditingController();
  final TextEditingController newPassword = TextEditingController();
  final TextEditingController confirmPassword = TextEditingController();

  bool updating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit My Profile")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            const Text(
              "Update Full Name",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            TextField(
              controller: newName,
              decoration: const InputDecoration(labelText: "New Full Name"),
            ),
            const SizedBox(height: 30),

            const Text(
              "Update Password",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            TextField(
              controller: newPassword,
              obscureText: true,
              decoration: const InputDecoration(labelText: "New Password"),
            ),
            TextField(
              controller: confirmPassword,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Confirm Password"),
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: updating
                  ? null
                  : () async {
                      setState(() => updating = true);

                      // 1. NAME UPDATE
                      if (newName.text.isNotEmpty) {
                        await AuthService.updateName(newName.text.trim());
                      }

                      // 2. PASSWORD UPDATE
                      if (newPassword.text.isNotEmpty ||
                          confirmPassword.text.isNotEmpty) {
                        if (newPassword.text.trim() !=
                            confirmPassword.text.trim()) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Passwords do not match."),
                            ),
                          );
                          setState(() => updating = false);
                          return;
                        }

                        await AuthService.updatePassword(
                          newPassword.text.trim(),
                        );
                      }

                      setState(() => updating = false);

                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Profile updated successfully"),
                        ),
                      );

                      Navigator.pop(context); // return to menu
                    },
              child: updating
                  ? const CircularProgressIndicator()
                  : const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}
