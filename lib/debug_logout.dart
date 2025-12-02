// lib/debug_logout.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://yzccwmhgqlgguighfhsk.supabase.co',
    anonKey: 'sb_publishable_PxUqRg99ug7dqYnWG82M9A_pRukqS1k',
  );

  await Supabase.instance.client.auth.signOut();

  print("🔵 DEBUG: Local Supabase session cleared.");
  print("You can now close this and run the app normally.");

  runApp(const PlaceholderApp());
}

class PlaceholderApp extends StatelessWidget {
  const PlaceholderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            "Supabase session cleared.\nYou may close this now.",
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
