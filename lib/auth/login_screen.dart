import 'package:flutter/material.dart';
import 'package:runrank/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
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
              onPressed: () async {
                final entered = email.text.trim();
                if (entered.isEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    const SnackBar(content: Text("Enter your email first")),
                  );
                  return;
                }

                try {
                  final messenger = ScaffoldMessenger.of(context);
                  await Supabase.instance.client.auth.resetPasswordForEmail(
                    entered,
                  );
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text("Password reset link sent to $entered"),
                    ),
                  );
                } catch (e) {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              },
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
          ],
        ),
      ),
    );
  }
}
