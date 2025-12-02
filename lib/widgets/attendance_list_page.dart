import 'package:flutter/material.dart';

class AttendanceListPage extends StatelessWidget {
  final String title;
  final List<String> names;

  const AttendanceListPage({
    super.key,
    required this.title,
    required this.names,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: names.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final name = names[index];
          return ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(name),
          );
        },
      ),
    );
  }
}
