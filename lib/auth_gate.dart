import 'dart:async';
import 'package:flutter/material.dart';
import 'package:runrank/auth/login_screen.dart';
import 'package:runrank/root_navigation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _userIsLoggedIn = false;

  @override
  void initState() {
    super.initState();

    // Check initial session synchronously
    final initialSession = Supabase.instance.client.auth.currentSession;
    setState(() {
      _userIsLoggedIn = initialSession != null;
    });

    // Listen to subsequent auth state changes
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (mounted) {
        setState(() {
          _userIsLoggedIn = session != null;
        });
      }

      // Log the event for debugging
      debugPrint('AuthGate: Auth event - $event');
      if (event == AuthChangeEvent.signedOut) {
        debugPrint('AuthGate: User signed out, navigating to LoginScreen.');
      } else if (event == AuthChangeEvent.signedIn) {
        debugPrint('AuthGate: User signed in, navigating to RootNavigation.');
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        debugPrint('AuthGate: Auth token was refreshed.');
      } else if (event == AuthChangeEvent.userDeleted) {
        debugPrint('AuthGate: User deleted, navigating to LoginScreen.');
      }
    }, onError: (error) {
      debugPrint('AuthGate: Auth stream error: $error');
      if (mounted) {
        setState(() {
          _userIsLoggedIn = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _userIsLoggedIn ? const RootNavigation() : const LoginScreen();
  }
}
