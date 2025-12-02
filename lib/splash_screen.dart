import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextPage;

  const SplashScreen({super.key, required this.nextPage});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  double _logoOpacity = 0.0;
  String _displayedText = "";
  bool _fadeOut = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const String slogan = "…where race timing matters";
  String _version = "";

  @override
  void initState() {
    super.initState();

    _loadVersion();
    _startAnimations();
    _scheduleNavigation();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _version = "v${info.version}");
  }

  void _startAnimations() {
    // Pulse effect
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0, end: 18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Fade logo in
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _logoOpacity = 1.0);
    });

    // Typewriter text
    Future.delayed(const Duration(milliseconds: 1400), () {
      _startTypewriter();
    });
  }

  void _startTypewriter() {
    int i = 0;
    Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (i < slogan.length) {
        setState(() => _displayedText += slogan[i]);
        i++;
      } else {
        timer.cancel();
      }
    });
  }

  void _scheduleNavigation() {
    // Start fade out
    Future.delayed(const Duration(milliseconds: 5200), () {
      if (mounted) setState(() => _fadeOut = true);
    });

    // Navigate after fade out
    Future.delayed(const Duration(milliseconds: 5800), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => widget.nextPage),
      );
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedOpacity(
        opacity: _fadeOut ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 600),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🌟 Pulsing glow circle + logo
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, child) {
                  return Container(
                    width: 200 + _pulseAnimation.value,
                    height: 200 + _pulseAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.yellowAccent.withOpacity(0.12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.yellowAccent.withOpacity(0.45),
                          blurRadius: 32 + _pulseAnimation.value,
                          spreadRadius: 8 + (_pulseAnimation.value / 2),
                        ),
                      ],
                    ),
                    child: Center(child: child),
                  );
                },
                child: AnimatedOpacity(
                  opacity: _logoOpacity,
                  duration: const Duration(milliseconds: 1200),
                  child: Image.asset(
                    'assets/images/rank_logo.png',
                    height: 140,
                    width: 140,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // Typewriter slogan
              Text(
                _displayedText,
                style: const TextStyle(
                  fontSize: 19,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // App version
              AnimatedOpacity(
                opacity: _logoOpacity,
                duration: const Duration(milliseconds: 800),
                child: Text(
                  _version,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
