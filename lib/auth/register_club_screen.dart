import 'package:flutter/material.dart';
import 'package:runrank/auth/register_code_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterClubScreen extends StatefulWidget {
  const RegisterClubScreen({super.key});

  @override
  State<RegisterClubScreen> createState() => _RegisterClubScreenState();
}

class _RegisterClubScreenState extends State<RegisterClubScreen> {
  String? _selectedClub;
  final _supabase = Supabase.instance.client;
  final List<String> _clubs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClubs();
  }

  Future<void> _loadClubs() async {
    try {
      final data = await _supabase
          .from('app_clubs')
          .select('name')
          .order('name', ascending: true);

      if (!mounted) return;

      setState(() {
        _clubs
          ..clear()
          ..addAll([for (final row in data) (row['name'] ?? '').toString()]);
        _loading = false;
      });
    } catch (e) {
      // Fallback to existing hard-coded list if anything goes wrong
      if (!mounted) return;
      setState(() {
        _clubs
          ..clear()
          ..addAll([
            "NNBR (North Norfolk Beach Runners)",
            "Generic Running Club",
            "Aylsham Runners",
            "Norfolk Gazelles",
            "Norwich Road Runners",
            "Runners-next-the-Sea",
            "Wymondham Athletic Club",
          ]);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Your Club")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedClub,
                    decoration: const InputDecoration(labelText: "Club"),
                    items: _clubs
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
