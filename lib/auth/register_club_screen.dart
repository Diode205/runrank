import 'package:flutter/material.dart';
import 'package:runrank/auth/register_code_screen.dart';

class RegisterClubScreen extends StatefulWidget {
  const RegisterClubScreen({super.key});

  @override
  State<RegisterClubScreen> createState() => _RegisterClubScreenState();
}

class _RegisterClubScreenState extends State<RegisterClubScreen> {
  String? _selectedClub;

  final List<String> clubs = [
    "NNBR (North Norfolk Beach Runners)",
    "Generic Running Club",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Your Club")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedClub,
              decoration: const InputDecoration(labelText: "Club"),
              items: clubs
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedClub = v),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedClub == null
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RegisterCodeScreen(
                              selectedClub: _selectedClub!,
                            ),
                          ),
                        );
                      },
                child: const Text("Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
