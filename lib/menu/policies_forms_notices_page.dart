import 'package:flutter/material.dart';
import 'package:runrank/services/user_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:runrank/menu/expenses_claim_page.dart';

class PoliciesFormsNoticesPage extends StatefulWidget {
  const PoliciesFormsNoticesPage({super.key});

  @override
  State<PoliciesFormsNoticesPage> createState() =>
      _PoliciesFormsNoticesPageState();
}

class _PoliciesFormsNoticesPageState extends State<PoliciesFormsNoticesPage> {
  static const _defaultDocs = [
    _GovernanceDoc(
      title: 'Health & Safety Policy',
      url:
          'https://cdn.website-editor.net/s/f5f7040afe41439ba9e3a87ec810eef0/files/uploaded/Health_and_Safety_Policy_v1.0_June2025.pdf?Expires=1769482352&Signature=sc2HdxBDmpsQEpsDloHUm42Kc-T-~fC13Fu8SLcUegEjRUL71YxAiQS5~TZ8902-th8Te3gxlG1q5PSt5SY1Ij1~t~hZDsy34ZEE-9xgOqAwz0v5FMv29VP6B7DCLMx8NFFbqnkr1zO-0fkt~ZJEP-lp8kV1cp4GT~zuHTIeTH-OtGAJPCB2IJSiZOafaMVnDE8rfVu0fNYB~JUM6QOdNFQ7JPJlcKzd8WleS80e5i6PFSeyawQE362ZX6dWSJk7x7IM60sOnhjli-kMi5Nzvm56k7xhnwD2C3stlOqL-OJ8a5jePb-sRdL5OvDwEQBqgSwXxt-SmYiT22iBwGt2Ig__&Key-Pair-Id=K2NXBXLF010TJW',
    ),
    _GovernanceDoc(
      title: 'Privacy Notice',
      url:
          'https://cdn.website-editor.net/s/f5f7040afe41439ba9e3a87ec810eef0/files/uploaded/Privacy_Notice_v1.0_June2025.pdf?Expires=1769482352&Signature=FIesR9Mxoe~58hp7dAE7~QpFCvG7qnX5Gph6vGUOJqcgI-pHVxdMjlLMDo8tcA0Lug8SdLnpf9Nl5C~2~P0ydHzWEJe9t8n~eum6kgwqj1-U07HRs69RW3c-I5-NGLuRw-bbnJdGjEcZAZKtm4GaXHCv7UJWoJve-ZGcQMRNwdieyI-J~RuBvoZgJX~J4hQnrM5vVtQHXhcKbLjzAY5W3TOGw0owRN0AAO012JBDPnUPEtZe1KPfRGljF-WJ4F1JRQ7Azha6eLZX8~ilrvG9RURZcK~rR~L7GRWdROY0d7G2ggRFGaDaVTyat0YdY2EQHMva4gJxDiwbpnVzKvegXw__&Key-Pair-Id=K2NXBXLF010TJW',
    ),
    _GovernanceDoc(
      title: 'Inclusion Policy',
      url:
          'https://cdn.website-editor.net/s/f5f7040afe41439ba9e3a87ec810eef0/files/uploaded/Inclusion_Policy_v1.0_June2025.pdf?Expires=1769482352&Signature=niNcxoxuUFxyXSMTLJ7RZeAaBLMyL0tYNmmoPrRmnSDmdW61L0bzfPq9ODDrmkbQz5WlIYpeJNBTZiIb9US9u5eIsDqiSY4LKVjYFMD~DU0xbaLVLvnxnqJfEQ0JhmPNljMaci2CUUDDdALjxryvDxK8VkPH4g6U6oS-1FlKAepdCg-TkPNQAVs-wfmrXYCKZhXG7GTe696DV91TvfBh0Pr01SD7EM-rojbbsNhKVcK6vzvppgG~htR0ppNAPxGVLJh~KA-nQPp0jOCtg2OHNoDX-3r4g~1HYh83CrmWWkSkxNJLcz1hw7ELDoZ2PXj1E2RwEoLCpqMMBiGociwOAA__&Key-Pair-Id=K2NXBXLF010TJW',
    ),
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

  String? _clubName;
  bool _loadingClub = true;

  @override
  void initState() {
    super.initState();
    _loadClub();
  }

  Future<void> _loadClub() async {
    final clubName = await UserService.currentClubName();
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

  List<_GovernanceDoc> get _docs => _isNrrClub ? _nrrDocs : _defaultDocs;

  String get _pageTitle => 'Club Governance';

  String get _heroTitle => _isNrrClub ? 'NRR Governance' : 'Club Governance';

  String get _heroSubtitle => _isNrrClub
      ? 'Access Norwich Road Runners governance documents and core club policies.'
      : 'Access club policies, notices and essential forms.';

  String get _heroImage =>
      _isNrrClub ? 'assets/images/nrrgov2.png' : 'assets/images/nnbrdocs.png';

  Color get _backgroundColor =>
      _isNrrClub ? const Color(0xFF140708) : Colors.black;

  Color get _surfaceColor =>
      _isNrrClub ? const Color(0xFF241112) : Colors.white.withOpacity(0.04);

  Color get _borderColor =>
      _isNrrClub ? const Color(0x66D32F2F) : Colors.white12;

  Color get _accentColor => _isNrrClub
      ? const Color(0xFFD32F2F)
      : const Color.fromRGBO(235, 246, 26, 1);

  Color get _secondaryAccentColor => _isNrrClub
      ? const Color(0xFFFFE9E9)
      : const Color.fromRGBO(39, 203, 236, 1);

  Color get _iconBackgroundColor => _isNrrClub
      ? const Color(0x29D32F2F)
      : const Color(0xFF0055FF).withOpacity(0.15);

  Color get _iconColor => _isNrrClub ? Colors.white : const Color(0xFF56D3FF);

  List<Color> get _heroGradientColors => _isNrrClub
      ? const [Color(0xE6D32F2F), Color(0xB3140708), Color(0xE6140708)]
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
                if (!_isNrrClub) ...[
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
