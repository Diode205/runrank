import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:runrank/menu/rnr_ekiden_eaccl_page.dart';
import 'package:runrank/services/membership_tier_config_service.dart';
import 'package:runrank/services/payment_service.dart';
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
  final _tierConfigService = MembershipTierConfigService();
  static const _nnbrYellow = Color(0xFFF5C542);
  static const _nnbrBlue = Color(0xFF0057B7);
  static const _socialGray = Color(0xFF8A8F98);
  static const _educationGreen = Color(0xFF2E8B57);

  bool _loading = true;
  bool _isAdmin = false;
  String? _memberSince;
  String? _membershipType;
  String? _clubName;
  Map<String, MembershipTierConfig> _tierConfigs = const {};
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
      _clubName = await UserService.currentClubName();
      _tierConfigs = await _tierConfigService.fetchConfigs(_clubName);

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

  bool get _isNrrClub {
    final normalized = (_clubName ?? '').trim().toLowerCase();
    return normalized == 'norwich road runners' || normalized == 'nrr';
  }

  bool get _showDigitalMembershipBackup =>
      _isNrrClub && PaymentService.nrrMembershipPaymentsEnabled;

  Color get _clubPrimaryColor =>
      _isNrrClub ? const Color(0xFFD32F2F) : _nnbrYellow;

  Color get _clubSecondaryColor => _isNrrClub ? Colors.white : _nnbrBlue;

  Map<String, int> get _defaultTierAmounts => _isNrrClub
      ? const {'1st Claim': 4200, '2nd Claim': 2300}
      : const {
          '1st Claim': 3000,
          '2nd Claim': 1500,
          'Social': 500,
          'Full-Time Education': 1500,
        };

  int _amountPenceForTier(String tierName) =>
      _tierConfigs[tierName]?.amountPence ?? _defaultTierAmounts[tierName] ?? 0;

  String _priceLabelForTier(String tierName) =>
      '£${(_amountPenceForTier(tierName) / 100).toStringAsFixed(0)}';

  Future<void> _showEditAmountDialog(String tierName) async {
    final clubName = _clubName;
    if (!_isAdmin || clubName == null || clubName.trim().isEmpty) return;

    final controller = TextEditingController(
      text: (_amountPenceForTier(tierName) / 100).toStringAsFixed(2),
    );
    final messenger = ScaffoldMessenger.of(context);

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        title: Text(
          'Edit $tierName amount',
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Amount (£)',
            labelStyle: TextStyle(color: Colors.white70),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldSave != true) return;

    final parsedAmount = double.tryParse(
      controller.text.trim().replaceAll('£', ''),
    );
    if (parsedAmount == null || parsedAmount < 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount.')),
      );
      return;
    }

    try {
      await _tierConfigService.updateAmount(
        clubName: clubName,
        tierName: tierName,
        amountPence: (parsedAmount * 100).round(),
      );
      final refreshed = await _tierConfigService.fetchConfigs(clubName);
      if (!mounted) return;
      setState(() {
        _tierConfigs = refreshed;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('$tierName amount updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update amount: $e')),
      );
    }
  }

  Future<String?> _membershipSecretaryEmailForClub(String clubName) async {
    final committeeRows = await _client
        .from('committee_roles')
        .select('role, email')
        .eq('club', clubName);

    for (final row in committeeRows) {
      final role = ((row['role'] as String?) ?? '').toLowerCase();
      final email = (row['email'] as String?)?.trim();
      if (role.contains('membership secretary') &&
          email != null &&
          email.isNotEmpty) {
        return email;
      }
    }

    return null;
  }

  String _membershipStatusLabel(String tierName) {
    return tierName == '1st Claim'
        ? 'First Claim'
        : tierName == '2nd Claim'
        ? 'Second Claim'
        : tierName;
  }

  Future<bool> _launchMembershipRequestEmail({
    required String membershipSecretaryEmail,
    required String tierName,
    bool paymentCompleted = false,
  }) async {
    final statusText = _membershipStatusLabel(tierName);
    final body = paymentCompleted
        ? 'I have completed a Stripe payment for my $statusText club membership renewal. '
              'May I therefore request that the UK Athletics registration order is now raised and confirmed.'
        : 'I intend to renew my club membership on a $statusText status. '
              'May I therefore request to please raise an order through the UK Athletic to complete my registration and the payment required.';

    final uri = Uri(
      scheme: 'mailto',
      path: membershipSecretaryEmail,
      queryParameters: {
        'subject': paymentCompleted
            ? 'Membership Payment Completed'
            : 'Raise Membership Order',
        'body': body,
      },
    );

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _handleDigitalBuy({
    required String tierName,
    required int amountCents,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = _client.auth.currentUser;
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please log in to continue')),
      );
      return;
    }

    try {
      final clubName = _clubName ?? await UserService.currentClubName();
      if (clubName == null || clubName.isEmpty) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to determine your club. Please contact an administrator.',
            ),
          ),
        );
        return;
      }

      if (!mounted) return;

      final paid = await PaymentService.startMembershipPayment(
        context: context,
        tierName: tierName,
        amountCents: amountCents,
        metadata: {
          'context': 'membership_renewal',
          'club': clubName,
          'membership_tier': tierName,
          'user_id': user.id,
        },
      );

      if (!paid || !mounted) {
        return;
      }

      final membershipSecretaryEmail = await _membershipSecretaryEmailForClub(
        clubName,
      );

      if (!mounted) return;

      if (membershipSecretaryEmail == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Payment succeeded, but no Membership Secretary email is configured yet.',
            ),
          ),
        );
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Payment received'),
            content: const Text(
              'Your payment has been completed. Email the Membership Secretary now to finish the current NRR renewal process.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  final launched = await _launchMembershipRequestEmail(
                    membershipSecretaryEmail: membershipSecretaryEmail,
                    tierName: tierName,
                    paymentCompleted: true,
                  );

                  if (!launched && mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Could not open your email app.'),
                      ),
                    );
                  }
                },
                child: const Text('Email Membership Secretary'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('Error starting digital membership payment: $e');
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Payment failed: $e')));
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
    final borderColor = _clubPrimaryColor.computeLuminance() > 0.8
        ? _clubSecondaryColor
        : _clubPrimaryColor;

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
              color: Colors.white,
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
    if (!_isNrrClub) {
      String assetPath;
      switch (type) {
        case '1st Claim':
          assetPath = 'assets/images/firstclaim.png';
          break;
        case '2nd Claim':
          assetPath = 'assets/images/secondclaim.png';
          break;
        case 'Social':
          assetPath = 'assets/images/socialclaim.png';
          break;
        case 'Full-Time Education':
          assetPath = 'assets/images/fulleduc.png';
          break;
        default:
          assetPath = 'assets/images/nnbr_logo.png';
      }

      return Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(assetPath, fit: BoxFit.contain),
        ),
      );
    }

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
    final firstClaimColor = _isNrrClub ? _clubPrimaryColor : _nnbrYellow;
    final secondClaimColor = _isNrrClub ? _clubSecondaryColor : _nnbrBlue;

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
        if (_isNrrClub) ...[
          _membershipTierCard(
            color: firstClaimColor,
            tierName: '1st Claim',
            title: "First Claim (Including UKA)",
            subtitle: "Full club membership",
            details:
                "1 year membership. Includes £19 England Athletics athlete registration.",
            buttonColor: firstClaimColor,
            onBuy: () => _handleBuy("1st Claim"),
            onDigitalBuy: _showDigitalMembershipBackup
                ? () => _handleDigitalBuy(
                    tierName: '1st Claim',
                    amountCents: _amountPenceForTier('1st Claim'),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          _membershipTierCard(
            color: secondClaimColor,
            tierName: '2nd Claim',
            title: "Second Claim",
            subtitle: "Second claim membership",
            details:
                "1 year membership for runners registered first claim with another club.",
            buttonColor: secondClaimColor,
            onBuy: () => _handleBuy("2nd Claim"),
            onDigitalBuy: _showDigitalMembershipBackup
                ? () => _handleDigitalBuy(
                    tierName: '2nd Claim',
                    amountCents: _amountPenceForTier('2nd Claim'),
                  )
                : null,
          ),
        ] else ...[
          _membershipTierCard(
            color: _nnbrYellow,
            tierName: '1st Claim',
            title: "1st Claim",
            subtitle: "Standard membership",
            details:
                "1 year membership. Includes £20 England Athletics athlete registration.",
            buttonColor: _nnbrYellow,
            onBuy: () => _handleBuy("1st Claim"),
          ),
          const SizedBox(height: 12),
          _membershipTierCard(
            color: _nnbrBlue,
            tierName: '2nd Claim',
            title: "2nd Claim",
            subtitle: "Secondary membership",
            details:
                "1 year membership for runners registered first claim with another club.",
            buttonColor: _nnbrBlue,
            onBuy: () => _handleBuy("2nd Claim"),
          ),
          const SizedBox(height: 12),
          _membershipTierCard(
            color: _socialGray,
            tierName: 'Social',
            title: "Social",
            subtitle: "Social membership",
            details:
                "1 year membership for social members and non-runners who want to stay involved with the club.",
            buttonColor: _socialGray,
            onBuy: () => _handleBuy("Social"),
          ),
          const SizedBox(height: 12),
          _membershipTierCard(
            color: _educationGreen,
            tierName: 'Full-Time Education',
            title: "Full-Time Education",
            subtitle: "Student membership",
            details:
                "1 year membership for full-time students who want full access to club membership benefits.",
            buttonColor: _educationGreen,
            onBuy: () => _handleBuy("Full-Time Education"),
          ),
        ],
      ],
    );
  }

  Widget _membershipTierCard({
    required Color color,
    required String tierName,
    required String title,
    required String subtitle,
    required String details,
    required Color buttonColor,
    required VoidCallback onBuy,
    VoidCallback? onDigitalBuy,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _priceLabelForTier(tierName),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (_isAdmin)
                    TextButton.icon(
                      onPressed: () => _showEditAmountDialog(tierName),
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
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
                _isNrrClub ? "Request to Raise an Order" : "Buy",
                style: TextStyle(
                  color: buttonTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (onDigitalBuy != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDigitalBuy,
                icon: const Icon(Icons.payment),
                label: const Text(
                  'Pay in App with Stripe',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: color.withValues(alpha: 0.75)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMembershipInfo() {
    final borderColor = _clubPrimaryColor.computeLuminance() > 0.8
        ? _clubSecondaryColor
        : _clubPrimaryColor;

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
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _isNrrClub
                        ? "About NRR Membership"
                        : "About NNBR Membership",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _clubPrimaryColor.computeLuminance() > 0.8
                          ? _clubSecondaryColor
                          : _clubPrimaryColor,
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
                TextSpan(
                  text: _isNrrClub
                      ? 'Your Norwich Road Runners Membership includes access to all of the clubs training and road running sessions, use of the facilities, affiliation with UK Athletics (£19) with a discount on entering races.\n\nFor more information visit '
                      : 'NNBR membership keeps you connected to club training, racing, social events and member activities across the year.\n\nFor more information visit ',
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: _launchEnglandAthleticsRegistration,
                    child: Text(
                      _isNrrClub ? 'UK Athletic' : 'England Athletics',
                      style: TextStyle(
                        fontSize: 13,
                        color: _clubSecondaryColor,
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
          if (_isNrrClub) ...[
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
                          color: _clubSecondaryColor,
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
                          color: _clubSecondaryColor,
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
                  const TextSpan(
                    text: '• Free entry and subsidised travel to ',
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      onTap: _openRelayAndCrossCountryPage,
                      child: Text(
                        'Norfolk',
                        style: TextStyle(
                          fontSize: 13,
                          color: _clubSecondaryColor,
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
                          color: _clubSecondaryColor,
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
                          color: _clubSecondaryColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            const Text(
              'NNBR membership offers four membership types so runners, social members and students can choose the option that fits them best.',
              style: TextStyle(fontSize: 13, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Choose First Claim, Second Claim, Social or Full-Time Education membership depending on your current athletics status and how you want to take part in club life.',
              style: TextStyle(fontSize: 13, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Membership supports training, racing, club communications and social events throughout the year.',
              style: TextStyle(fontSize: 13, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
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
                            final navigator = Navigator.of(sheetContext);
                            final messenger = ScaffoldMessenger.of(context);
                            await Clipboard.setData(
                              ClipboardData(text: content),
                            );
                            if (!mounted) return;
                            if (navigator.canPop()) {
                              navigator.pop();
                            }
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Copied membership report to clipboard.',
                                ),
                              ),
                            );
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
        final amountCents = _amountPenceForTier(tierName);
        if (!_isNrrClub) {
          final paid = await PaymentService.startMembershipPayment(
            context: context,
            tierName: tierName,
            amountCents: amountCents,
            metadata: {
              'context': 'membership_renewal',
              'club': _clubName,
              'membership_tier': tierName,
              'user_id': user.id,
            },
          );

          if (!paid) return;

          final updates = {
            'membership_type': tierName,
            if (_memberSince == null)
              'member_since': DateTime.now().toIso8601String(),
          };

          await _client.from('user_profiles').update(updates).eq('id', user.id);

          if (!mounted) return;
          setState(() {
            _membershipType = tierName;
            _memberSince ??= _formatMonthYear(DateTime.now().toIso8601String());
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Membership purchased: $tierName')),
          );
          return;
        }

        final clubName = _clubName ?? await UserService.currentClubName();
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

        final membershipSecretaryEmail = await _membershipSecretaryEmailForClub(
          clubName,
        );

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

        final launched = await _launchMembershipRequestEmail(
          membershipSecretaryEmail: membershipSecretaryEmail,
          tierName: tierName,
        );

        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open your email app.')),
          );
        }
      } catch (e) {
        debugPrint('Error requesting membership order: $e');
        if (!mounted) return;
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
