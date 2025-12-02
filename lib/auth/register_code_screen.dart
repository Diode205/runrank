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
                if (_codeController.text.trim() == "NNBR2025") {
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
