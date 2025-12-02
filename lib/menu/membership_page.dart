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
  String? _memberSince;
  String? _memberSinceRaw;
  String _membershipStatus = "Active"; // Always active for now
  String _membershipType = "Standard"; // Hard-coded, editable later

  @override
  void initState() {
    super.initState();
    _loadMembershipData();
  }

  Future<void> _loadMembershipData() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final row = await _client
          .from('user_profiles')
          .select('member_since')
          .eq('id', user.id)
          .maybeSingle();

      if (row != null && row['member_since'] != null) {
        _memberSinceRaw = row['member_since'];
        _memberSince = _formatMonthYear(row['member_since']);
      }
    } catch (e) {
      // ignore: avoid_print
      print("Error loading membership data: $e");
    }

    if (mounted) setState(() => _loading = false);
  }

  String _formatMonthYear(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];
      return "${months[dt.month - 1]} ${dt.year}";
    } catch (_) {
      return "-";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Membership")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _buildStatusCard(),
                const SizedBox(height: 20),
                _buildNNBRInfo(),
                const SizedBox(height: 20),
                _buildRenewButton(),
              ],
            ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Your Membership",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _infoRow("Status", _membershipStatus),
          _infoRow("Type", _membershipType),
          _infoRow("Member since", _memberSince ?? "-"),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildNNBRInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "About NNBR Membership",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            "North Norfolk Beach Runners (NNBR) welcomes runners of all levels. "
            "Membership includes access to club training sessions, group runs, "
            "club events, social activities, England Athletics affiliation options, "
            "and being part of a friendly and inclusive running community.",
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 12),
          Text(
            "Membership is renewed annually. Fees directly support club activities, "
            "equipment, coaching, facility use, and insurance coverage.",
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildRenewButton() {
    return ElevatedButton.icon(
      onPressed: () {
        // Opens NNBR membership page
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Renew Membership"),
            content: const Text(
              "Membership renewal via the official NNBR website will open in your browser.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _openNNBRMembershipURL();
                },
                child: const Text("Open Website"),
              ),
            ],
          ),
        );
      },
      icon: const Icon(Icons.payment),
      label: const Text("Renew Membership"),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontSize: 16),
      ),
    );
  }

  void _openNNBRMembershipURL() {
    _client.functions.invoke(
      'open-url',
      body: {'url': 'https://www.northnorfolkbeachrunners.com/membership'},
    );
  }
}
