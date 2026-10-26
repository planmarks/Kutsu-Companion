import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../state/kutsu_state.dart';
import '../store/db.dart';
import '../theme.dart';
import '../services/community_service.dart';
import 'heatmap_layer.dart';
import 'floating_readings_layer.dart';
import 'preview_readings_layer.dart';
import 'map_styles.dart';

const _heatmapBelowZoom = 15.0;  // below → heatmap
const _floatAboveZoom = 17.0;    // at/above → individual floating readings

class MapScreen extends StatefulWidget {
  /// When true, the map runs as a location picker for Trends (#7.1.2): it shows
  /// only readings inside the Trends period, and tapping a data point selects it
  /// as the trend centre (then pops).
  final bool pickTrend;
  const MapScreen({super.key, this.pickTrend = false});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _Cluster {
  final LatLng center;
  final int count, sev;
  final List<Map<String, dynamic>> rows;
  _Cluster(this.center, this.count, this.sev, this.rows);
}

class _Top {
  final String label;
  final int sev;
  _Top(this.label, this.sev);
}

class _MapScreenState extends State<MapScreen> {
  final _controller = MapController();
  String _view = 'all'; // all | run | global
  List<Map<String, dynamic>> _rows = [];
  double _zoom = 16;
  int _seenRev = -1;            // KutsuState.dataVersion we last reloaded for (#4.3)
  bool _globalLoading = false;

  MapStyle _style = MapStyle.standard;   // base map tiles (#4.1)
  List<Map<String, dynamic>> _markers = []; // user-placed markers (#4.2)
  bool _placing = false;                 // armed to drop a marker on next tap

  // Date / run sorting (All time tab).
  DateTime? _date;        // null = all time
  int? _boot;             // null = all runs on the date; else a specific run
  List<Map<String, dynamic>> _runs = [];

  // Filter = which metrics appear in the tap dialog AND drive the map previews.
  final Set<String> _filter = {'temp', 'hum', 'co2', 'voc', 'nox'};
  static const _metricNames = {'temp': 'Temperature', 'hum': 'Humidity', 'co2': 'CO₂', 'voc': 'VOC', 'nox': 'NOx'};
  // Short labels + a stable display order for on-map previews.
  static const _shortName = {'co2': 'CO₂', 'voc': 'VOC', 'nox': 'NOx', 'temp': 'Temp', 'hum': 'Hum'};
  static const _previewOrder = ['co2', 'voc', 'nox', 'temp', 'hum'];
  // Tie-break priority when picking the single "worst" selected metric.
  static const _sevOrder = ['co2', 'nox', 'voc', 'temp', 'hum'];

  @override
  void initState() {
    super.initState();
    if (widget.pickTrend) {
      final src = context.read<KutsuState>().trends.source;
      _view = (src == 'run' || src == 'global') ? src : 'all';
    }
    _restore(); _loadMarkers(); _load();
  }

  // In pick mode, keep only rows inside the Trends date/time period.
  List<Map<String, dynamic>> _postFilter(List<Map<String, dynamic>> rows) {
    if (!widget.pickTrend) return rows;
    final t = context.read<KutsuState>().trends;
    return rows.where((r) => t.inPeriod(r['ts'] as int?, (r['recv'] as num?)?.toInt() ?? 0)).toList();
  }

  Future<void> _restore() async {
    final s = await KutsuDb.instance.kvGet('map_style');
    if (mounted && s != null) setState(() => _style = mapStyleFromId(s));
  }

  Future<void> _loadMarkers() async {
    final m = await KutsuDb.instance.markers();
    if (mounted) setState(() => _markers = m);
  }

  Future<void> _load() async {
    if (_view == 'global') {
      setState(() => _globalLoading = true);
      try {
        final g = _date == null
            ? await CommunityService.fetchGlobal()
            : await CommunityService.fetchGlobalOnDate(_date!);
        if (mounted) setState(() => _rows = _postFilter(g));
      } catch (e) {
        if (mounted) {
          setState(() => _rows = []);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load community data: ${'$e'.replaceFirst('Exception: ', '')}')));
        }
      } finally {
        if (mounted) setState(() => _globalLoading = false);
      }
      return;
    }
    List<Map<String, dynamic>> raw;
    if (_view == 'run') {
      raw = await KutsuDb.instance.runRows();
    } else if (_date == null) {
      raw = await KutsuDb.instance.geoRows();
    } else if (_boot == null) {
      raw = await KutsuDb.instance.geoRowsOnDate(_date!);
    } else {
      raw = await KutsuDb.instance.geoRowsForBoot(_boot!);
    }
    final rows = <Map<String, dynamic>>[];
    for (final r in raw) {
      final m = Map<String, dynamic>.from(r);
      final j = r['json'];
      if (j is String) {
        try {
          final d = jsonDecode(j);
          if (d is Map) {
            for (final key in ['co2', 'voc', 'nox', 'temp', 'hum', 'eco2', 'tvoc', 'gas']) {
              if (d['s_$key'] is num) m['s_$key'] = (d['s_$key'] as num).toInt();
            }
          }
        } catch (_) {}
      }
      rows.add(m);
    }
    if (mounted) setState(() => _rows = _postFilter(rows));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: _date ?? now, firstDate: DateTime(2024), lastDate: now);
    if (d == null) return;
    // Global tab filters by date only — no run (boot session) picker.
    if (_view == 'global') { setState(() { _date = d; _boot = null; _runs = []; }); _load(); return; }
    final runs = await KutsuDb.instance.runsOnDate(d);
    setState(() { _date = d; _boot = null; _runs = runs; });
    _load();
  }

  void _clearDate() { setState(() { _date = null; _boot = null; _runs = []; }); _load(); }

  // Default alarm thresholds (match firmware config.h). Used to classify severity
  // from raw values for rows that don't carry per-metric s_* (e.g. Global data).
  static const _warn = {'co2': 1000.0, 'voc': 250.0, 'nox': 20.0};
  static const _harm = {'co2': 2000.0, 'voc': 400.0, 'nox': 150.0};

  int _sevOfValue(String m, double v) {
    final h = _harm[m], w = _warn[m];
    if (h != null && v >= h) return 2;
    if (w != null && v >= w) return 1;
    return 0;
  }

  // Severity (0..2) that COLOURS the heatmap, circles, preview cards and dots.
  // Only the gas metrics currently selected in the filter contribute, and the
  // colour reflects the highest severity among them. Prefer the firmware-provided
  // per-metric severity (s_*); for rows without it (community/Global), derive each
  // metric's severity from its raw value so filtering is accurate there too.
  int _gasSev(Map<String, dynamic> r) {
    int s = 0;
    for (final m in const ['co2', 'nox', 'voc']) {
      if (!_filter.contains(m)) continue;
      final sv = r['s_$m'];
      if (sv is num) { if (sv.toInt() > s) s = sv.toInt(); continue; }
      final v = r[m];
      if (v is num) { final lvl = _sevOfValue(m, v.toDouble()); if (lvl > s) s = lvl; }
    }
    return s.clamp(0, 2);
  }

  List<_Cluster> _cluster(double zoom) {
    final worldPx = 256 * pow(2, zoom);
    final cellDeg = (55 / worldPx) * 360;
    final buckets = <String, List<Map<String, dynamic>>>{};
    for (final r in _rows) {
      if (r['lat'] is! num || r['lon'] is! num) continue;
      final lat = (r['lat'] as num).toDouble(), lon = (r['lon'] as num).toDouble();
      final key = '${(lat / cellDeg).floor()}_${(lon / cellDeg).floor()}';
      (buckets[key] ??= []).add(r);
    }
    return buckets.values.map((grp) {
      double la = 0, lo = 0;
      int worst = 0; // worst-case severity among the filtered readings in the cell
      for (final r in grp) { la += (r['lat'] as num); lo += (r['lon'] as num); final sv = _gasSev(r); if (sv > worst) worst = sv; }
      return _Cluster(LatLng(la / grp.length, lo / grp.length), grp.length, worst, grp);
    }).toList();
  }

  // Grid-aggregated points for the heatmap: one blob per cell (coloured by the
  // cell's majority severity) so we draw tens of blurred blobs, not thousands.
  List<HeatPoint> _heatPoints(double zoom, KT k) {
    final worldPx = 256 * pow(2, zoom);
    final cellDeg = (34 / worldPx) * 360; // ~34 px cells
    final buckets = <String, List<Map<String, dynamic>>>{};
    for (final r in _rows) {
      if (r['lat'] is! num || r['lon'] is! num) continue;
      final lat = (r['lat'] as num).toDouble(), lon = (r['lon'] as num).toDouble();
      final key = '${(lat / cellDeg).floor()}_${(lon / cellDeg).floor()}';
      (buckets[key] ??= []).add(r);
    }
    final out = <HeatPoint>[];
    buckets.forEach((_, grp) {
      double la = 0, lo = 0;
      int worst = 0; // worst-case severity drives the blob colour (not the majority)
      for (final r in grp) { la += (r['lat'] as num); lo += (r['lon'] as num); final sv = _gasSev(r); if (sv > worst) worst = sv; }
      out.add(HeatPoint(LatLng(la / grp.length, lo / grp.length), k.sev(worst)));
    });
    return out;
  }

  List<LatLng> _routePoints() => _rows
      .where((r) => r['lat'] is num && r['lon'] is num)
      .map((r) => LatLng((r['lat'] as num).toDouble(), (r['lon'] as num).toDouble()))
      .toList();

  // Tap: zoom out → zoom in; otherwise open the NEAREST reading's dialog (this is
  // the fix — dots were clusters, so tapping them used to just zoom in).
  void _onTap(LatLng p) {
    if (widget.pickTrend) { _pickTrendLocation(p); return; }
    if (_placing) { setState(() => _placing = false); _addMarkerDialog(p); return; }
    if (_zoom < _heatmapBelowZoom) { _controller.move(p, _heatmapBelowZoom + 1); return; }
    const dist = Distance();
    Map<String, dynamic>? best;
    double bestM = double.infinity;
    for (final r in _rows) {
      if (r['lat'] is! num || r['lon'] is! num) continue;
      final m = dist(p, LatLng((r['lat'] as num).toDouble(), (r['lon'] as num).toDouble()));
      if (m < bestM) { bestM = m; best = r; }
    }
    if (best == null) return;
    final mPerPx = 156543.03392 * cos(p.latitudeInRad) / pow(2, _zoom);
    if (bestM <= max(22.0, 44 * mPerPx)) _showReading(best);  // generous tap target
  }

  // Trends location picker (#7.1.2): snap to the nearest data point in the period
  // and set it as the trend centre, then return to Stats.
  void _pickTrendLocation(LatLng p) {
    const dist = Distance();
    Map<String, dynamic>? best;
    double bestM = double.infinity;
    for (final r in _rows) {
      if (r['lat'] is! num || r['lon'] is! num) continue;
      final m = dist(p, LatLng((r['lat'] as num).toDouble(), (r['lon'] as num).toDouble()));
      if (m < bestM) { bestM = m; best = r; }
    }
    final mPerPx = 156543.03392 * cos(p.latitudeInRad) / pow(2, _zoom);
    if (best == null || bestM > max(60.0, 80 * mPerPx)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data there for your period. Tap a spot that has readings.')));
      return;
    }
    final st = context.read<KutsuState>();
    st.trends.locLat = (best['lat'] as num).toDouble();
    st.trends.locLon = (best['lon'] as num).toDouble();
    st.trends.source = _view;
    st.saveTrends();
    Navigator.pop(context, true);
  }

  // The single "worst" metric among the filter-selected ones for a row:
  // highest severity wins; ties fall back to _sevOrder priority. Used for the
  // most-zoomed-in floating labels.
  _Top? _topMetric(Map<String, dynamic> r) {
    String? key;
    int sev = -1;
    num? val;
    for (final m in _sevOrder) {
      if (!_filter.contains(m)) continue;
      final v = r[m];
      if (v is! num) continue;
      final sv = (r['s_$m'] is num) ? (r['s_$m'] as num).toInt() : 0;
      if (sv > sev) { sev = sv; key = m; val = v; }
    }
    if (key == null) return null;
    final txt = key == 'temp' ? val!.toStringAsFixed(1) : val!.round().toString();
    return _Top('${_shortName[key]} $txt', sev < 0 ? 0 : sev);
  }

  // Max-zoom: one floating label per reading = the worst selected metric's value.
  List<FloatReading> _floatItems(KT k) {
    final out = <FloatReading>[];
    for (final r in _rows) {
      if (r['lat'] is! num || r['lon'] is! num) continue;
      final top = _topMetric(r);
      if (top == null) continue;
      out.add(FloatReading(LatLng((r['lat'] as num).toDouble(), (r['lon'] as num).toDouble()),
          k.sev(top.sev), top.label));
    }
    return out;
  }

  // Mid-zoom: one multi-line preview card per cluster, listing the selected
  // metrics (area average), sorted so the most severe / largest cluster is laid
  // out first and wins placement when cards would collide.
  List<PreviewReading> _previewItems(List<_Cluster> clusters, KT k) {
    final sel = _previewOrder.where(_filter.contains).toList();
    if (sel.isEmpty) return const [];
    final sorted = [...clusters]
      ..sort((a, b) { final s = b.sev.compareTo(a.sev); return s != 0 ? s : b.count.compareTo(a.count); });
    final out = <PreviewReading>[];
    for (final c in sorted) {
      final lines = <String>[];
      for (final m in sel) {
        num sum = 0;
        int n = 0;
        for (final r in c.rows) { final v = r[m]; if (v is num) { sum += v; n++; } }
        if (n == 0) continue;
        final avg = sum / n;
        lines.add('${_shortName[m]}: ${m == 'temp' ? avg.toStringAsFixed(1) : avg.round()}');
      }
      if (lines.isEmpty) continue;
      out.add(PreviewReading(c.center, k.sev(c.sev), lines));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final k = ktOf(context);
    final s = context.watch<KutsuState>();
    // Dynamic readings (#4.3): when a new sample lands, refresh the local tabs.
    if (s.dataVersion != _seenRev) {
      _seenRev = s.dataVersion;
      if (_view != 'global') WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
    }
    final heat = _zoom < _heatmapBelowZoom;
    final floating = _zoom >= _floatAboveZoom;
    final clusters = (heat || floating) ? const <_Cluster>[] : _cluster(_zoom);  // mid-zoom only
    LatLng center;
    if (_rows.isNotEmpty && _rows.last['lat'] is num && _rows.last['lon'] is num) {
      center = LatLng((_rows.last['lat'] as num).toDouble(), (_rows.last['lon'] as num).toDouble());
    } else if (s.userLat != null) {
      center = LatLng(s.userLat!, s.userLon!);
    } else {
      center = const LatLng(20, 0);
    }

    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 4), child: Row(children: [
        Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _seg(k, 'All time', 'all'), const SizedBox(width: 8),
          _seg(k, 'This run', 'run'), const SizedBox(width: 8),
          _seg(k, 'Global', 'global'),
        ]))),
        const SizedBox(width: 8),
        OutlinedButton.icon(onPressed: _openFilter, icon: const Icon(Icons.tune, size: 18), label: const Text('Filter'),
          style: OutlinedButton.styleFrom(foregroundColor: k.ink, side: BorderSide(color: k.line))),
      ])),
      if (!widget.pickTrend && (_view == 'all' || _view == 'global')) _dateBar(k, showRuns: _view == 'all'),
      if (widget.pickTrend)
        Padding(padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
          child: Text('Pick a location: tap a spot that has readings in your period.',
              style: TextStyle(color: k.brand, fontSize: 12, fontWeight: FontWeight.w600))),
      Expanded(child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: k.line)),
        clipBehavior: Clip.antiAlias,
        child: (_rows.isEmpty && s.userLat == null)
            ? Container(color: k.panel, alignment: Alignment.center, padding: const EdgeInsets.all(24),
                child: Text('No located readings here. Connect with location on and walk around.',
                    textAlign: TextAlign.center, style: TextStyle(color: k.muted)))
            : Stack(children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: center, initialZoom: _zoom,
                    onTap: (_, p) => _onTap(p),
                    onPositionChanged: (cam, _) { if ((cam.zoom - _zoom).abs() > 0.2) setState(() => _zoom = cam.zoom); },
                  ),
                  children: [
                    tileLayerFor(_style),
                    if (_view == 'run' && _rows.length > 1)
                      PolylineLayer(polylines: [Polyline(points: _routePoints(), color: Colors.blueAccent, strokeWidth: 3)]),
                    if (heat)
                      HeatmapLayer(points: _heatPoints(_zoom, k))
                    else if (floating)
                      FloatingReadingsLayer(items: _floatItems(k))
                    else ...[
                      CircleLayer(circles: [
                        for (final c in clusters)
                          if (c.count == 1)
                            CircleMarker(point: c.center, radius: 10, useRadiusInMeter: true,
                              color: k.sev(c.sev).withOpacity(0.5), borderColor: k.sev(c.sev), borderStrokeWidth: 1.5)
                          else
                            CircleMarker(point: c.center, radius: (14 + sqrt(c.count) * 6).clamp(14, 64).toDouble(),
                              useRadiusInMeter: false, color: k.sev(c.sev).withOpacity(0.35), borderColor: k.sev(c.sev), borderStrokeWidth: 1.5),
                        for (final c in clusters)
                          CircleMarker(point: c.center, radius: 3.5, useRadiusInMeter: false,
                            color: Colors.white, borderColor: k.ink, borderStrokeWidth: 1.5),
                      ]),
                      PreviewReadingsLayer(items: _previewItems(clusters, k)),
                    ],
                    if (_markers.isNotEmpty)
                      MarkerLayer(markers: [
                        for (final m in _markers)
                          Marker(
                            point: LatLng((m['lat'] as num).toDouble(), (m['lon'] as num).toDouble()),
                            width: 40, height: 44, alignment: Alignment.topCenter,
                            child: GestureDetector(
                              onTap: () => _markerInfo(m),
                              child: Icon(Icons.place, size: 36, color: Color((m['color'] as int?) ?? 0xFFEF4444)),
                            ),
                          ),
                      ]),
                    if (s.userLat != null)
                      MarkerLayer(markers: [Marker(
                        point: LatLng(s.userLat!, s.userLon!), width: 34, height: 34,
                        child: Transform.rotate(angle: (s.userHeading ?? 0) * pi / 180,
                          child: const Icon(Icons.navigation, color: Colors.blue, size: 28)),
                      )]),
                  ],
                ),
                Positioned(top: 10, right: 10, child: Column(children: [
                  _recenterBtn(k, s),
                  const SizedBox(height: 8),
                  _styleBtn(k),
                  if (!widget.pickTrend) ...[
                    const SizedBox(height: 8),
                    _addMarkerBtn(k),
                  ],
                ])),
                if (_placing)
                  Positioned(top: 10, left: 10, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: k.ink.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Tap the map to place a marker', style: TextStyle(color: Colors.white, fontSize: 12)))),
                if (_globalLoading)
                  const Positioned.fill(child: IgnorePointer(child: Center(child: CircularProgressIndicator()))),
              ]),
      )),
      Padding(padding: const EdgeInsets.all(12),
        child: Text(
            _view == 'global'
                ? 'Global community readings (anonymous). Tap a dot for details.'
                : heat ? 'Zoom in for individual 10 m readings' : 'Tap a dot for its reading · green good · yellow warning · red alert',
            style: TextStyle(color: k.muted, fontSize: 12))),
    ]);
  }

  Widget _dateBar(KT k, {bool showRuns = true}) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(children: [
      OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_today, size: 16),
        label: Text(_date == null ? 'All time' : '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}'),
        style: OutlinedButton.styleFrom(foregroundColor: k.ink, side: BorderSide(color: k.line))),
      const SizedBox(width: 8),
      if (showRuns && _date != null)
        Expanded(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(border: Border.all(color: k.line), borderRadius: BorderRadius.circular(8)),
          child: DropdownButton<int?>(
            isExpanded: true, underline: const SizedBox(), value: _boot,
            dropdownColor: k.panel,
            hint: Text('All runs', style: TextStyle(color: k.ink, fontSize: 13)),
            items: [
              DropdownMenuItem(value: null, child: Text('All runs (${_runs.length})', style: TextStyle(color: k.ink, fontSize: 13))),
              for (final r in _runs)
                DropdownMenuItem(value: r['boot'] as int,
                  child: Text('Run ${TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(r['start'] as int)).format(context)} · ${r['n']}',
                      style: TextStyle(color: k.ink, fontSize: 13))),
            ],
            onChanged: (v) { setState(() => _boot = v); _load(); },
          ),
        )),
      if (_date != null) IconButton(onPressed: _clearDate, icon: Icon(Icons.close, color: k.muted, size: 18)),
    ]));

  Widget _recenterBtn(KT k, KutsuState s) => Material(
    color: k.panel, shape: const CircleBorder(), elevation: 3,
    child: InkWell(customBorder: const CircleBorder(),
      onTap: () { if (s.userLat != null) _controller.move(LatLng(s.userLat!, s.userLon!), max(_controller.camera.zoom, 16.0)); },
      child: Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.my_location, color: k.brand, size: 22))),
  );

  // Base-map style switcher (#4.1).
  Widget _styleBtn(KT k) => Material(
    color: k.panel, shape: const CircleBorder(), elevation: 3,
    child: InkWell(customBorder: const CircleBorder(), onTap: _pickStyle,
      child: Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.layers, color: k.ink, size: 22))),
  );

  // Arm/disarm marker placement (#4.2).
  Widget _addMarkerBtn(KT k) => Material(
    color: _placing ? k.brand : k.panel, shape: const CircleBorder(), elevation: 3,
    child: InkWell(customBorder: const CircleBorder(),
      onTap: () => setState(() => _placing = !_placing),
      child: Padding(padding: const EdgeInsets.all(10),
        child: Icon(Icons.add_location_alt, color: _placing ? Colors.white : k.ink, size: 22))),
  );

  void _pickStyle() {
    showModalBottomSheet(context: context, builder: (_) {
      final k = ktOf(context);
      return Container(color: k.panel, padding: const EdgeInsets.symmetric(vertical: 8), child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final e in kMapStyles.entries)
          ListTile(
            leading: Icon(Icons.map, color: _style == e.key ? k.brand : k.muted),
            title: Text(e.value.label, style: TextStyle(color: k.ink)),
            trailing: _style == e.key ? Icon(Icons.check, color: k.brand) : null,
            onTap: () { setState(() => _style = e.key); KutsuDb.instance.kvSet('map_style', e.value.id); Navigator.pop(context); },
          ),
      ]));
    });
  }

  static const _markerColors = <int>[0xFFEF4444, 0xFF22C55E, 0xFF3B82F6, 0xFFEAB308, 0xFFA855F7];

  void _addMarkerDialog(LatLng p) {
    final ctrl = TextEditingController();
    int color = _markerColors.first;
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, setD) {
      final k = ktOf(ctx);
      return AlertDialog(
        backgroundColor: k.panel,
        title: Text('New marker', style: TextStyle(color: k.ink)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: ctrl, autofocus: true, style: TextStyle(color: k.ink),
            decoration: InputDecoration(hintText: 'Title (e.g. Home, Recycling plant)', hintStyle: TextStyle(color: k.muted))),
          const SizedBox(height: 16),
          Row(children: [
            for (final c in _markerColors)
              GestureDetector(
                onTap: () => setD(() => color = c),
                child: Container(
                  margin: const EdgeInsets.only(right: 12), width: 30, height: 30,
                  decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle,
                    border: Border.all(color: color == c ? k.ink : Colors.transparent, width: 3)),
                ),
              ),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () async {
            final title = ctrl.text.trim().isEmpty ? 'Marker' : ctrl.text.trim();
            await KutsuDb.instance.addMarker(title: title, color: color, lat: p.latitude, lon: p.longitude);
            if (ctx.mounted) Navigator.pop(ctx);
            _loadMarkers();
          }, child: const Text('Save')),
        ],
      );
    }));
  }

  void _markerInfo(Map<String, dynamic> m) {
    final k = ktOf(context);
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: k.panel,
      title: Row(children: [
        Icon(Icons.place, color: Color((m['color'] as int?) ?? 0xFFEF4444)),
        const SizedBox(width: 8), Expanded(child: Text('${m['title']}', style: TextStyle(color: k.ink))),
      ]),
      content: Text('${(m['lat'] as num).toStringAsFixed(5)}, ${(m['lon'] as num).toStringAsFixed(5)}',
          style: TextStyle(color: k.muted)),
      actions: [
        TextButton(onPressed: () async {
          await KutsuDb.instance.deleteMarker(m['mid'] as int);
          if (mounted) Navigator.pop(context);
          _loadMarkers();
        }, child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    ));
  }

  Widget _seg(KT k, String label, String v) {
    final on = _view == v;
    return GestureDetector(onTap: () { setState(() => _view = v); _load(); },
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(color: on ? k.brand : k.chip, borderRadius: BorderRadius.circular(9)),
        child: Text(label, style: TextStyle(color: on ? Colors.white : k.muted, fontWeight: FontWeight.w600, fontSize: 13))));
  }

  void _openFilter() {
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, setD) {
      final k = ktOf(ctx);
      return AlertDialog(
        backgroundColor: k.panel,
        title: Text('Show in detail', style: TextStyle(color: k.ink)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final e in _metricNames.entries)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero, activeColor: k.brand,
              title: Text(e.value, style: TextStyle(color: k.ink)),
              value: _filter.contains(e.key),
              onChanged: (b) => setD(() { b == true ? _filter.add(e.key) : _filter.remove(e.key); setState(() {}); }),
            ),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
      );
    }));
  }

  void _showReading(Map<String, dynamic> r) {
    final k = ktOf(context);
    final ts = r['ts'] as int?;
    final when = ts != null ? DateTime.fromMillisecondsSinceEpoch(ts * 1000) : DateTime.fromMillisecondsSinceEpoch(r['recv'] as int);
    String f(String key, [int d = 0]) => r[key] is num ? (r[key] as num).toStringAsFixed(d) : '—';
    Widget row(String label, String val) => Padding(padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: k.muted)), Text(val, style: TextStyle(color: k.ink, fontWeight: FontWeight.w600))]));
    final units = {'co2': 'ppm', 'voc': 'idx', 'nox': 'idx', 'temp': '°C', 'hum': '%'};
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: k.panel,
      title: Row(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: k.sev(_gasSev(r)), shape: BoxShape.circle)),
        const SizedBox(width: 8), Text('Reading', style: TextStyle(color: k.ink)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        row('Time', '${when.toLocal()}'.split('.').first),
        for (final m in const ['co2', 'voc', 'nox', 'temp', 'hum'])
          if (_filter.contains(m)) row(_metricNames[m]!, '${f(m, m == 'temp' ? 1 : 0)} ${units[m]}'),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ));
  }
}
