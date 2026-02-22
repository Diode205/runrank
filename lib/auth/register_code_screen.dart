import 'package:flutter/material.dart';
import 'package:runrank/auth/register_profile_screen.dart';

class RegisterCodeScreen extends StatefulWidget {
  final String selectedClub;
  const RegisterCodeScreen({super.key, required this.selectedClub});

  @override
  State<RegisterCodeScreen> createState() => _RegisterCodeScreenState();
}

class _RegisterCodeScreenState extends State<RegisterCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  String? _error;

  static const Map<String, String> _clubVerificationCodes = {
    // Format: first letters (capitalised) + 2026
    'NNBR (North Norfolk Beach Runners)': 'NNBR2026',
    'Generic Running Club': 'GRC2026',
    'Aylsham Runners': 'AR2026',
    'Norfolk Gazelles': 'NG2026',
    'Norwich Road Runners': 'NRR2026',
    'Runners-next-the-Sea': 'RNTS2026',
    'Wymondham Athletic Club': 'WAC2026',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Enter Club Code')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Club Selected: ${widget.selectedClub}",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 25),
            const Text(
              "Enter Verification Code",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),

            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                hintText: "Enter club-provided code",
                errorText: _error,
              ),
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final enteredCode = _codeController.text.trim().toUpperCase();
                final expectedCode =
                    _clubVerificationCodes[widget.selectedClub] ?? '';

                if (enteredCode.isNotEmpty &&
                    enteredCode == expectedCode.toUpperCase()) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RegisterProfileScreen(
                        selectedClub: widget.selectedClub,
                      ),
                    ),
                  );
                } else {
                  setState(() {
                    _error = "Invalid club code. Please try again.";
                  });
                }
              },
              child: const Text("Continue"),
            ),
          ],
        ),
      ),
    );
  }
}
