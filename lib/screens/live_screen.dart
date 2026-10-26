import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/kutsu_state.dart';
import '../theme.dart';
import '../ui/widgets.dart';

class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final k = ktOf(context);
    final s = context.watch<KutsuState>();
    final r = s.record;

    if (!s.connected || r == null) {
      return KCenter(s.connected ? 'Waiting for the first reading…' : 'Connect a device on the Device tab.');
    }

    final name = (r['id'] ?? 'Kutsu').toString();
    final room = (r['room'] ?? '').toString();
    final coords = r['lat'] is num && r['lon'] is num
        ? '${(r['lat'] as num).toStringAsFixed(4)}, ${(r['lon'] as num).toStringAsFixed(4)}'
        : '';
    final place = s.placeLabel ?? '';
    final sub = [if (room.isNotEmpty) room, if (place.isNotEmpty) place, if (coords.isNotEmpty) coords].join('  ·  ');

    final ts = r['ts'] as int?;
    final time = ts != null
        ? TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(ts * 1000)).format(context)
        : TimeOfDay.now().format(context);

    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: k.panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: k.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(color: k.ink, fontSize: 22, fontWeight: FontWeight.w800)),
          if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2),
            child: Text(sub, style: TextStyle(color: k.muted, fontSize: 14))),
          const SizedBox(height: 16),
          Row(children: [
            _miniTile(k, 'Time', '', time, 0),
            const SizedBox(width: 10),
            _miniTile(k, 'Temp', '°C', _fmt(r['temp'], 1), (r['s_temp'] as num?)?.toInt() ?? 0),
            const SizedBox(width: 10),
            _miniTile(k, 'Humidity', '%', _fmt(r['hum'], 0), (r['s_hum'] as num?)?.toInt() ?? 0),
          ]),
          const SizedBox(height: 14),
          _graphCard(k, s, 'co2', 'CO2', 'ppm', (r['s_co2'] as num?)?.toInt() ?? 0, _fmt(r['co2'], 0)),
          const SizedBox(height: 10),
          _graphCard(k, s, 'voc', 'VOC', 'idx', (r['s_voc'] as num?)?.toInt() ?? 0, _fmt(r['voc'], 0)),
          const SizedBox(height: 10),
          _graphCard(k, s, 'nox', 'NOx', 'idx', (r['s_nox'] as num?)?.toInt() ?? 0, _fmt(r['nox'], 0)),
          // Any other sensor found at boot (DIY CCS811 / MQ-2) gets its own graph.
          for (final e in const [['eco2', 'eCO₂', 'ppm'], ['tvoc', 'TVOC', 'ppb'], ['gas', 'Gas', 'adc']])
            if (r.containsKey(e[0])) ...[
              const SizedBox(height: 10),
              _graphCard(k, s, e[0], e[1], e[2], (r['s_${e[0]}'] as num?)?.toInt() ?? 0, _fmt(r[e[0]], 0)),
            ],
          const SizedBox(height: 16),
          Text('Device Runtime:  ${_runtime(r['up'])}', style: TextStyle(color: k.muted, fontSize: 14)),
        ]),
      ),
    ]);
  }

  Widget _miniTile(KT k, String label, String unit, String value, int sev) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(color: k.chip, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic, children: [
              Text(label, style: TextStyle(color: k.muted, fontSize: 13)),
              if (unit.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 3),
                child: Text(unit, style: TextStyle(color: k.muted, fontSize: 10))),
            ]),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: sev > 0 ? k.sev(sev) : k.ink, fontSize: 24, fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  Widget _graphCard(KT k, KutsuState s, String key, String label, String unit, int sev, String value) {
    final series = s.history.map((h) => (h[key] as num?)?.toDouble()).whereType<double>().toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: k.chip, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        SizedBox(width: 92, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(label, style: TextStyle(color: k.ink, fontSize: 14, fontWeight: FontWeight.w700)),
            Padding(padding: const EdgeInsets.only(left: 4), child: Text(unit, style: TextStyle(color: k.muted, fontSize: 11))),
          ]),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: k.sev(sev), fontSize: 26, fontWeight: FontWeight.w800)),
        ])),
        const SizedBox(width: 10),
        Expanded(child: SizedBox(height: 58, child: CustomPaint(painter: _Spark(series, k.sev(sev), k.line)))),
      ]),
    );
  }

  String _fmt(dynamic v, int d) => v is num ? v.toStringAsFixed(d) : '—';

  String _runtime(dynamic up) {
    final s = (up is num ? up.toInt() : 0);
    if (s >= 86400) {
      final d = s ~/ 86400, h = (s % 86400) ~/ 3600, m = (s % 3600) ~/ 60;
      return '${d}d ${h}h ${m}m';
    }
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    return '${h}h ${m}m ${sec}s';
  }
}

// Sparkline: faint horizontal gridlines + an auto-scaled line of the recent values.
class _Spark extends CustomPainter {
  final List<double> pts;
  final Color color, grid;
  _Spark(this.pts, this.color, this.grid);

  @override
  void paint(Canvas canvas, Size size) {
    final gp = Paint()..color = grid..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
    }
    if (pts.length < 2) return;
    final mn = pts.reduce(min), mx = pts.reduce(max);
    final range = (mx - mn).abs() < 1e-6 ? 1.0 : (mx - mn);
    final path = Path();
    for (int i = 0; i < pts.length; i++) {
      final x = size.width * i / (pts.length - 1);
      final y = size.height * (1 - (pts[i] - mn) / range);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_Spark old) => true;
}
