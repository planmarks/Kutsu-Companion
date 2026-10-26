import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../state/kutsu_state.dart';
import '../state/trends.dart';
import '../store/db.dart';
import '../services/community_service.dart';
import '../theme.dart';
import '../ui/widgets.dart';
import 'settings_widgets.dart';
import 'map_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<Map<String, dynamic>> _rows = [];
  String _metric = 'co2';
  static const _metrics = [['co2', 'CO₂'], ['voc', 'VOC'], ['nox', 'NOx'], ['temp', 'Temp'], ['hum', 'Humidity']];

  // Visible window over the x-index range (scroll/zoom, #5.1).
  double _minX = 0, _maxX = 0;
  bool _userAdjusted = false;   // false → auto-follow the full/newest range
  double _plotW = 300;          // plot width in px (for px→x-unit mapping)
  double _lastScale = 1.0;

  // Auto-refresh triggers (#5.2 / #5.3) + trends-config change (#7).
  int _seenRev = -1;
  String? _seenDevice;
  String _trendSig = '';

  @override
  void initState() { super.initState(); _load(); }

  // Load the chart data according to the Trends mode (#7): one session, or an
  // area around a chosen location over a period/source.
  Future<void> _load() async {
    final t = context.read<KutsuState>().trends;
    List<Map<String, dynamic>> rows;
    if (t.mode == 'location') {
      rows = await _loadLocation(t);
    } else {
      final boot = t.boot ?? await KutsuDb.instance.latestBoot();
      rows = boot == null ? <Map<String, dynamic>>[] : await KutsuDb.instance.rowsForBoot(boot);
    }
    if (!mounted) return;
    setState(() {
      _rows = rows; // already oldest → newest
      if (!_userAdjusted) { _minX = 0; _maxX = (_rows.length - 1).clamp(0, 1 << 30).toDouble(); }
    });
  }

  Future<List<Map<String, dynamic>>> _loadLocation(TrendsConfig t) async {
    if (!t.hasLocation) return <Map<String, dynamic>>[];
    List<Map<String, dynamic>> candidates;
    if (t.source == 'global') {
      candidates = await CommunityService.fetchGlobal(limit: 5000);
    } else if (t.source == 'run') {
      candidates = await KutsuDb.instance.runRows();
    } else {
      candidates = await KutsuDb.instance.geoRows(5000);
    }
    const dist = Distance();
    final center = LatLng(t.locLat!, t.locLon!);
    final out = <Map<String, dynamic>>[];
    for (final r in candidates) {
      if (r['lat'] is! num || r['lon'] is! num) continue;
      final d = dist(center, LatLng((r['lat'] as num).toDouble(), (r['lon'] as num).toDouble()));
      if (d > t.radiusM) continue;
      if (!t.inPeriod(r['ts'] as int?, (r['recv'] as num?)?.toInt() ?? 0)) continue;
      out.add(r);
    }
    out.sort((a, b) => ((a['recv'] ?? 0) as num).compareTo((b['recv'] ?? 0) as num));
    return out;
  }

  String _timeOf(BuildContext context, Map<String, dynamic> r) {
    final ts = r['ts'] as int?;
    final dt = ts != null ? DateTime.fromMillisecondsSinceEpoch(ts * 1000) : DateTime.fromMillisecondsSinceEpoch(r['recv'] as int);
    return TimeOfDay.fromDateTime(dt).format(context);
  }

  void _resetZoom(int n) => setState(() {
    _userAdjusted = false; _lastScale = 1.0;
    _minX = 0; _maxX = (n - 1).clamp(0, 1 << 30).toDouble();
  });

  void _onScaleUpdate(ScaleUpdateDetails d, int n) {
    if (n < 3) return;
    final fullMax = (n - 1).toDouble();
    const minRange = 2.0;
    var range = (_maxX - _minX).clamp(minRange, fullMax);
    // Pan (per-frame horizontal drag → shift the window).
    var newMin = _minX - d.focalPointDelta.dx / _plotW * range;
    // Zoom (pinch → shrink/grow the window around its centre).
    final deltaScale = d.scale / _lastScale;
    _lastScale = d.scale;
    if ((deltaScale - 1).abs() > 0.001) {
      final center = newMin + range / 2;
      final newRange = (range / deltaScale).clamp(minRange, fullMax);
      newMin = center - newRange / 2;
      range = newRange;
    }
    var newMax = newMin + range;
    if (newMin < 0) { newMax -= newMin; newMin = 0; }
    if (newMax > fullMax) { newMin -= newMax - fullMax; newMax = fullMax; }
    newMin = newMin.clamp(0, fullMax);
    setState(() { _userAdjusted = true; _minX = newMin; _maxX = newMax; });
  }

  // ---- Trends controls (#7) -------------------------------------------------
  static const _sourceLabels = ['All time', 'This run', 'Global'];
  static const _sourceKeys = ['all', 'run', 'global'];

  String _sessionLabel(TrendsConfig t) {
    if (t.boot == null) return 'Most recent session';
    if (_rows.isEmpty) return 'Selected session';
    final r = _rows.first;
    final ts = r['ts'] as int?;
    final dt = ts != null ? DateTime.fromMillisecondsSinceEpoch(ts * 1000) : DateTime.fromMillisecondsSinceEpoch(r['recv'] as int);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${TimeOfDay.fromDateTime(dt).format(context)}';
  }

  String _periodLabel(TrendsConfig t) {
    String d(DateTime x) => '${x.month}/${x.day}';
    final parts = <String>[];
    if (t.dateFrom != null || t.dateTo != null) {
      parts.add('${t.dateFrom != null ? d(t.dateFrom!) : '…'}–${t.dateTo != null ? d(t.dateTo!) : '…'}');
    }
    if (t.timeStartMin != null && t.timeEndMin != null) {
      String hm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
      parts.add('${hm(t.timeStartMin!)}–${hm(t.timeEndMin!)}');
    }
    return parts.isEmpty ? 'Any time' : parts.join(' · ');
  }

  Future<void> _pickSession() async {
    final st = context.read<KutsuState>();
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: now, firstDate: DateTime(2024), lastDate: now);
    if (d == null || !mounted) return;
    final runs = await KutsuDb.instance.runsOnDate(d);
    if (!mounted) return;
    showModalBottomSheet(context: context, builder: (_) {
      final k = ktOf(context);
      return Container(color: k.panel, child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 8), children: [
        ListTile(
          leading: Icon(Icons.history, color: k.brand),
          title: Text('Most recent session', style: TextStyle(color: k.ink)),
          onTap: () { st.trends.boot = null; st.saveTrends(); Navigator.pop(context); }),
        if (runs.isEmpty)
          ListTile(title: Text('No sessions recorded on this day', style: TextStyle(color: k.muted))),
        for (final r in runs)
          ListTile(
            leading: Icon(Icons.timeline, color: k.muted),
            title: Text('Run ${TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(r['start'] as int)).format(context)}',
                style: TextStyle(color: k.ink)),
            subtitle: Text('${r['n']} readings', style: TextStyle(color: k.muted)),
            onTap: () { st.trends.boot = r['boot'] as int; st.saveTrends(); Navigator.pop(context); }),
      ]));
    });
  }

  void _pickRadius(TrendsConfig t, KutsuState st) {
    const opts = [50, 100, 150, 300, 500, 1000];
    showDialog(context: context, builder: (_) {
      final k = ktOf(context);
      return AlertDialog(
        backgroundColor: k.panel,
        title: Text('Radius', style: TextStyle(color: k.ink)),
        content: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in opts)
            GestureDetector(
              onTap: () { t.radiusM = m.toDouble(); st.saveTrends(); Navigator.pop(context); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: t.radiusM == m ? k.brand : k.chip, borderRadius: BorderRadius.circular(999)),
                child: Text('$m m', style: TextStyle(color: t.radiusM == m ? Colors.white : k.muted, fontWeight: FontWeight.w600)),
              )),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      );
    });
  }

  Future<void> _pickPeriod(TrendsConfig t, KutsuState st) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context, firstDate: DateTime(2024), lastDate: now,
      initialDateRange: (t.dateFrom != null && t.dateTo != null) ? DateTimeRange(start: t.dateFrom!, end: t.dateTo!) : null);
    if (!mounted) return;
    if (range != null) { t.dateFrom = range.start; t.dateTo = range.end; }
    final start = await showTimePicker(context: context,
      initialTime: t.timeStartMin != null ? TimeOfDay(hour: t.timeStartMin! ~/ 60, minute: t.timeStartMin! % 60) : const TimeOfDay(hour: 0, minute: 0),
      helpText: 'Start of time window (cancel to skip)');
    if (!mounted) return;
    if (start != null) {
      final end = await showTimePicker(context: context,
        initialTime: t.timeEndMin != null ? TimeOfDay(hour: t.timeEndMin! ~/ 60, minute: t.timeEndMin! % 60) : const TimeOfDay(hour: 23, minute: 59),
        helpText: 'End of time window');
      if (!mounted) return;
      if (end != null) { t.timeStartMin = start.hour * 60 + start.minute; t.timeEndMin = end.hour * 60 + end.minute; }
    }
    st.saveTrends();
  }

  void _clearPeriod(TrendsConfig t, KutsuState st) {
    t.dateFrom = null; t.dateTo = null; t.timeStartMin = null; t.timeEndMin = null;
    st.saveTrends();
  }

  Future<void> _pickLocation() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(appBar: AppBar(title: const Text('Pick trend location')), body: const MapScreen(pickTrend: true))));
    if (mounted) { _userAdjusted = false; _load(); }
  }

  Widget _trendControls(KT k, KutsuState st) {
    final t = st.trends;
    Widget pill(IconData ic, String label, VoidCallback onTap) => OutlinedButton.icon(
      onPressed: onTap, icon: Icon(ic, size: 16), label: Text(label),
      style: OutlinedButton.styleFrom(foregroundColor: k.ink, side: BorderSide(color: k.line), visualDensity: VisualDensity.compact));

    if (t.mode == 'session') {
      return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
        Expanded(child: Text(_sessionLabel(t), style: TextStyle(color: k.muted, fontSize: 12.5))),
        pill(Icons.calendar_today, 'Session', _pickSession),
      ]));
    }
    // location
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        pill(Icons.adjust, 'Radius: ${t.radiusM.round()} m', () => _pickRadius(t, st)),
        pill(Icons.date_range, _periodLabel(t), () => _pickPeriod(t, st)),
        if (t.dateFrom != null || t.timeStartMin != null)
          pill(Icons.clear, 'Clear period', () => _clearPeriod(t, st)),
      ]),
      const SizedBox(height: 8),
      SettingOptions(label: 'Source', value: _sourceKeys.indexOf(t.source).clamp(0, 2), options: _sourceLabels,
        onChanged: (i) { t.source = _sourceKeys[i]; st.saveTrends(); }),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: Text(t.hasLocation ? 'Centre: ${t.locLat!.toStringAsFixed(4)}, ${t.locLon!.toStringAsFixed(4)}' : 'No location set',
            style: TextStyle(color: k.muted, fontSize: 12.5))),
        pill(Icons.place, t.hasLocation ? 'Change' : 'Pick on map', _pickLocation),
      ]),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final k = ktOf(context);
    // Auto-refresh on new samples (#5.3), on device change (#5.2), and on trends
    // config change (#7).
    final st = context.watch<KutsuState>();
    final sig = st.trends.encode();
    if (st.dataVersion != _seenRev || st.connectedId != _seenDevice || sig != _trendSig) {
      final deviceChanged = st.connectedId != _seenDevice;
      final trendChanged = sig != _trendSig;
      _seenRev = st.dataVersion; _seenDevice = st.connectedId; _trendSig = sig;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (deviceChanged || trendChanged) _userAdjusted = false;
        _load();
      });
    }
    final t = st.trends;
    final needsLocation = t.mode == 'location' && !t.hasLocation;

    final spots = <FlSpot>[];
    for (var i = 0; i < _rows.length; i++) {
      final v = _rows[i][_metric];
      if (v is num) spots.add(FlSpot(i.toDouble(), v.toDouble()));
    }
    final n = _rows.length;
    final minX = _minX, maxX = _maxX > _minX ? _maxX : (n - 1).clamp(0, 1 << 30).toDouble();
    final visRange = (maxX - minX).clamp(1.0, 1 << 30);
    final labelEvery = (visRange / 5).ceilToDouble().clamp(1, 1 << 30);

    return RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
      KCard(title: 'Environment trend', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _trendControls(k, st),
        Row(children: [
          Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final m in _metrics)
              GestureDetector(onTap: () => setState(() => _metric = m[0]), child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _metric == m[0] ? k.brand : k.chip, borderRadius: BorderRadius.circular(999)),
                child: Text(m[1], style: TextStyle(color: _metric == m[0] ? Colors.white : k.muted, fontSize: 12, fontWeight: FontWeight.w600)),
              )),
          ])),
          if (_userAdjusted)
            IconButton(tooltip: 'Reset zoom', visualDensity: VisualDensity.compact,
              onPressed: () => _resetZoom(n), icon: Icon(Icons.zoom_out_map, color: k.muted, size: 20)),
        ]),
        const SizedBox(height: 14),
        SizedBox(height: 220, child: needsLocation
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.place_outlined, color: k.muted, size: 32),
                const SizedBox(height: 8),
                Text('Pick a location on the map to see area trends.',
                    textAlign: TextAlign.center, style: TextStyle(color: k.muted)),
                const SizedBox(height: 10),
                KBtn('Pick on map', _pickLocation, kind: 'ghost'),
              ]))
            : spots.length < 2
            ? Center(child: Text(t.mode == 'location'
                ? 'No readings in this area/period yet.'
                : 'Collect some data to see charts.', style: TextStyle(color: k.muted)))
            : LayoutBuilder(builder: (ctx, cons) {
                _plotW = (cons.maxWidth - 40).clamp(1, 1 << 30).toDouble(); // minus left axis reserve
                return GestureDetector(
                  onScaleStart: (_) => _lastScale = 1.0,
                  onScaleUpdate: (d) => _onScaleUpdate(d, n),
                  child: LineChart(LineChartData(
                      minX: minX, maxX: maxX,
                      clipData: const FlClipData.all(),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        getTouchedSpotIndicator: (bar, indexes) => indexes.map((i) => TouchedSpotIndicatorData(
                          FlLine(color: k.brand, strokeWidth: 1),
                          FlDotData(getDotPainter: (s, p, b, idx) => FlDotCirclePainter(radius: 4, color: k.brand, strokeWidth: 0)),
                        )).toList(),
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => k.ink.withOpacity(0.92),
                          getTooltipItems: (spots) => spots.map((sp) {
                            final i = sp.x.toInt();
                            final when = (i >= 0 && i < _rows.length) ? _timeOf(context, _rows[i]) : '';
                            final val = (_metric == 'temp' || _metric == 'hum') ? sp.y.toStringAsFixed(1) : sp.y.round().toString();
                            return LineTooltipItem('$val\n$when', TextStyle(color: k.bg, fontWeight: FontWeight.w700, fontSize: 12));
                          }).toList(),
                        ),
                      ),
                      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: k.line, strokeWidth: 0.5)),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(
                          showTitles: true, reservedSize: 26, interval: labelEvery.toDouble(),
                          getTitlesWidget: (v, meta) {
                            final i = v.round();
                            if (i < 0 || i >= _rows.length) return const SizedBox.shrink();
                            return SideTitleWidget(axisSide: meta.axisSide, space: 6,
                              child: Text(_timeOf(context, _rows[i]), style: TextStyle(color: k.muted, fontSize: 9)));
                          },
                        )),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40,
                            getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: TextStyle(color: k.muted, fontSize: 10)))),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: k.brand, barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: true, color: k.brand.withOpacity(0.12)))],
                    )),
                );
              })),
        const SizedBox(height: 6),
        Text(_userAdjusted
            ? 'Drag to scroll · pinch to zoom · tap a point for its value'
            : 'Drag to scroll · pinch to zoom · auto-updating',
            style: TextStyle(color: k.muted, fontSize: 11)),
      ])),

      KCard(title: 'Export', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KBtn('Export as .csv', _exportCsv),
        const SizedBox(height: 8),
        Text('Exports all stored readings (time, location, metrics) as a CSV file to share.',
            style: TextStyle(color: k.muted, fontSize: 12)),
      ])),

      KCard(title: 'Debug', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Device internal log (latest records)', style: TextStyle(color: k.muted, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          height: 200, padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF0D120F), borderRadius: BorderRadius.circular(10)),
          child: ListView(reverse: true, children: [
            for (final r in _rows.reversed.take(60))
              Text('${r['json'] ?? ''}', style: const TextStyle(color: Color(0xFFB7D6BF), fontFamily: 'monospace', fontSize: 10)),
          ]),
        ),
      ])),
    ]));
  }

  Future<void> _exportCsv() async {
    try {
      final csv = await KutsuDb.instance.exportCsv();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/kutsu_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], subject: 'Kutsu data export');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}
