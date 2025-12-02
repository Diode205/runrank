import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:runrank/services/charity_service.dart';

class CharityPage extends StatefulWidget {
  const CharityPage({super.key});

  @override
  State<CharityPage> createState() => _CharityPageState();
}

class _CharityPageState extends State<CharityPage> {
  bool _loading = true;
  Map<String, dynamic>? _charity;

  @override
  void initState() {
    super.initState();
    _loadCharity();
  }

  Future<void> _loadCharity() async {
    final data = await CharityService.getCharity();
    setState(() {
      _charity = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Charity of the Year")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _charity == null
          ? const Center(
              child: Text(
                "Charity information not set up yet.",
                style: TextStyle(fontSize: 16),
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final charity = _charity!;
    final name = charity['charity_name'] ?? 'Unknown Charity';
    final url = charity['donate_url'] ?? '';
    final total = charity['total_raised']?.toString() ?? "0";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Club message box
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              "North Norfolk Beach Runners is proud to support our chosen "
              "charity of the year. Together we help our community through "
              "fundraising, volunteering, and events.\n\n"
              "(Club message or mission statement can be edited here.)",
              style: TextStyle(fontSize: 16),
            ),
          ),

          const SizedBox(height: 20),

          // Charity name + amount
          Text(
            name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Text(
            "Total Raised: £$total",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),

          const SizedBox(height: 30),

          // Donate button
          ElevatedButton.icon(
            icon: const Icon(Icons.volunteer_activism),
            label: const Text("Donate Now"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              backgroundColor: Colors.orange,
              textStyle: const TextStyle(fontSize: 18),
            ),
            onPressed: url.isEmpty
                ? null
                : () async {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
          ),

          const SizedBox(height: 40),

          const Text(
            "All donations go directly to our charity partner.\n"
            "Thank you for making a difference ❤️",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
