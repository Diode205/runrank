// main.dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/app_routes.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/painting.dart' as painting;

// Global RouteObserver to support auto-refresh on page resume
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1️⃣ Initialize Firebase FIRST
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2️⃣ Initialize Supabase SECOND
  await Supabase.initialize(
    url: 'https://yzccwmhgqlgguighfhsk.supabase.co',
    anonKey: 'sb_publishable_PxUqRg99ug7dqYnWG82M9A_pRukqS1k',
  );

  // 3️⃣ Crashlytics: capture Dart & platform errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true; // handled
  };

  // Trim image cache to reduce memory pressure on iOS
  try {
    painting.PaintingBinding.instance.imageCache
      ..maximumSize = 200
      ..maximumSizeBytes = 60 * 1024 * 1024; // 60MB
  } catch (_) {}

  runZonedGuarded(
    () {
      runApp(const LifecycleProbe(child: RunRankApp()));
    },
    (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}

// Logs lifecycle transitions to Crashlytics to help diagnose untethered crashes
class LifecycleProbe extends StatefulWidget {
  const LifecycleProbe({super.key, required this.child});
  final Widget child;

  @override
  State<LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<LifecycleProbe>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    FirebaseCrashlytics.instance.log('AppLifecycleState: $state');
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
      navigatorObservers: [routeObserver],
      home: const SplashScreen(nextPage: AuthGate()),
    );
  }
}
