import 'package:flutter/material.dart';
import 'package:runrank/auth/register_profile_screen.dart';
import 'package:runrank/services/auth_service.dart';

class RegisterInviteScreen extends StatefulWidget {
  final String selectedClub;

  const RegisterInviteScreen({super.key, required this.selectedClub});

  @override
  State<RegisterInviteScreen> createState() => _RegisterInviteScreenState();
}

class _RegisterInviteScreenState extends State<RegisterInviteScreen> {
  final _ukaController = TextEditingController();
  final _inviteController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ukaController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final uka = _ukaController.text.trim();
    final invite = _inviteController.text.trim();

    if (uka.isEmpty || invite.isEmpty) {
      setState(() {
        _error = 'Enter both your UKA number and member invite code.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final match = await AuthService.validateClubMemberInvite(
      club: widget.selectedClub,
      ukaNumber: uka,
      inviteCode: invite,
    );

    if (!mounted) return;

    setState(() => _loading = false);

    if (match == null) {
      setState(() {
        _error =
            'The UKA number and member invite code do not match. Please go back and check the club code, or check that your UKA number and invite code are correct.';
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterProfileScreen(
          selectedClub: widget.selectedClub,
          verifiedInviteId: match['invite_id']?.toString(),
          verifiedUkaNumber: match['uka_number']?.toString(),
          prefillFullName: match['full_name']?.toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Member Invite')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Text(
              'Club Selected: ${widget.selectedClub}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'Enter your UKA athlete number and the unique invite code provided by your club admin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ukaController,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'UKA athlete number',
                hintText: 'Enter your UKA number',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _inviteController,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _loading ? null : _continue(),
              decoration: const InputDecoration(
                labelText: 'Member invite code',
                hintText: 'Enter your unique code',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, height: 1.35),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _continue,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
