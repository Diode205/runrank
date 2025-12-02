import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MerchandisePage extends StatelessWidget {
  const MerchandisePage({super.key});

  final String shopUrl = "https://www.northnorfolkbeachrunners.com/kit";

  final List<Map<String, dynamic>> items = const [
    {
      "name": "NNBR Running Vest",
      "price": "£20.00",
      "image":
          "https://static.wixstatic.com/media/b32f45_aaa81394a681423d83515a69f8f299ec~mv2.jpeg",
    },
    {
      "name": "NNBR Hoodie",
      "price": "£35.00",
      "image":
          "https://static.wixstatic.com/media/b32f45_3cb147f1b6774a2f825c2872d960d5fe~mv2.jpg",
    },
    {
      "name": "NNBR Bobble Hat",
      "price": "£12.00",
      "image":
          "https://static.wixstatic.com/media/b32f45_705f7113c6674a7f8f3bfce8dd65f27c~mv2.jpg",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Club Kit")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Official NNBR Kit",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          ...items.map((item) => _buildItemCard(item)).toList(),

          const SizedBox(height: 20),

          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text("Open Full Shop"),
            onPressed: () async {
              final uri = Uri.parse(shopUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            offset: const Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Image.network(
              item["image"],
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          ListTile(title: Text(item["name"]), subtitle: Text(item["price"])),
        ],
      ),
    );
  }
}
