import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/main.dart' show routeObserver;

class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key});

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> with RouteAware {
  final _client = Supabase.instance.client;

  bool _loading = true;
  String? _memberSince;
  String? _membershipType;
  final String _membershipStatus = "Active";

  @override
  void initState() {
    super.initState();
    _loadMembershipData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Called when returning to this page (e.g., after closing quick-edit)
  @override
  void didPopNext() {
    _loadMembershipData();
  }

  Future<void> _loadMembershipData() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final row = await _client
          .from('user_profiles')
          .select('member_since, membership_type')
          .eq('id', user.id)
          .maybeSingle();

      if (row != null && row['member_since'] != null) {
        _memberSince = _formatMonthYear(row['member_since']);
      }

      if (row != null && row['membership_type'] != null) {
        _membershipType = row['membership_type'] as String?;
      }
    } catch (e) {
      debugPrint("Error loading membership data: $e");
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
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
      return "Not set";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Membership & Renewal"),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStatusCard(),
                const SizedBox(height: 24),
                _buildNNBRInfo(),
                const SizedBox(height: 24),
                _buildMembershipTiers(),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0057B7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0057B7).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "My Membership",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _infoRow("Status", _membershipStatus),
          const SizedBox(height: 8),
          _infoRow("Type", _membershipType ?? "Not assigned"),
          const SizedBox(height: 8),
          _infoRow("Member Since", _memberSince ?? "Not set"),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildMembershipBadge(String type, Color color) {
    // Display membership badge with actual logo image
    String assetPath;
    switch (type) {
      case "1st Claim":
        assetPath = "assets/images/firstclaim.png";
        break;
      case "2nd Claim":
        assetPath = "assets/images/secondclaim.png";
        break;
      case "Social":
        assetPath = "assets/images/socialclaim.png";
        break;
      case "Full-Time Education":
        assetPath = "assets/images/fulleduc.png";
        break;
      default:
        assetPath = "assets/images/nnbr_logo.png";
    }

    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Image.asset(
          assetPath,
          width: 65,
          height: 65,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildMembershipTiers() {
    // NOTE: Membership type is determined during user registration/signup flow
    // When a user selects their membership tier during signup, that selection
    // (\"1st Claim\", \"2nd Claim\", \"Social\", or \"Full-Time Education\") is stored
    // in the database `user_profiles.membership_type` field.
    // This page then fetches and displays that stored value.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Membership Options",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        _membershipTierCard(
          color: const Color(0xFFFFD700),
          title: "1st Claim",
          subtitle: "Standard Membership",
          price: "£30",
          details: "1 year • £20 to England Athletics",
          buttonColor: const Color(0xFFFFD700),
          onBuy: () => _handleBuy("1st Claim"),
        ),
        const SizedBox(height: 12),
        _membershipTierCard(
          color: const Color(0xFF0055FF),
          title: "2nd Claim",
          subtitle: "Secondary Membership",
          price: "£15",
          details: "1 year for 2nd claim runners",
          buttonColor: const Color(0xFF0055FF),
          onBuy: () => _handleBuy("2nd Claim"),
        ),
        const SizedBox(height: 12),
        _membershipTierCard(
          color: Colors.grey,
          title: "Social",
          subtitle: "Social Membership",
          price: "£5",
          details: "1 year for social members / non-runners",
          buttonColor: Colors.grey,
          onBuy: () => _handleBuy("Social"),
        ),
        const SizedBox(height: 12),
        _membershipTierCard(
          color: const Color(0xFF2E8B57),
          title: "Full-Time Education",
          subtitle: "Student Membership",
          price: "£15",
          details: "1 year for students (Limited: 9 remaining)",
          buttonColor: const Color(0xFF2E8B57),
          onBuy: () => _handleBuy("Full-Time Education"),
        ),
      ],
    );
  }

  Widget _membershipTierCard({
    required Color color,
    required String title,
    required String subtitle,
    required String price,
    required String details,
    required Color buttonColor,
    required VoidCallback onBuy,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildMembershipBadge(title, color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            details,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onBuy,
              child: Text(
                "Buy",
                style: TextStyle(
                  color: color == const Color(0xFFFFD700)
                      ? Colors.black
                      : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNNBRInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "About NNBR Membership",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Text(
            "North Norfolk Beach Runners welcome runners of all levels. "
            "Memberships include access to club training sessions, group runs, "
            "club events, social activities, and being part of a friendly and inclusive community.",
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          SizedBox(height: 12),
          Text(
            "Membership is renewed annually. Fees directly support club activities, "
            "equipment, coaching, and community events.",
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  void _handleBuy(String tierName) {
    final user = _client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to continue')),
      );
      return;
    }

    () async {
      try {
        final updates = {
          'membership_type': tierName,
          if (_memberSince == null)
            'member_since': DateTime.now().toIso8601String(),
        };

        final updated = await _client
            .from('user_profiles')
            .update(updates)
            .eq('id', user.id)
            .select()
            .maybeSingle();

        debugPrint('Membership update saved row: $updated');

        setState(() {
          _membershipType = tierName;
          _memberSince ??= _formatMonthYear(DateTime.now().toIso8601String());
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Membership updated: $tierName')),
        );
      } catch (e) {
        debugPrint('Error updating membership_type: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }();
  }
}
