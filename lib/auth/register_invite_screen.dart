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
  final _nameController = TextEditingController();
  final _ukaController = TextEditingController();
  final _inviteController = TextEditingController();
  bool _loading = false;
  bool _detailsSaved = false;
  String? _error;
  String? _savedName;
  String? _savedUka;

  @override
  void dispose() {
    _nameController.dispose();
    _ukaController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _saveMemberDetails() async {
    final name = _nameController.text.trim();
    final uka = _ukaController.text.trim();

    if (name.isEmpty || uka.isEmpty) {
      setState(() {
        _error = 'Enter your name and UKA athlete number.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final request = await AuthService.requestClubMemberInvite(
      club: widget.selectedClub,
      fullName: name,
      ukaNumber: uka,
    );

    if (!mounted) return;

    setState(() => _loading = false);

    if (request == null) {
      setState(() {
        _error =
            'We could not save your member details. Please check your name and UKA number, then try again.';
      });
      return;
    }

    setState(() {
      _detailsSaved = true;
      _savedName = request['full_name']?.toString() ?? name;
      _savedUka = request['uka_number']?.toString() ?? uka;
      _nameController.text = _savedName!;
      _ukaController.text = _savedUka!;
    });
  }

  Future<void> _continue() async {
    final uka = (_savedUka ?? _ukaController.text).trim();
    final invite = _inviteController.text.trim();

    if (!_detailsSaved || uka.isEmpty || invite.isEmpty) {
      setState(() {
        _error =
            'Save your member details first, then enter your member invite code.';
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
      appBar: AppBar(title: const Text('Member Details')),
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
              'Enter your member details first. This creates a pending invite request for your club admin to verify.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              readOnly: _detailsSaved,
              decoration: const InputDecoration(
                labelText: 'Full name',
                hintText: 'Enter your name as known by the club',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ukaController,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              readOnly: _detailsSaved,
              decoration: const InputDecoration(
                labelText: 'UKA athlete number',
                hintText: 'Enter your UKA number',
              ),
            ),
            const SizedBox(height: 14),
            if (!_detailsSaved)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _saveMemberDetails,
                  icon: const Icon(Icons.save_outlined),
                  label: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Member Details'),
                ),
              )
            else ...[
              const Text(
                'Your details have been saved. Please contact your club admin by text or call and ask for your unique member invite code.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () {
                        setState(() {
                          _detailsSaved = false;
                          _inviteController.clear();
                          _error = null;
                        });
                      },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit member details'),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _inviteController,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              enabled: _detailsSaved,
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
                onPressed: _loading || !_detailsSaved ? null : _continue,
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
