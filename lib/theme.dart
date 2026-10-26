import 'package:flutter/material.dart';

// Kutsu brand palette (sage green), mirrors the RN app / Setup app.
class KT {
  final Color bg, panel, ink, muted, line, brand, brandInk, chip, good, warn, bad;
  const KT(this.bg, this.panel, this.ink, this.muted, this.line, this.brand,
      this.brandInk, this.chip, this.good, this.warn, this.bad);

  static const light = KT(
    Color(0xFFF4F6F5), Color(0xFFFFFFFF), Color(0xFF15211C), Color(0xFF5D6B64), Color(0xFFDDE4E0),
    Color(0xFF4A7C59), Color(0xFF2F5B3E), Color(0xFFEEF2F0),
    Color(0xFF2E9E5B), Color(0xFFD7A21A), Color(0xFFD1495B),
  );
  static const dark = KT(
    Color(0xFF10150F), Color(0xFF18211A), Color(0xFFE7EFE9), Color(0xFF9DB0A4), Color(0xFF2A362D),
    Color(0xFF8FB89A), Color(0xFFB7D6BF), Color(0xFF1F2A22),
    Color(0xFF2E9E5B), Color(0xFFD7A21A), Color(0xFFD1495B),
  );

  Color sev(int s) => s >= 2 ? bad : (s == 1 ? warn : good);
}

KT ktOf(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? KT.dark : KT.light;

ThemeData kutsuTheme(Brightness b) {
  final k = b == Brightness.dark ? KT.dark : KT.light;
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: k.bg,
    colorSchemeSeed: k.brand,
    appBarTheme: AppBarTheme(backgroundColor: k.panel, foregroundColor: k.ink, elevation: 0),
  );
}
