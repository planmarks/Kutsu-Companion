import 'package:flutter/material.dart';
import '../theme.dart';

class KCard extends StatelessWidget {
  final String? title;
  final Widget child;
  const KCard({super.key, this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    final k = ktOf(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: k.panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: k.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title != null)
          Padding(padding: const EdgeInsets.only(bottom: 12),
            child: Text(title!.toUpperCase(),
              style: TextStyle(color: k.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1))),
        child,
      ]),
    );
  }
}

class KBtn extends StatelessWidget {
  final String title; final VoidCallback onPressed; final String kind;
  const KBtn(this.title, this.onPressed, {super.key, this.kind = 'primary'});
  @override
  Widget build(BuildContext context) {
    final k = ktOf(context);
    final primary = kind == 'primary';
    final danger = kind == 'danger';
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: primary ? k.brand : Colors.transparent,
        foregroundColor: primary ? Colors.white : (danger ? k.bad : k.ink),
        side: primary ? null : BorderSide(color: k.line),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class KRow extends StatelessWidget {
  final String label; final String value;
  const KRow(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) {
    final k = ktOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: k.line, width: 0.5))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: k.muted)),
        Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(color: k.ink, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class KCenter extends StatelessWidget {
  final String text;
  const KCenter(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final k = ktOf(context);
    return Center(child: Padding(padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: k.muted))));
  }
}

String fmtMetric(dynamic v, String key) {
  if (v is! num) return '—';
  return (key == 'temp' || key == 'hum') ? v.toStringAsFixed(1) : v.round().toString();
}
