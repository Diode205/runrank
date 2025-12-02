import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key});

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  String _expiryText = "Unknown";
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _loadMembership();
  }

  Future<void> _loadMembership() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final row = await _client
        .from("user_profiles")
        .select("membership_expiry")
        .eq("id", user.id)
        .maybeSingle();

    if (row == null || row["membership_expiry"] == null) {
      setState(() {
        _isActive = false;
        _expiryText = "Not registered";
        _loading = false;
      });
      return;
    }

    final expiryString = row["membership_expiry"] as String;
    final expiry = DateTime.tryParse(expiryString);

    if (expiry == null) {
      setState(() {
        _expiryText = "Invalid date";
        _isActive = false;
        _loading = false;
      });
      return;
    }

    final today = DateTime.now();
    _isActive = expiry.isAfter(today);

    setState(() {
      _expiryText =
          "${expiry.day}/${expiry.month.toString().padLeft(2, '0')}/${expiry.year}";
      _loading = false;
    });
  }

  Future<void> _renew() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Online renewal will be added soon!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Membership")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Membership Status",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _isActive ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              _isActive
                  ? "Active until: $_expiryText"
                  : "Expired on: $_expiryText",
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.payment),
              label: const Text("Renew Membership"),
              onPressed: _renew,
            ),

            const Spacer(),

            const Center(
              child: Text(
                "NNBR Membership System\nRunRank © 2025",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
