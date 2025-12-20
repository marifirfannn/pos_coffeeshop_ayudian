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
  // ✅ minimal tampil biar animasi kebaca & gak “kedip”
  static const Duration _minSplash = Duration(milliseconds: 1000);

  // ✅ buat fade-out sebelum pindah page (biar smooth)
  bool _fadeOut = false;

  static const _primary = Color(0xFF2F6BFF);
  static const _bg = Color(0xFFF6FAFF);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    // ✅ pastikan UI keburu ke-render dulu 1 frame (anti kedip)
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

      // 1) belum onboarding
      if (!seenOnboard) {
        target = const OnboardingPage();
      } else {
        // 2) sudah login -> load profile -> home
        if (user != null) {
          try {
            // ✅ biar gak nyangkut lama kalau network aneh
            await AuthService.loadProfile().timeout(const Duration(seconds: 3));
            target = const HomePage();
          } catch (_) {
            if (mounted)
              notify(
                context,
                'Gagal load profile, coba login ulang',
                error: true,
              );
            target = const LoginPage();
          }
        } else {
          // 3) default login
          target = const LoginPage();
        }
      }
    } catch (_) {
      target = const LoginPage();
    }

    // ✅ tahan minimal durasi splash supaya animasi keliatan
    final elapsed = DateTime.now().difference(startedAt);
    final remaining = _minSplash - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;

    // ✅ fade out dulu biar transisi smooth
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

    final logoSize = isTablet ? 160.0 : 130.0;
    final cardW = isTablet ? 560.0 : 520.0;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          opacity: _fadeOut ? 0 : 1,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: cardW),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Glow blob background (halus)
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Animated glow circle
                        Container(
                              height: logoSize + 90,
                              width: logoSize + 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    _primary.withOpacity(0.22),
                                    _primary.withOpacity(0.02),
                                  ],
                                ),
                              ),
                            )
                            .animate(onPlay: (c) => c.repeat())
                            .scaleXY(
                              begin: 0.92,
                              end: 1.06,
                              duration: 1400.ms,
                              curve: Curves.easeInOut,
                            )
                            .then()
                            .scaleXY(
                              begin: 1.06,
                              end: 0.92,
                              duration: 1400.ms,
                              curve: Curves.easeInOut,
                            ),

                        // Logo card
                        Container(
                              height: logoSize,
                              width: logoSize,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: const Color(0xFFE8EEF7),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    blurRadius: 28,
                                    offset: Offset(0, 14),
                                    color: Color(0x22000000),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.asset(
                                  'assets/logo/mager_logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 450.ms, curve: Curves.easeOut)
                            .scaleXY(
                              begin: 0.92,
                              end: 1.0,
                              duration: 520.ms,
                              curve: Curves.easeOutBack,
                            ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Text(
                          'Mager Coffee Lab',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isTablet ? 24 : 22,
                            fontWeight: FontWeight.w900,
                            color: _text,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 120.ms, duration: 420.ms)
                        .slideY(begin: 0.18, end: 0, curve: Curves.easeOut),

                    const SizedBox(height: 6),

                    Text(
                          'POS • Fast checkout • Stable UI',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isTablet ? 13.5 : 13,
                            fontWeight: FontWeight.w700,
                            color: _muted,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 420.ms)
                        .slideY(begin: 0.18, end: 0, curve: Curves.easeOut),

                    const SizedBox(height: 26),

                    // progress (✅ gak pake _ready yang ga kepake)
                    const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: _primary,
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat())
                        .rotate(
                          begin: -0.02,
                          end: 0.02,
                          duration: 850.ms,
                          curve: Curves.easeInOut,
                        )
                        .then()
                        .rotate(
                          begin: 0.02,
                          end: -0.02,
                          duration: 850.ms,
                          curve: Curves.easeInOut,
                        ),
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
