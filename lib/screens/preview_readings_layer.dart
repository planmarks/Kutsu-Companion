import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A mid-zoom reading preview: a small multi-line card (selected metrics) tied to
/// a cluster centre, coloured by severity.
class PreviewReading {
  final LatLng pos;
  final Color color;
  final List<String> lines; // e.g. ["CO₂: 1200", "VOC: 300", "NOx: 5"]
  PreviewReading(this.pos, this.color, this.lines);
}

/// Draws preview cards for mid-zoom clusters. Cards are placed greedily in the
/// order given (most important first): each card tries a set of positions around
/// its point and takes the first that is on-screen and does not overlap a card
/// already placed; if none is free it is hidden. This keeps nearby previews from
/// overlapping — they move apart or drop out dynamically as the map pans/zooms.
class PreviewReadingsLayer extends StatelessWidget {
  final List<PreviewReading> items;
  const PreviewReadingsLayer({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final bounds = camera.visibleBounds;
    final projected = <_PC>[];
    for (final it in items) {
      if (!bounds.contains(it.pos)) continue;
      final p = camera.latLngToScreenPoint(it.pos);
      projected.add(_PC(Offset(p.x.toDouble(), p.y.toDouble()), it.color, it.lines));
    }
    return IgnorePointer(child: CustomPaint(size: Size.infinite, painter: _PreviewPainter(projected)));
  }
}

class _PC {
  final Offset o;
  final Color c;
  final List<String> lines;
  _PC(this.o, this.c, this.lines);
}

class _PreviewPainter extends CustomPainter {
  final List<_PC> cards;
  _PreviewPainter(this.cards);

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    final placed = <Rect>[];

    for (final card in cards) {
      final tp = TextPainter(
        text: TextSpan(
          text: card.lines.join('\n'),
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, height: 1.35),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      const accent = 3.0, padL = 9.0, padR = 9.0, padV = 6.0;
      final w = tp.width + accent + padL + padR;
      final h = tp.height + padV * 2;
      final o = card.o;

      // Candidate top-left positions: centred on the point first (sits on the
      // cluster circle, like the reference), then nudged out to the sides.
      final cands = <Offset>[
        Offset(o.dx - w / 2, o.dy - h / 2),
        Offset(o.dx + 12, o.dy - h / 2),
        Offset(o.dx - w - 12, o.dy - h / 2),
        Offset(o.dx - w / 2, o.dy - h - 12),
        Offset(o.dx - w / 2, o.dy + 12),
        Offset(o.dx + 12, o.dy + 12),
        Offset(o.dx - w - 12, o.dy - h - 12),
        Offset(o.dx + 12, o.dy - h - 12),
        Offset(o.dx - w - 12, o.dy + 12),
      ];

      Rect? chosen;
      for (final tl in cands) {
        final rect = Rect.fromLTWH(tl.dx, tl.dy, w, h);
        if (!screen.overlaps(rect.deflate(-2))) continue;            // keep it on-screen
        var clash = false;
        for (final pr in placed) {
          if (pr.inflate(4).overlaps(rect)) { clash = true; break; }
        }
        if (!clash) { chosen = rect; break; }
      }
      if (chosen == null) continue; // hidden this frame to avoid overlap

      placed.add(chosen);
      final rr = RRect.fromRectAndRadius(chosen, const Radius.circular(8));
      canvas.drawRRect(rr, Paint()..color = const Color(0xD9171B19)); // dark, readable over map or circle
      // left severity accent bar
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(chosen.left, chosen.top, accent + 2, chosen.height),
          topLeft: const Radius.circular(8), bottomLeft: const Radius.circular(8)),
        Paint()..color = card.c,
      );
      tp.paint(canvas, Offset(chosen.left + accent + padL, chosen.top + padV));
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => true;
}
