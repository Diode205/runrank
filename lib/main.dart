// main.dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'splash_screen.dart';
import 'auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/app_routes.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:runrank/services/payment_service.dart';
import 'package:runrank/services/club_config_service.dart';
import 'dart:io';

// Global RouteObserver to support auto-refresh on page resume
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

bool _isTransientNetworkError(Object error) {
  // Supabase wraps some network issues in AuthException with a SocketException
  if (error is AuthException) {
    final msg = error.message ?? '';
    if (msg.contains('Failed host lookup') || msg.contains('SocketException')) {
      return true;
    }
  }

  if (error is SocketException) {
    // Typical offline / DNS failure
    return true;
  }

  return false;
}

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // 1️⃣ Initialize Firebase FIRST
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 2️⃣ Initialize Supabase SECOND
      await Supabase.initialize(
        url: 'https://yzccwmhgqlgguighfhsk.supabase.co',
        anonKey: 'sb_publishable_PxUqRg99ug7dqYnWG82M9A_pRukqS1k',
      );

      // 2b️⃣ Stripe setup (safe if keys not provided)
      await PaymentService.init();

      // 3️⃣ Crashlytics: capture Dart & platform errors
      final bool crashlyticsEnabled =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android);

      if (crashlyticsEnabled) {
        FlutterError.onError = (FlutterErrorDetails details) {
          final error = details.exception;
          if (_isTransientNetworkError(error)) {
            // Log as non-fatal to avoid noisy "crashes" when offline
            FirebaseCrashlytics.instance.recordError(
              error,
              details.stack,
              fatal: false,
            );
          } else {
            FirebaseCrashlytics.instance.recordFlutterFatalError(details);
          }
        };
        ui.PlatformDispatcher.instance.onError = (error, stack) {
          if (_isTransientNetworkError(error)) {
            FirebaseCrashlytics.instance.recordError(
              error,
              stack,
              fatal: false,
            );
            return true; // handled gracefully
          }
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true; // handled
        };
      } else {
        // On web/unsupported platforms, avoid Crashlytics calls
        FlutterError.onError = FlutterError.dumpErrorToConsole;
        ui.PlatformDispatcher.instance.onError = (error, stack) {
          // Return false to allow default error handling
          return false;
        };
      }

      // Trim image cache to reduce memory pressure on iOS
      try {
        painting.PaintingBinding.instance.imageCache
          ..maximumSize = 200
          ..maximumSizeBytes = 60 * 1024 * 1024; // 60MB
      } catch (_) {}

      runApp(const LifecycleProbe(child: RunRankApp()));
    },
    (error, stack) {
      final bool crashlyticsEnabled =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android);
      if (crashlyticsEnabled) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
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
    final bool crashlyticsEnabled =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    if (crashlyticsEnabled) {
      FirebaseCrashlytics.instance.log('AppLifecycleState: $state');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class RunRankApp extends StatefulWidget {
  const RunRankApp({super.key});

  @override
  State<RunRankApp> createState() => _RunRankAppState();
}

class _RunRankAppState extends State<RunRankApp> {
  ClubConfig? _clubConfig;

  @override
  void initState() {
    super.initState();
    _loadClubConfig();
  }

  Future<void> _loadClubConfig() async {
    final config = await ClubConfigService.loadForCurrentUser();
    if (!mounted) return;
    setState(() {
      _clubConfig = config;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = _clubConfig?.primaryColor ?? const Color(0xFFFFD300);
    final accentColor = _clubConfig?.accentColor ?? const Color(0xFF0057B7);
    final backgroundColor = _clubConfig?.backgroundColor ?? Colors.black;

    return MaterialApp(
      title: 'RunRank',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: backgroundColor,
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: primaryColor,
          secondary: accentColor,
          surface: Colors.grey.shade900,
          background: backgroundColor,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: backgroundColor,
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
          backgroundColor: backgroundColor,
          indicatorColor: primaryColor.withOpacity(0.3),
          labelTextStyle: MaterialStatePropertyAll(
            TextStyle(color: accentColor),
          ),
          iconTheme: MaterialStatePropertyAll(
            IconThemeData(color: accentColor),
          ),
        ),
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
            borderSide: BorderSide(color: accentColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: primaryColor, width: 2),
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
