import 'package:flutter/material.dart';
import 'package:runrank/app_routes.dart';
import 'package:runrank/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.recoveryUri});

  final Uri? recoveryUri;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _processingRecovery = false;
  String? _recoveryError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ensureRecoverySession();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _ensureRecoverySession() async {
    if (Supabase.instance.client.auth.currentUser != null) {
      return;
    }

    final uri = widget.recoveryUri;
    if (uri == null) {
      setState(() {
        _recoveryError =
            'This password reset session is no longer available. Please request a new reset email.';
      });
      return;
    }

    setState(() {
      _processingRecovery = true;
      _recoveryError = null;
    });

    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
      if (!mounted) return;

      if (Supabase.instance.client.auth.currentUser == null) {
        setState(() {
          _recoveryError =
              'The password reset link was opened, but no recovery session was created. Please request a new reset email.';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _recoveryError = 'Could not process the password reset link: $error';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _processingRecovery = false;
      });
    }
  }

  Future<void> _saveNewPassword() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final newPassword = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

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

    if (Supabase.instance.client.auth.currentUser == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Your recovery link has expired or is invalid. Please request a new reset email.',
          ),
        ),
      );
      navigator.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
      return;
    }

    setState(() => _saving = true);
    final updated = await AuthService.updatePassword(newPassword);
    if (!mounted) return;
    setState(() => _saving = false);

    if (updated) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
      navigator.pushNamedAndRemoveUntil(AppRoutes.root, (_) => false);
      return;
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Could not update password. Please try the link again.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_processingRecovery) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reset Password')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Processing your password reset link...',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_recoveryError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reset Password')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _recoveryError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _ensureRecoverySession,
                    child: const Text('Try again'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
                    },
                    child: const Text('Back to login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Choose a new password for your account.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                  ),
                  onSubmitted: (_) {
                    if (!_saving) {
                      _saveNewPassword();
                    }
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _saveNewPassword,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save new password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
