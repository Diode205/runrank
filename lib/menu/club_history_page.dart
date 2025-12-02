import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ClubHistoryPage extends StatelessWidget {
  const ClubHistoryPage({super.key});

  final String articleUrl =
      "https://www.northnorfolkbeachrunners.com/nnbr-origin-story";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("NNBR Origin Story")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER IMAGE
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                "https://www.northnorfolkbeachrunners.com/_files/ugd/b32f45_18d7c93926e141c09a8330d78f701886.png",
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "North Norfolk Beach Runners began with a small group of runners "
              "who shared a passion for the beautiful coastline, the running "
              "community, and the joy of challenging themselves.\n\n"
              "Over time, NNBR grew into one of the most welcoming and active "
              "running clubs in East Anglia, offering training sessions, "
              "competitions, events and community engagement throughout the year.\n\n"
              "Our story continues — shaped by every member who becomes part "
              "of our journey.",
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text("Read Full Story on Website"),
              onPressed: () async {
                final uri = Uri.parse(articleUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
