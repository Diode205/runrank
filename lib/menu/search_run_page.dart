import 'package:flutter/material.dart';
import 'package:runrank/widgets/web_link_preview_card.dart';

class SearchRunPage extends StatelessWidget {
  const SearchRunPage({super.key});

  static const _sites = [
    _SearchRunSite(
      title: 'Total Race Timing',
      tabTitle: 'Total Race Timing',
      url: 'https://totalracetiming.co.uk/race',
    ),
    _SearchRunSite(
      title: 'Running Calendar UK',
      tabTitle: 'Running Calendar UK',
      url: 'https://www.runningcalendar.co.uk/calendar/',
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
            'Search & Run',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Total Race Timing'),
              Tab(text: 'Running Calendar UK'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: TabBarView(
            physics: NeverScrollableScrollPhysics(),
            children: [
              for (final site in _sites) _SearchRunSiteView(site: site),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchRunSiteView extends StatefulWidget {
  const _SearchRunSiteView({required this.site});

  final _SearchRunSite site;

  @override
  State<_SearchRunSiteView> createState() => _SearchRunSiteViewState();
}

class _SearchRunSiteViewState extends State<_SearchRunSiteView>
    with AutomaticKeepAliveClientMixin<_SearchRunSiteView> {
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
              child: WebLinkPreviewCard(
                url: site.url,
                buttonLabel: 'Visit Site',
                height: constraints.maxHeight,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchRunSite {
  const _SearchRunSite({
    required this.title,
    required this.tabTitle,
    required this.url,
  });

  final String title;
  final String tabTitle;
  final String url;
}
