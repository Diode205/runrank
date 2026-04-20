import 'package:flutter/material.dart';
import 'package:runrank/services/charity_service.dart';
import 'package:runrank/services/user_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CharityPage extends StatefulWidget {
  const CharityPage({super.key});

  @override
  State<CharityPage> createState() => _CharityPageState();
}

class _CharityPageState extends State<CharityPage> {
  static const String _introText =
      'The club support local charities as part of our service to the community, aligned with our vision and values. Through fundraising, volunteering, and participation in charitable events, we contribute beyond sport, helping strengthen community connections and support causes that matter to our members and the wider public.';

  final TextEditingController _websiteController = TextEditingController();

  bool _loadingClub = true;
  bool _isAdmin = false;
  bool _saving = false;
  String? _clubName;
  String? _seededCharityKey;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    final clubName = await UserService.currentClubName();
    final isAdmin = await UserService.isAdmin();
    if (!mounted) return;
    setState(() {
      _clubName = clubName;
      _isAdmin = isAdmin;
      _loadingClub = false;
    });
  }

  bool get _isNrrClub {
    final lower = (_clubName ?? '').trim().toLowerCase();
    return lower == 'nrr' || lower.contains('norwich road runners');
  }

  List<Color> get _brandGradient => UserService.clubBrandGradient(_clubName);

  Color get _backgroundColor =>
      _isNrrClub ? const Color(0xFF140708) : const Color(0xFF07121F);

  Color get _surfaceColor =>
      _isNrrClub ? const Color(0xFF241112) : const Color(0xFF0F111A);

  Color get _primaryColor =>
      _isNrrClub ? const Color(0xFFD32F2F) : const Color(0xFF0057B7);

  Color get _accentColor => _isNrrClub ? Colors.white : const Color(0xFFFFD300);

  Color get _borderColor =>
      _isNrrClub ? const Color(0x66D32F2F) : const Color(0x66FFD300);

  Color get _overlayLabelColor =>
      _isNrrClub ? const Color(0xFFF5D7D7) : const Color(0xFFE8F1FF);

  String _formatCurrency(dynamic amount) {
    final value = amount is num
        ? amount.toDouble()
        : double.tryParse(amount?.toString() ?? '') ?? 0;
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
  }

  Uri? _parseUri(dynamic rawValue) {
    final raw = rawValue?.toString().trim() ?? '';
    if (raw.isEmpty) return null;

    final withScheme = raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : 'https://$raw';

    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty) return null;
    return uri;
  }

  Future<void> _launchExternal(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the link')));
    }
  }

  void _seedAdminFields(Map<String, dynamic>? charity) {
    final key = '${charity?['id'] ?? 'new'}|${charity?['website_url'] ?? ''}';
    if (_seededCharityKey == key) return;

    _websiteController.text =
        (charity?['website_url'] as String?)?.trim() ?? '';
    _seededCharityKey = key;
  }

  Future<void> _saveAdminFields() async {
    final website = _websiteController.text.trim();

    setState(() => _saving = true);
    try {
      await CharityService.saveCharityBasics(
        clubName: _clubName,
        websiteUrl: website,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Charity details updated')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _showEditCharityDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surfaceColor,
        title: const Text(
          'Edit Charity',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: _websiteController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Website Link'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Close', style: TextStyle(color: _accentColor)),
          ),
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    await _saveAdminFields();
                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                  },
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTotalRaisedDialog(dynamic currentAmount) async {
    final controller = TextEditingController(
      text: _formatCurrency(currentAmount),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surfaceColor,
        title: const Text(
          'Club Donations',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Total Amount Donated (£)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Close', style: TextStyle(color: _accentColor)),
          ),
          FilledButton(
            onPressed: () async {
              final newTotal = double.tryParse(controller.text.trim());
              if (newTotal == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid amount')),
                );
                return;
              }

              await CharityService.updateTotalRaised(
                clubName: _clubName,
                newTotal: newTotal,
              );

              if (!mounted) return;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Donation total updated')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Charity Of The Year'),
        actions: [
          if (_isAdmin)
            IconButton(
              tooltip: 'Edit charity',
              onPressed: _showEditCharityDialog,
              icon: const Icon(Icons.edit),
            ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _brandGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _loadingClub
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: CharityService.watchCharities(clubName: _clubName),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                final charity = rows.isEmpty ? null : rows.first;

                if (_isAdmin) {
                  _seedAdminFields(charity);
                }

                return _buildContent(charity);
              },
            ),
    );
  }

  Widget _buildContent(Map<String, dynamic>? charity) {
    final websiteUri = _parseUri(charity?['website_url']);
    final totalRaised = _formatCurrency(charity?['total_raised']);
    final previewController = websiteUri == null
        ? null
        : (WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..loadRequest(websiteUri));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCard(
            child: const Text(
              _introText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                height: 1.45,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildDonationButton(
            totalRaised,
            currentAmount: charity?['total_raised'],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildCard(
              child: _buildPreviewPanel(
                websiteUri: websiteUri,
                previewController: previewController,
                expandToFill: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationButton(String totalRaised, {dynamic currentAmount}) {
    return FilledButton.icon(
      onPressed: _isAdmin ? () => _showTotalRaisedDialog(currentAmount) : null,
      icon: const Icon(Icons.favorite),
      style: FilledButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _primaryColor,
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      ),
      label: Text('Club Donations  £$totalRaised'),
    );
  }

  Widget _buildPreviewPanel({
    required Uri? websiteUri,
    required WebViewController? previewController,
    bool expandToFill = false,
  }) {
    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: expandToFill ? null : 360,
        color: Colors.black26,
        child: websiteUri == null || previewController == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No charity website has been linked yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  WebViewWidget(controller: previewController),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => _launchExternal(websiteUri),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Visit Charity',
                            style: TextStyle(
                              color: _overlayLabelColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );

    if (expandToFill) {
      return SizedBox.expand(child: preview);
    }

    return preview;
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.75)),
      filled: true,
      fillColor: Colors.black26,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _accentColor),
      ),
    );
  }
}
