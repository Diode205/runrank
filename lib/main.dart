// main.dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1️⃣ Initialize Firebase FIRST
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2️⃣ Initialize Supabase SECOND
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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,

        colorScheme: ColorScheme.dark(
          primary: Color(0xFFFFD300), // NNBR Yellow
          secondary: Color(0xFF0057B7), // NNBR Blue
          surface: Colors.grey.shade900,
          background: Colors.black,
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),

        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
        ),

        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.black,
          indicatorColor: Color(0xFF0057B7).withOpacity(0.3),
          labelTextStyle: const MaterialStatePropertyAll(
            TextStyle(color: Color(0xFFFFD300)),
          ),
          iconTheme: const MaterialStatePropertyAll(
            IconThemeData(color: Color(0xFFFFD300)),
          ),
        ),

        // ⭐ FINAL MERGED INPUT THEME (only one!)
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1A1A1A),

          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white38),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white24),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF0057B7)), // Blue
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFFFFD300), // Yellow
              width: 2,
            ),
          ),

          errorBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Colors.redAccent),
          ),

          focusedErrorBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Colors.redAccent, width: 2),
          ),
        ),
      ),

      routes: AppRoutes.routes,
      home: const SplashScreen(nextPage: AuthGate()),
    );
  }
}
