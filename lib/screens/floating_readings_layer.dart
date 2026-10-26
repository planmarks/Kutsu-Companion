import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class FloatReading {
  final LatLng pos;
  final Color color;
  final String label; // short value shown floating by the dot
  FloatReading(this.pos, this.color, this.label);
}

/// When zoomed in, draws each reading as a floating dot + its value label,
/// culled to the visible viewport so it stays fast. Rebuilds with the camera.
class FloatingReadingsLayer extends StatelessWidget {
  final List<FloatReading> items;
  final int cap;
  const FloatingReadingsLayer({super.key, required this.items, this.cap = 160});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final bounds = camera.visibleBounds;
    final drawn = <_FP>[];
    for (final it in items) {
      if (!bounds.contains(it.pos)) continue;
      final p = camera.latLngToScreenPoint(it.pos);
      drawn.add(_FP(Offset(p.x.toDouble(), p.y.toDouble()), it.color, it.label));
      if (drawn.length >= cap) break;
    }
    return IgnorePointer(child: CustomPaint(size: Size.infinite, painter: _FloatPainter(drawn)));
  }
}

class _FP {
  final Offset o;
  final Color c;
  final String label;
  _FP(this.o, this.c, this.label);
}

class _FloatPainter extends CustomPainter {
  final List<_FP> pts;
  _FloatPainter(this.pts);

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()..color = Colors.white;
    for (final p in pts) {
      // dot
      canvas.drawCircle(p.o, 6, white);
      canvas.drawCircle(p.o, 5, Paint()..color = p.c);
      // floating label chip above the dot
      if (p.label.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(text: p.label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      final chipW = tp.width + 10, chipH = tp.height + 4;
      final chipRect = Rect.fromCenter(center: Offset(p.o.dx, p.o.dy - 16), width: chipW, height: chipH);
      final rrect = RRect.fromRectAndRadius(chipRect, const Radius.circular(6));
      canvas.drawRRect(rrect, Paint()..color = p.c.withOpacity(0.92));
      tp.paint(canvas, Offset(chipRect.left + 5, chipRect.top + 2));
    }
  }

  @override
  bool shouldRepaint(_FloatPainter old) => true;
}
