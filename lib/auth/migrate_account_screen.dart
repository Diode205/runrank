import 'package:flutter/material.dart';
import 'package:runrank/app_routes.dart';
import 'package:runrank/services/migration_service.dart';

class MigrateAccountScreen extends StatefulWidget {
  final String newClub;

  const MigrateAccountScreen({super.key, required this.newClub});

  @override
  State<MigrateAccountScreen> createState() => _MigrateAccountScreenState();
}

class _MigrateAccountScreenState extends State<MigrateAccountScreen> {
  final TextEditingController _migrationCodeController =
      TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _migrationCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _migrationCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your migration code')),
      );
      return;
    }

    setState(() => _submitting = true);
    final applied = await MigrationService.applyMigration(
      migrationCode: code,
      newClub: widget.newClub,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!applied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not apply this migration code. It may be invalid, expired, or already used.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Your account has been migrated to ${widget.newClub}. You can now log in.',
        ),
      ),
    );

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Migrate Your Account')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New club: ${widget.newClub}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter the migration code provided by your current club admin. ',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _migrationCodeController,
              decoration: const InputDecoration(labelText: 'Migration Code'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const CircularProgressIndicator()
                    : const Text('Submit Migration Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
