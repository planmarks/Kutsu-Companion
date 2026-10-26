import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';

/// Logo + intro screen shown on launch, then → Device screen.
/// Drop a logo at assets/logo.png (declare it in pubspec) to replace the glyph.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1800), () {
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final k = ktOf(context);
    return Scaffold(
      backgroundColor: k.bg,
      body: Center(
        child: FadeTransition(
          opacity: _c,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(color: k.brand, borderRadius: BorderRadius.circular(26)),
              child: const Icon(Icons.eco, color: Colors.white, size: 52), // placeholder for assets/logo.png
            ),
            const SizedBox(height: 20),
            Text('Kutsu Companion', style: TextStyle(color: k.ink, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Environmental awareness', style: TextStyle(color: k.muted, fontSize: 14)),
          ]),
        ),
      ),
    );
  }
}
