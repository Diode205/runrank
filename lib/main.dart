// main.dart
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:runrank/auth/reset_password_screen.dart';
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
    final msg = error.message;
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
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );

      // 2b️⃣ Stripe setup is optional. Never let payment configuration stop
      // the login screen from loading during a fresh App Review install.
      try {
        await PaymentService.init();
      } catch (e, stack) {
        debugPrint('Stripe init failed, continuing without payments: $e');
        FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
      }

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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final AppLinks _appLinks = AppLinks();
  ClubConfig? _clubConfig;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<Uri>? _deepLinkSubscription;
  Uri? _pendingRecoveryUri;
  bool _passwordRecoveryScreenOpen = false;
  bool _passwordRecoveryMode = false;

  void _handleClubConfigRefresh() {
    _loadClubConfig();
  }

  @override
  void initState() {
    super.initState();
    ClubConfigService.refreshNotifier.addListener(_handleClubConfigRefresh);
    _loadClubConfig();
    _listenForPasswordRecoveryLinks();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final event = data.event;

      if (!mounted) return;

      if (event == AuthChangeEvent.signedOut) {
        setState(() {
          _clubConfig = null;
        });
        return;
      }

      if (event == AuthChangeEvent.passwordRecovery) {
        _openPasswordRecoveryScreen();
      }

      _loadClubConfig();
    });
  }

  @override
  void dispose() {
    ClubConfigService.refreshNotifier.removeListener(_handleClubConfigRefresh);
    _authSubscription?.cancel();
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadClubConfig() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      if (!mounted) return;
      setState(() {
        _clubConfig = null;
      });
      return;
    }

    final config = await ClubConfigService.loadForCurrentUser();
    if (!mounted) return;
    setState(() {
      _clubConfig = config;
    });
  }

  bool _isPasswordRecoveryLink(Uri uri) {
    final normalizedPath = uri.path.toLowerCase();
    return uri.scheme == 'runrank' &&
        uri.host == 'login-callback' &&
        normalizedPath == '/reset-password';
  }

  Future<void> _listenForPasswordRecoveryLinks() async {
    _deepLinkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (_isPasswordRecoveryLink(uri)) {
        _openPasswordRecoveryScreen(recoveryUri: uri);
      }
    });

    try {
      Uri? initialUri;
      try {
        initialUri = await (_appLinks as dynamic).getInitialAppLink();
      } on NoSuchMethodError {
        initialUri = await (_appLinks as dynamic).getInitialLink();
      }

      if (initialUri != null && _isPasswordRecoveryLink(initialUri)) {
        _openPasswordRecoveryScreen(recoveryUri: initialUri);
      }
    } catch (_) {
      // If reading the initial deep link fails, the auth listener still
      // handles the common recovery path.
    }
  }

  void _openPasswordRecoveryScreen({Uri? recoveryUri}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _navigatorKey.currentState;
      if (!mounted || _passwordRecoveryScreenOpen) return;

      setState(() {
        _passwordRecoveryMode = true;
        _pendingRecoveryUri = recoveryUri ?? _pendingRecoveryUri;
      });

      if (navigator == null) return;

      _passwordRecoveryScreenOpen = true;
      navigator
          .pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(
                recoveryUri: recoveryUri ?? _pendingRecoveryUri,
              ),
              settings: const RouteSettings(name: AppRoutes.resetPassword),
            ),
            (_) => false,
          )
          .whenComplete(() {
            _passwordRecoveryScreenOpen = false;
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasClubConfig = _clubConfig != null;
    final primaryColor = hasClubConfig
        ? _clubConfig!.primaryColor
        : Colors.white;
    final accentColor = hasClubConfig
        ? _clubConfig!.accentColor
        : Colors.white70;
    final backgroundColor = hasClubConfig
        ? _clubConfig!.backgroundColor
        : Colors.black;

    return MaterialApp(
      navigatorKey: _navigatorKey,
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
          indicatorColor: primaryColor.withValues(alpha: 0.3),
          labelTextStyle: WidgetStatePropertyAll(TextStyle(color: accentColor)),
          iconTheme: WidgetStatePropertyAll(IconThemeData(color: accentColor)),
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
      home: _passwordRecoveryMode
          ? ResetPasswordScreen(recoveryUri: _pendingRecoveryUri)
          : const SplashScreen(nextPage: AuthGate()),
    );
  }
}
