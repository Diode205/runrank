import 'package:flutter/material.dart';
import 'package:runrank/auth/login_screen.dart';
import 'package:runrank/services/auth_service.dart';
import 'package:runrank/root_navigation.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final userIsLoggedIn = AuthService.userIsLoggedIn();

    return userIsLoggedIn ? const RootNavigation() : const LoginScreen();
  }
}
