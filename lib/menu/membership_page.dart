import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:runrank/menu/rnr_ekiden_eaccl_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
          : CustomScrollView(
              slivers: [
                // Pinned header with the top status card
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _FixedHeaderDelegate(
                    extent: 140,
                    child: Container(
                      color: Colors.black,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: _buildStatusCard(),
                    ),
                  ),
                ),
                // Scrollable page content below the sticky header
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildMembershipInfo(),
                      const SizedBox(height: 24),
                      _buildMembershipTiers(),
                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusCard() {
    final colorScheme = Theme.of(context).colorScheme;
    Color borderColor = colorScheme.primary;

    // Avoid washed-out white borders if the primary is very bright
    if (borderColor.computeLuminance() > 0.8) {
      borderColor = colorScheme.secondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.25),
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
              color: Color.fromRGBO(230, 240, 89, 1),
            ),
          ),
          const SizedBox(height: 6),
          _infoRow("Status", _membershipStatus),
          const SizedBox(height: 2),
          _infoRow("Type", _membershipType ?? "Not assigned"),
          const SizedBox(height: 2),
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
    String assetPath;
    var invertLogo = false;

    switch (type) {
      case "First Claim (Including UKA)":
        assetPath = "assets/images/nrrlogo1.png";
        break;
      case "Second Claim":
        assetPath = "assets/images/nrrlogo1.png";
        invertLogo = true;
        break;
      default:
        assetPath = "assets/images/rank_logo.png";
    }

    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: ColorFiltered(
          colorFilter: invertLogo
              ? const ColorFilter.matrix(<double>[
                  -1,
                  0,
                  0,
                  0,
                  255,
                  0,
                  -1,
                  0,
                  0,
                  255,
                  0,
                  0,
                  -1,
                  0,
                  255,
                  0,
                  0,
                  0,
                  1,
                  0,
                ])
              : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
          child: Image.asset(
            assetPath,
            width: 65,
            height: 65,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildMembershipTiers() {
    final colorScheme = Theme.of(context).colorScheme;
    var firstClaimColor = colorScheme.primary;
    var secondClaimColor = colorScheme.secondary;

    if (secondClaimColor.computeLuminance() > 0.9) {
      secondClaimColor = Colors.white70;
    }

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
          color: firstClaimColor,
          title: "First Claim (Including UKA)",
          subtitle: "Full club membership",
          price: "£42",
          details:
              "1 year membership. Includes £19 England Athletics athlete registration.",
          buttonColor: firstClaimColor,
          onBuy: () => _handleBuy("1st Claim"),
        ),
        const SizedBox(height: 12),
        _membershipTierCard(
          color: secondClaimColor,
          title: "Second Claim",
          subtitle: "Second claim membership",
          price: "£23",
          details:
              "1 year membership for runners registered first claim with another club.",
          buttonColor: secondClaimColor,
          onBuy: () => _handleBuy("2nd Claim"),
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
    final buttonTextColor = buttonColor.computeLuminance() > 0.6
        ? Colors.black
        : Colors.white;

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
                "Request to Raise an Order",
                style: TextStyle(
                  color: buttonTextColor,
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

  Widget _buildMembershipInfo() {
    final colorScheme = Theme.of(context).colorScheme;
    Color borderColor = colorScheme.primary;

    // Fall back to accent if primary is too close to white
    if (borderColor.computeLuminance() > 0.8) {
      borderColor = colorScheme.secondary;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "About NRR Membership",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color.from(
                        alpha: 1,
                        red: 0.941,
                        green: 0.925,
                        blue: 0.024,
                      ),
                    ),
                    textAlign: TextAlign.left,
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
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.white70),
              children: [
                const TextSpan(
                  text:
                      'Your Norwich Road Runners Membership includes access to all of the clubs training and road running sessions, use of the facilities, affiliation with UK Athletics (£19) with a discount on entering races.\n\nFor more information visit ',
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: _launchEnglandAthleticsRegistration,
                    child: Text(
                      'UK Athletic',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.secondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            "When entering races as an affiliated club runner, please note that official club race vests or T-shirts must be worn.\n\n"
            "Membership also includes:",
            style: TextStyle(fontSize: 13, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.white70),
              children: [
                const TextSpan(text: '• Affiliation with '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: _launchAthleticsNorfolk,
                    child: Text(
                      'Athletics Norfolk',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.secondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const TextSpan(
                  text:
                      '. This makes you eligible for county championship team prizes',
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.white70),
              children: [
                const TextSpan(text: '• Team access to the '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: _openRelayAndCrossCountryPage,
                    child: Text(
                      'Round Norfolk Relay',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.secondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.white70),
              children: [
                const TextSpan(text: '• Free entry and subsidised travel to '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: _openRelayAndCrossCountryPage,
                    child: Text(
                      'Norfolk',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.secondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: ' and '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: _openRelayAndCrossCountryPage,
                    child: Text(
                      'National Cross Country',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.secondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: ' events'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Access to our social events (Christmas party, club social nights etc) and most importantly, the ability to meet with, train and socialise with a large group of friendly and like-minded individuals.',
            style: TextStyle(fontSize: 13, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.white70),
              children: [
                const TextSpan(
                  text:
                      'An opportunity to apply for a club London Marathon Ballot space ',
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: _showEligibilityAndApplicationComingSoon,
                    child: Text(
                      '(Eligibility & Application)',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.secondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (_isAdmin)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showLapsedRenewalsReport,
                icon: const Icon(Icons.warning_amber_rounded, size: 18),
                label: const Text('View Lapsed Renewals List'),
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
      final clubName = await UserService.currentClubName();
      var query = _client
          .from('user_profiles')
          .select('full_name, email, membership_type, member_since, club');
      if (clubName != null && clubName.isNotEmpty) {
        query = query.eq('club', clubName);
      }
      final rows = await query.order('full_name');

      if (rows.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No members found for report.')),
        );
        return;
      }

      final now = DateTime.now();
      final buffer = StringBuffer();
      buffer.writeln('NRR Membership Status Report');
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
        title: 'NRR Membership Status Report',
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
      final clubName = await UserService.currentClubName();
      var query = _client
          .from('user_profiles')
          .select('full_name, email, membership_type, member_since, club');
      if (clubName != null && clubName.isNotEmpty) {
        query = query.eq('club', clubName);
      }
      final rows = await query.order('full_name');

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
    try {
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

      final safeTitle = title.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]+'),
        '_',
      );

      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: '${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting PDF: $e')));
    }
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
        final clubName = await UserService.currentClubName();
        if (clubName == null || clubName.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to determine your club. Please contact an administrator.',
              ),
            ),
          );
          return;
        }

        final committeeRows = await _client
            .from('committee_roles')
            .select('role, email')
            .eq('club', clubName);

        String? membershipSecretaryEmail;
        for (final row in committeeRows) {
          final role = ((row['role'] as String?) ?? '').toLowerCase();
          final email = (row['email'] as String?)?.trim();
          if (role.contains('membership secretary') &&
              email != null &&
              email.isNotEmpty) {
            membershipSecretaryEmail = email;
            break;
          }
        }

        if (membershipSecretaryEmail == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No Membership Secretary email is configured yet in the admin committee roles.',
              ),
            ),
          );
          return;
        }

        final statusText = tierName == '1st Claim'
            ? 'First Claim'
            : tierName == '2nd Claim'
            ? 'Second Claim'
            : tierName;

        final body =
            'I intend to renew my club membership on a $statusText status. '
            'May I therefore request to please raise an order through the UK Athletic to complete my registration and the payment required.';

        final uri = Uri(
          scheme: 'mailto',
          path: membershipSecretaryEmail,
          queryParameters: {'subject': 'Raise Membership Order', 'body': body},
        );

        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open your email app.')),
          );
        }
      } catch (e) {
        debugPrint('Error requesting membership order: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Request failed: $e')));
      }
    }();
  }

  Future<void> _launchEnglandAthleticsRegistration() async {
    final uri = Uri.parse(
      'https://www.englandathletics.org/take-part/athlete-registration/',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open England Athletics link.')),
      );
    }
  }

  Future<void> _launchAthleticsNorfolk() async {
    final uri = Uri.parse('https://athleticsnorfolk.org.uk/');

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Athletics Norfolk link.')),
      );
    }
  }

  void _openRelayAndCrossCountryPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RnrEkidenEacclPage()),
    );
  }

  void _showEligibilityAndApplicationComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Eligibility & Application page coming soon.'),
      ),
    );
  }
}

// Simple fixed-extent header delegate to pin the top box
class _FixedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double extent;

  _FixedHeaderDelegate({required this.child, required this.extent});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _FixedHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.extent != extent;
  }
}
