import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/services/payment_service.dart';
import 'package:runrank/services/user_service.dart';
import 'package:runrank/main.dart' show routeObserver;

class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key});

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> with RouteAware {
  final _client = Supabase.instance.client;

  bool _loading = true;
  bool _isAdmin = false;
  String? _memberSince;
  String? _membershipType;
  String? _fullName;
  String? _email;
  String? _ukaNumber;
  String? _dob;
  final String _membershipStatus = "Active";

  @override
  void initState() {
    super.initState();
    _initAdmin();
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
          .select(
            'member_since, membership_type, full_name, email, uka_number, date_of_birth',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (row != null && row['member_since'] != null) {
        _memberSince = _formatMonthYear(row['member_since']);
      }

      if (row != null && row['membership_type'] != null) {
        _membershipType = row['membership_type'] as String?;
      }

      _fullName = row?['full_name'] as String?;
      _email = row?['email'] as String?;
      _ukaNumber = row?['uka_number'] as String?;
      _dob = row?['date_of_birth'] as String?;
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

  String _formatFullDate(DateTime dt) {
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
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    return "$day $month ${dt.year}";
  }

  Future<void> _initAdmin() async {
    final isAdmin = await UserService.isAdmin();
    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
    });
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  "About NNBR Membership",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (_isAdmin)
                IconButton(
                  icon: const Icon(Icons.list_alt, color: Colors.white70),
                  tooltip: 'View membership status report (admin only)',
                  onPressed: _showMembershipStatusReport,
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "North Norfolk Beach Runners welcome runners of all levels. "
            "Memberships include access to club training sessions, group runs, "
            "club events, social activities, and being part of a friendly and inclusive community.",
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          const Text(
            "Membership is renewed annually. Fees directly support club activities, "
            "equipment, coaching, and community events.",
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          SizedBox(height: 12),
          if (_isAdmin)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showLapsedRenewalsReport,
                icon: const Icon(Icons.warning_amber_rounded, size: 18),
                label: const Text('View lapsed renewals list'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orangeAccent,
                  side: const BorderSide(color: Colors.orangeAccent, width: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showMembershipStatusReport() async {
    try {
      final rows = await _client
          .from('user_profiles')
          .select('full_name, email, membership_type, member_since')
          .order('full_name');

      if (rows.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No members found for report.')),
        );
        return;
      }

      final now = DateTime.now();
      final buffer = StringBuffer();
      buffer.writeln('NNBR Membership Status Report');
      buffer.writeln('Generated on ${_formatFullDate(now)}');
      buffer.writeln('');
      buffer.writeln('Name — Membership type — Member since — Renewal due');
      buffer.writeln('');

      for (final row in rows) {
        final name = (row['full_name'] as String?)?.trim();
        final email = (row['email'] as String?)?.trim();
        final membershipType = (row['membership_type'] as String?)?.trim();
        final memberSinceStr = row['member_since'] as String?;

        String memberSinceLabel = 'Not set';
        String renewalLabel = 'Unknown';

        if (memberSinceStr != null) {
          try {
            final dt = DateTime.parse(memberSinceStr);
            memberSinceLabel = _formatMonthYear(memberSinceStr);
            final due = DateTime(dt.year + 1, dt.month, dt.day);
            renewalLabel = _formatFullDate(due);
          } catch (_) {
            memberSinceLabel = 'Not set';
            renewalLabel = 'Unknown';
          }
        }

        final displayName = (name != null && name.isNotEmpty)
            ? name
            : (email ?? 'Unknown');
        final typeLabel = (membershipType != null && membershipType.isNotEmpty)
            ? membershipType
            : 'Not assigned';

        buffer.writeln(
          '$displayName — $typeLabel — $memberSinceLabel — $renewalLabel',
        );
      }

      final content = buffer.toString().trimRight();
      if (!mounted) return;
      await _showMembershipReportSheet(
        title: 'NNBR Membership Status Report',
        content: content,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading membership report: $e')),
      );
    }
  }

  Future<void> _showLapsedRenewalsReport() async {
    try {
      final rows = await _client
          .from('user_profiles')
          .select('full_name, email, membership_type, member_since')
          .order('full_name');

      if (rows.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No members found for report.')),
        );
        return;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final lapsed = <Map<String, dynamic>>[];

      for (final row in rows) {
        final name = (row['full_name'] as String?)?.trim();
        final email = (row['email'] as String?)?.trim();
        final membershipType = (row['membership_type'] as String?)?.trim();
        final memberSinceStr = row['member_since'] as String?;

        if (memberSinceStr == null) {
          continue; // cannot compute renewal without a start date
        }

        try {
          final dt = DateTime.parse(memberSinceStr);
          final due = DateTime(dt.year + 1, dt.month, dt.day);
          final dueDateOnly = DateTime(due.year, due.month, due.day);
          if (dueDateOnly.isBefore(today)) {
            final displayName = (name != null && name.isNotEmpty)
                ? name
                : (email ?? 'Unknown');
            final typeLabel =
                (membershipType != null && membershipType.isNotEmpty)
                ? membershipType
                : 'Not assigned';
            lapsed.add({
              'name': displayName,
              'type': typeLabel,
              'memberSinceLabel': _formatMonthYear(memberSinceStr),
              'renewalLabel': _formatFullDate(due),
              'due': dueDateOnly,
            });
          }
        } catch (_) {
          // ignore rows with invalid dates
        }
      }

      if (lapsed.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No lapsed renewals found.')),
        );
        return;
      }

      lapsed.sort((a, b) {
        final da = a['due'] as DateTime;
        final db = b['due'] as DateTime;
        return da.compareTo(db);
      });

      final buffer = StringBuffer();
      buffer.writeln('Lapsed Membership Renewals');
      buffer.writeln('Generated on ${_formatFullDate(now)}');
      buffer.writeln('');
      buffer.writeln('Name — Membership type — Member since — Renewal due');
      buffer.writeln('');

      for (final entry in lapsed) {
        buffer.writeln(
          '${entry['name']} — ${entry['type']} — '
          '${entry['memberSinceLabel']} — ${entry['renewalLabel']}',
        );
      }

      final content = buffer.toString().trimRight();
      if (!mounted) return;
      await _showMembershipReportSheet(
        title: 'Lapsed Membership Renewals',
        content: content,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading lapsed renewals: $e')),
      );
    }
  }

  Future<void> _showMembershipReportSheet({
    required String title,
    required String content,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              media.viewInsets.bottom + 20,
            ),
            child: SizedBox(
              height: media.size.height * 0.65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        content,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: content),
                            );
                            if (Navigator.canPop(sheetContext)) {
                              Navigator.pop(sheetContext);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Copied membership report to clipboard.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copy'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: Colors.white38,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _exportMembershipReportAsPdf(title, content);
                          },
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('Export PDF'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: Colors.white38,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportMembershipReportAsPdf(
    String title,
    String content,
  ) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            content,
            style: const pw.TextStyle(fontSize: 11, height: 1.3),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  void _handleBuy(String tierName) {
    final user = _client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to continue')),
      );
      return;
    }

    final amountMap = <String, int>{
      '1st Claim': 3000, // £30.00
      '2nd Claim': 1500, // £15.00
      'Social': 500, // £5.00
      'Full-Time Education': 1500, // £15.00
    };

    final amountCents = amountMap[tierName];
    if (amountCents == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unknown membership tier.')));
      return;
    }

    () async {
      try {
        final metadata = {
          'user_id': user.id,
          'full_name': _fullName,
          'email': _email,
          'uka_number': _ukaNumber,
          'date_of_birth': _dob,
          'membership_type_requested': tierName,
        };

        final paid = await PaymentService.startMembershipPayment(
          context: context,
          tierName: tierName,
          amountCents: amountCents,
          metadata: metadata,
        );

        if (!paid) return;

        // Optimistic update; in production prefer webhook confirmation
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
          SnackBar(content: Text('Membership purchased: $tierName')),
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
