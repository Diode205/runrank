import 'package:flutter/material.dart';
import 'package:runrank/services/user_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:runrank/menu/expenses_claim_page.dart';

class PoliciesFormsNoticesPage extends StatefulWidget {
  final String? initialClubName;

  const PoliciesFormsNoticesPage({super.key, this.initialClubName});

  @override
  State<PoliciesFormsNoticesPage> createState() =>
      _PoliciesFormsNoticesPageState();
}

class _PoliciesFormsNoticesPageState extends State<PoliciesFormsNoticesPage> {
  static const _defaultDocs = [
    _GovernanceDoc(title: 'Health & Safety Policy'),
    _GovernanceDoc(title: 'Privacy Notice'),
    _GovernanceDoc(title: 'Inclusion Policy'),
  ];

  static const _nrrDocs = [
    _GovernanceDoc(
      title: 'Club Constitution',
      url:
          'https://img1.wsimg.com/blobby/go/b95e7360-e03d-412e-902c-a9f82cbfccb0/downloads/_Norwich%20Road%20Runners%20Club%20Constitution%20Nov%2020.pdf?ver=1773002944276',
    ),
    _GovernanceDoc(
      title: 'Code of Conduct',
      url:
          'https://img1.wsimg.com/blobby/go/b95e7360-e03d-412e-902c-a9f82cbfccb0/downloads/601b138b-8f69-4403-83a9-66702b983dbb/NRR%20Cde%20of%20conduct.pdf?ver=1773002944277',
    ),
    _GovernanceDoc(
      title: 'Officer Roles',
      url:
          'https://img1.wsimg.com/blobby/go/b95e7360-e03d-412e-902c-a9f82cbfccb0/downloads/cc964c27-42b0-4ecf-b2c9-5d7e71214731/NRR%20Officer%20roles.pdf?ver=1773002944277',
    ),
    _GovernanceDoc(
      title: 'Health & Safety Policy',
      url:
          'https://img1.wsimg.com/blobby/go/b95e7360-e03d-412e-902c-a9f82cbfccb0/downloads/Norwich%20Road%20Runner%20Health%20and%20Safety%20Policy.pdf?ver=1773002944277',
    ),
    _GovernanceDoc(
      title: 'Safeguarding and Child Welfare Policy',
      url:
          'https://img1.wsimg.com/blobby/go/b95e7360-e03d-412e-902c-a9f82cbfccb0/downloads/102e36a2-e143-48f9-972a-fde4d6c34d36/Safeguarding%20and%20child%20welfare%20policy%202025.pdf?ver=1773002944277',
    ),
    _GovernanceDoc(
      title: 'Safeguarding and Welfare Statement',
      url:
          'https://img1.wsimg.com/blobby/go/b95e7360-e03d-412e-902c-a9f82cbfccb0/downloads/cf1b42bc-b3d2-4425-bf31-da11b8a50d1c/Safeguarding%20and%20Welfare%20statement%202025.pdf?ver=1773002944277',
    ),
    _GovernanceDoc(
      title: 'Grievance & Disciplinary Procedures',
      url:
          'https://img1.wsimg.com/blobby/go/b95e7360-e03d-412e-902c-a9f82cbfccb0/downloads/GrievanceDiscilinary2016.pdf?ver=1773002944277',
    ),
  ];

  String? _clubName = UserService.cachedClubName;
  bool _loadingClub = true;

  @override
  void initState() {
    super.initState();
    _loadClub();
  }

  Future<void> _loadClub() async {
    final clubName =
        widget.initialClubName ?? await UserService.currentClubName();
    if (!mounted) return;
    setState(() {
      _clubName = clubName;
      _loadingClub = false;
    });
  }

  bool get _isNrrClub {
    final lower = (_clubName ?? '').trim().toLowerCase();
    return lower == 'nrr' || lower.contains('norwich road runners');
  }

  bool get _isYcrrClub {
    final lower = (_clubName ?? '').trim().toLowerCase();
    return lower == 'ycrr' || lower.contains('your club road runners');
  }

  bool get _clubResolved => (_clubName ?? '').trim().isNotEmpty;

  List<_GovernanceDoc> get _docs => !_clubResolved
      ? const []
      : _isNrrClub
      ? _nrrDocs
      : _defaultDocs;

  String get _pageTitle => 'Club Governance';

  String get _heroTitle => !_clubResolved
      ? 'Club Governance'
      : _isNrrClub
      ? 'NRR Governance'
      : _isYcrrClub
      ? 'YCRR Governance'
      : 'Club Governance';

  String get _heroSubtitle => !_clubResolved
      ? 'Access club policies, notices and essential forms.'
      : _isNrrClub
      ? 'Access Norwich Road Runners governance documents and core club policies.'
      : _isYcrrClub
      ? 'Sample governance documents can be connected for a live club build.'
      : 'Access club policies, notices and essential forms.';

  String get _heroImage => !_clubResolved
      ? 'assets/images/rank_logo.png'
      : _isNrrClub
      ? 'assets/images/nrrgov2.png'
      : _isYcrrClub
      ? 'assets/images/yourclublogo1.png'
      : 'assets/images/nnbrdocs.png';

  Color get _backgroundColor => !_clubResolved
      ? const Color(0xFF101010)
      : _isNrrClub
      ? const Color(0xFF140708)
      : _isYcrrClub
      ? const Color(0xFF10140F)
      : Colors.black;

  Color get _surfaceColor => !_clubResolved
      ? Colors.white.withOpacity(0.04)
      : _isNrrClub
      ? const Color(0xFF241112)
      : _isYcrrClub
      ? const Color(0xFF10140F)
      : Colors.white.withOpacity(0.04);

  Color get _borderColor => !_clubResolved
      ? Colors.white12
      : _isNrrClub
      ? const Color(0x66D32F2F)
      : _isYcrrClub
      ? const Color(0x6616803A)
      : Colors.white12;

  Color get _accentColor => !_clubResolved
      ? Colors.white70
      : _isNrrClub
      ? const Color(0xFFD32F2F)
      : _isYcrrClub
      ? const Color(0xFFFFD300)
      : const Color.fromRGBO(235, 246, 26, 1);

  Color get _secondaryAccentColor => !_clubResolved
      ? Colors.white
      : _isNrrClub
      ? const Color(0xFFD32F2F)
      : _isYcrrClub
      ? const Color(0xFF16803A)
      : const Color.fromRGBO(39, 203, 236, 1);

  Color get _iconBackgroundColor => !_clubResolved
      ? Colors.white.withOpacity(0.08)
      : _isNrrClub
      ? const Color(0x29D32F2F)
      : _isYcrrClub
      ? const Color(0x2916803A)
      : const Color(0xFF0055FF).withOpacity(0.15);

  Color get _iconColor => !_clubResolved
      ? Colors.white70
      : _isNrrClub
      ? Colors.white
      : _isYcrrClub
      ? const Color(0xFFFFD300)
      : const Color(0xFF56D3FF);

  List<Color> get _heroGradientColors => !_clubResolved
      ? const [Color(0xCC181818), Colors.transparent, Color(0xCC181818)]
      : _isNrrClub
      ? const [Color(0xE6D32F2F), Color(0xB3140708), Color(0xE6140708)]
      : _isYcrrClub
      ? const [Color(0xCC16803A), Colors.transparent, Color(0xCC10140F)]
      : const [Color(0xCC0A0C14), Colors.transparent, Color(0xCC0A0C14)];

  Future<void> _openLink(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        title: Text(
          _pageTitle,
          style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _loadingClub
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _hero(),
                const SizedBox(height: 20),
                if (!_isNrrClub && !_isYcrrClub) ...[
                  _DocTile(
                    title: 'Expenses Claim Form',
                    backgroundColor: _surfaceColor,
                    borderColor: _borderColor,
                    iconBackgroundColor: _iconBackgroundColor,
                    iconColor: _iconColor,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ExpensesClaimPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                ..._docs.map(
                  (doc) => _DocTile(
                    title: doc.title,
                    subtitle: doc.url == null
                        ? 'Link to be added'
                        : (_isNrrClub ? 'Open document' : null),
                    backgroundColor: _surfaceColor,
                    borderColor: _borderColor,
                    iconBackgroundColor: _iconBackgroundColor,
                    iconColor: _iconColor,
                    trailingIcon: doc.url == null
                        ? Icons.schedule
                        : Icons.open_in_new,
                    onTap: doc.url == null
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Add the web link for "${doc.title}" to enable this document.',
                                ),
                              ),
                            );
                          }
                        : () => _openLink(doc.url!, context),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _hero() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Image.asset(
            _heroImage,
            height: 190,
            width: double.infinity,
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.25),
            colorBlendMode: BlendMode.darken,
          ),
          Container(
            height: 190,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _heroGradientColors,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _heroTitle,
                    style: TextStyle(
                      color: _secondaryAccentColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _heroSubtitle,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData trailingIcon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconBackgroundColor;
  final Color iconColor;

  const _DocTile({
    required this.title,
    required this.onTap,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconBackgroundColor,
    required this.iconColor,
    this.subtitle,
    this.trailingIcon = Icons.open_in_new,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: backgroundColor,
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBackgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.description, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
        trailing: Icon(trailingIcon, color: Colors.white70),
      ),
    );
  }
}

class _GovernanceDoc {
  final String title;
  final String? url;

  const _GovernanceDoc({required this.title, this.url});
}
