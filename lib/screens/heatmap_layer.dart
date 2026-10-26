import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class HeatPoint {
  final LatLng pos;
  final Color color; // severity colour (green/yellow/red)
  HeatPoint(this.pos, this.color);
}

/// A smooth heatmap drawn on top of the map: each reading becomes a soft, blurred
/// radial blob coloured by severity, so overlapping points blend into readable
/// regions when zoomed out (no external plugin). Place inside FlutterMap's children.
class HeatmapLayer extends StatelessWidget {
  final List<HeatPoint> points;
  final double radius;
  const HeatmapLayer({super.key, required this.points, this.radius = 48});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final projected = <_P>[];
    for (final p in points) {
      final pt = camera.latLngToScreenPoint(p.pos);
      projected.add(_P(Offset(pt.x.toDouble(), pt.y.toDouble()), p.color));
    }
    return IgnorePointer(child: CustomPaint(size: Size.infinite, painter: _HeatPainter(projected, radius)));
  }
}

class _P {
  final Offset o;
  final Color c;
  _P(this.o, this.c);
}

class _HeatPainter extends CustomPainter {
  final List<_P> pts;
  final double radius;
  _HeatPainter(this.pts, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    for (final p in pts) {
      if (!bounds.inflate(radius).contains(p.o)) continue; // skip off-screen
      final rect = Rect.fromCircle(center: p.o, radius: radius);
      final paint = Paint()
        ..shader = RadialGradient(colors: [p.c.withOpacity(0.5), p.c.withOpacity(0.0)]).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(p.o, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_HeatPainter old) => true;
}
