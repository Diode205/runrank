import 'package:flutter/material.dart';
import 'package:runrank/widgets/web_link_preview_card.dart';

class AthleticsPortalPower10Page extends StatelessWidget {
  const AthleticsPortalPower10Page({super.key});

  static const _sites = [
    _AthleticsSite(
      title: 'Athletics Portal',
      url: 'https://myathleticsportal.englandathletics.org/Account/Login',
    ),
    _AthleticsSite(
      title: 'Power of 10',
      url: 'https://www.powerof10.uk/Home/AthleteSearch',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _sites.length,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          centerTitle: true,
          title: const Text(
            'Athletics Portal & Power of 10',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Athletics'),
              Tab(text: 'Power of 10'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: TabBarView(
            physics: NeverScrollableScrollPhysics(),
            children: [
              for (final site in _sites) _AthleticsSiteView(site: site),
            ],
          ),
        ),
      ),
    );
  }
}

class _AthleticsSiteView extends StatefulWidget {
  const _AthleticsSiteView({required this.site});

  final _AthleticsSite site;

  @override
  State<_AthleticsSiteView> createState() => _AthleticsSiteViewState();
}

class _AthleticsSiteViewState extends State<_AthleticsSiteView>
    with AutomaticKeepAliveClientMixin<_AthleticsSiteView> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final site = widget.site;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF5C542), width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                children: [
                  WebLinkPreviewCard(
                    url: site.url,
                    buttonLabel: 'Visit Site',
                    height: constraints.maxHeight,
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        site.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AthleticsSite {
  const _AthleticsSite({required this.title, required this.url});

  final String title;
  final String url;
}
