import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:runrank/menu/expenses_claim_page.dart';

class PoliciesFormsNoticesPage extends StatelessWidget {
  const PoliciesFormsNoticesPage({super.key});

  static const _docs = [
    {
      'title': 'Health & Safety Policy',
      'url':
          'https://cdn.website-editor.net/s/f5f7040afe41439ba9e3a87ec810eef0/files/uploaded/Health_and_Safety_Policy_v1.0_June2025.pdf?Expires=1769482352&Signature=sc2HdxBDmpsQEpsDloHUm42Kc-T-~fC13Fu8SLcUegEjRUL71YxAiQS5~TZ8902-th8Te3gxlG1q5PSt5SY1Ij1~t~hZDsy34ZEE-9xgOqAwz0v5FMv29VP6B7DCLMx8NFFbqnkr1zO-0fkt~ZJEP-lp8kV1cp4GT~zuHTIeTH-OtGAJPCB2IJSiZOafaMVnDE8rfVu0fNYB~JUM6QOdNFQ7JPJlcKzd8WleS80e5i6PFSeyawQE362ZX6dWSJk7x7IM60sOnhjli-kMi5Nzvm56k7xhnwD2C3stlOqL-OJ8a5jePb-sRdL5OvDwEQBqgSwXxt-SmYiT22iBwGt2Ig__&Key-Pair-Id=K2NXBXLF010TJW',
    },
    {
      'title': 'Privacy Notice',
      'url':
          'https://cdn.website-editor.net/s/f5f7040afe41439ba9e3a87ec810eef0/files/uploaded/Privacy_Notice_v1.0_June2025.pdf?Expires=1769482352&Signature=FIesR9Mxoe~58hp7dAE7~QpFCvG7qnX5Gph6vGUOJqcgI-pHVxdMjlLMDo8tcA0Lug8SdLnpf9Nl5C~2~P0ydHzWEJe9t8n~eum6kgwqj1-U07HRs69RW3c-I5-NGLuRw-bbnJdGjEcZAZKtm4GaXHCv7UJWoJve-ZGcQMRNwdieyI-J~RuBvoZgJX~J4hQnrM5vVtQHXhcKbLjzAY5W3TOGw0owRN0AAO012JBDPnUPEtZe1KPfRGljF-WJ4F1JRQ7Azha6eLZX8~ilrvG9RURZcK~rR~L7GRWdROY0d7G2ggRFGaDaVTyat0YdY2EQHMva4gJxDiwbpnVzKvegXw__&Key-Pair-Id=K2NXBXLF010TJW',
    },
    {
      'title': 'Inclusion Policy',
      'url':
          'https://cdn.website-editor.net/s/f5f7040afe41439ba9e3a87ec810eef0/files/uploaded/Inclusion_Policy_v1.0_June2025.pdf?Expires=1769482352&Signature=niNcxoxuUFxyXSMTLJ7RZeAaBLMyL0tYNmmoPrRmnSDmdW61L0bzfPq9ODDrmkbQz5WlIYpeJNBTZiIb9US9u5eIsDqiSY4LKVjYFMD~DU0xbaLVLvnxnqJfEQ0JhmPNljMaci2CUUDDdALjxryvDxK8VkPH4g6U6oS-1FlKAepdCg-TkPNQAVs-wfmrXYCKZhXG7GTe696DV91TvfBh0Pr01SD7EM-rojbbsNhKVcK6vzvppgG~htR0ppNAPxGVLJh~KA-nQPp0jOCtg2OHNoDX-3r4g~1HYh83CrmWWkSkxNJLcz1hw7ELDoZ2PXj1E2RwEoLCpqMMBiGociwOAA__&Key-Pair-Id=K2NXBXLF010TJW',
    },
  ];

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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Policies & Notices',
          style: TextStyle(
            color: Color.fromRGBO(235, 246, 26, 1),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _hero(),
          const SizedBox(height: 20),
          _DocTile(
            title: 'Expenses Claim Form',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExpensesClaimPage()),
              );
            },
          ),
          const SizedBox(height: 8),
          ..._docs.map(
            (doc) => _DocTile(
              title: doc['title']!,
              onTap: () => _openLink(doc['url']!, context),
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
            'assets/images/nnbrdocs.png',
            height: 190,
            width: double.infinity,
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.25),
            colorBlendMode: BlendMode.darken,
          ),
          Container(
            height: 190,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xCC0A0C14),
                  Colors.transparent,
                  Color(0xCC0A0C14),
                ],
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
                children: const [
                  Text(
                    'Club Policies & Forms',
                    style: TextStyle(
                      color: Color.fromRGBO(39, 203, 236, 1),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Access Health & Safety, Privacy, Inclusion documents and essential forms.',
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
  final VoidCallback onTap;

  const _DocTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF0055FF).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.description, color: Color(0xFF56D3FF)),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: const Icon(Icons.open_in_new, color: Colors.white70),
      ),
    );
  }
}
