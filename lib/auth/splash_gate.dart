import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/onboarding_page.dart';
import '../auth/login_page.dart';
import '../pages/home_page.dart';
import '../services/auth_service.dart';
import '../core/notifier.dart';

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  static const Duration _minSplash = Duration(milliseconds: 1500);
  bool _fadeOut = false;

  static const _primary = Color(0xFF4196E3); // Gradient Start Color
  static const _secondary = Color(0xFF6346E3); // Gradient End Color

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _boot();
    });
  }

  Future<void> _boot() async {
    final startedAt = DateTime.now();
    Widget target = const LoginPage();

    try {
      final prefs = await SharedPreferences.getInstance();
      final seenOnboard = prefs.getBool('seen_onboarding') ?? false;
      final user = Supabase.instance.client.auth.currentUser;

      if (!seenOnboard) {
        target = const OnboardingPage();
      } else {
        if (user != null) {
          try {
            await AuthService.loadProfile().timeout(const Duration(seconds: 3));
            target = const HomePage();
          } catch (_) {
            if (mounted)
              notify(
                context,
                'Failed to load profile, try logging in again.',
                error: true,
              );
            target = const LoginPage();
          }
        } else {
          target = const LoginPage();
        }
      }
    } catch (_) {
      target = const LoginPage();
    }

    final elapsed = DateTime.now().difference(startedAt);
    final remaining = _minSplash - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;
    setState(() => _fadeOut = true);
    await Future.delayed(const Duration(milliseconds: 220));

    if (!mounted) return;
    _go(target);
  }

  void _go(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (_, animation, __, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.of(context).size.shortestSide;
    final isTablet = shortest >= 600;
    final logoSize = isTablet ? 200.0 : 160.0;  // Increased logo size

    return Scaffold(
      body: SafeArea(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          opacity: _fadeOut ? 0 : 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primary, _secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Glow blob background (soft animation)
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: logoSize + 50,
                          width: logoSize + 50,
                          padding: const EdgeInsets.all(14),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset(
                              'assets/logo/mager_logo_load.png', // Adjust the logo asset
                              fit: BoxFit.contain,
                            ),
                          ),
                        ).animate()
                          .fadeIn(duration: 450.ms, curve: Curves.easeOut)
                          .scaleXY(begin: 0.92, end: 1.0, duration: 520.ms, curve: Curves.easeOutBack)
                      ],
                    ),

                    const SizedBox(height: 26),

                    // Thicker loading indicator
                    const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,  // Thicker spinner
                        color: Color.fromARGB(255, 255, 255, 255),
                      ),
                    ).animate(onPlay: (c) => c.repeat())
                      .rotate(begin: -0.02, end: 0.02, duration: 850.ms, curve: Curves.easeInOut)
                      .then()
                      .rotate(begin: 0.02, end: -0.02, duration: 850.ms, curve: Curves.easeInOut),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
