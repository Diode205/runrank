import 'package:flutter/material.dart';
import 'package:runrank/services/auth_service.dart';
import 'package:runrank/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _showForgotPasswordDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset password'),
          content: const Text(
            'For now, password resets are handled by your club admin. Please contact your admin for a one-off reset code, then use that code to choose a new password here in the app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pushNamed(AppRoutes.resetPasswordCode);
              },
              child: const Text('I have a reset code'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Welcome Back!",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 20),

            // Forgot password
            TextButton(
              onPressed: _showForgotPasswordDialog,
              child: const Text("Forgot password?"),
            ),

            // Log in button
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => loading = true);
                      final success = await AuthService.login(
                        email.text.trim(),
                        password.text.trim(),
                      );
                      if (!mounted) return;
                      setState(() => loading = false);

                      if (success) {
                        navigator.pushReplacementNamed(AppRoutes.root);
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Login failed, check credentials'),
                          ),
                        );
                      }
                    },
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("Log In"),
            ),

            // Create account
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.register);
              },
              child: const Text("Create an Account"),
            ),

            // Migrate existing account to a new club
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.migrateAccount);
              },
              child: const Text("Migrate an Account"),
            ),
            const SizedBox(height: 12),
            const Text(
              'By logging in, you agree to RunRank Terms of Use. RunRank has zero tolerance for objectionable content, harassment, abusive behaviour, or misuse of member data. Members can report objectionable posts and block abusive users.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
