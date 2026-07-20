import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main_shell.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.88, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.forward();

    Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainShell(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.25),
            radius: 1.2,
            colors: [Color(0xFF22201A), AppColors.ink],
            stops: [0.0, 0.6],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // "K" logo mark — paper rounded square
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            color: AppColors.paper,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 50,
                                offset: const Offset(0, 24),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'K',
                              style: bricolage(
                                fontSize: 66,
                                fontWeight: FontWeight.w800,
                                color: AppColors.green,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        // Wordmark
                        Text(
                          'Kamaae',
                          style: bricolage(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFFBF9F3),
                            letterSpacing: -0.02 * 40,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dukaan ka hisaab, aasaan.',
                          style: instrument(
                            fontSize: 14,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom: dots + tagline
              Padding(
                padding: const EdgeInsets.only(bottom: 44),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _dot(active: true),
                        const SizedBox(width: 7),
                        _dot(active: false),
                        const SizedBox(width: 7),
                        _dot(active: false),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ALL DATA STORED ON YOUR DEVICE',
                      style: instrument(
                        fontSize: 11,
                        color: const Color(0xFF6E675C),
                        letterSpacing: 0.14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot({required bool active}) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? AppColors.greenFrame
              : Colors.white.withValues(alpha: 0.22),
        ),
      );
}
