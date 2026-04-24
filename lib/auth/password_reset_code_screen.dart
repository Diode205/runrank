import 'package:flutter/material.dart';
import 'package:runrank/app_routes.dart';
import 'package:runrank/services/password_reset_service.dart';

class PasswordResetCodeScreen extends StatefulWidget {
  const PasswordResetCodeScreen({super.key});

  @override
  State<PasswordResetCodeScreen> createState() =>
      _PasswordResetCodeScreenState();
}

class _PasswordResetCodeScreenState extends State<PasswordResetCodeScreen> {
  final TextEditingController _ukaController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _ukaController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ukaNumber = _ukaController.text.trim();
    final resetCode = _codeController.text.trim().toUpperCase();
    final newPassword = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (ukaNumber.isEmpty || resetCode.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Enter your UKA number and reset code first.'),
        ),
      );
      return;
    }

    if (newPassword.length < 8) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please enter a password with at least 8 characters.'),
        ),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final error = await PasswordResetService.applyResetCode(
      ukaNumber: ukaNumber,
      resetCode: resetCode,
      newPassword: newPassword,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Password updated. You can now log in with your new password.'),
      ),
    );
    navigator.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Enter the one-off reset code provided by your club admin, along with your UKA number, then choose a new password.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _ukaController,
                  decoration: const InputDecoration(
                    labelText: 'UKA member number',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Reset code'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                  ),
                  onSubmitted: (_) {
                    if (!_submitting) {
                      _submit();
                    }
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reset password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
