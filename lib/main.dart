// main.dart
import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/app_routes.dart'; // ✅ ADD THIS

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase initialization
  await Supabase.initialize(
    url: 'https://yzccwmhgqlgguighfhsk.supabase.co',
    anonKey: 'sb_publishable_PxUqRg99ug7dqYnWG82M9A_pRukqS1k',
  );

  runApp(const RunRankApp());
}

class RunRankApp extends StatelessWidget {
  const RunRankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RunRank',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.blueAccent,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),

      // 💡 Use named routes everywhere
      routes: AppRoutes.routes, // ✅ ADD THIS LINE
      /// 💡 KEEP THIS EXACTLY AS IT IS
      home: const SplashScreen(nextPage: AuthGate()),
    );
  }
}
