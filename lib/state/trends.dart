import 'dart:convert';

/// Trends display preferences (#7). Persisted as JSON in the kv store.
///
/// mode 'session'  → Stats shows one recording session (run), chosen by date.
/// mode 'location' → Stats shows an area: all readings within [radiusM] of a
///                   chosen map point, within an optional date/time period, from
///                   a chosen source (All time / This run / Global).
class TrendsConfig {
  String mode;            // 'session' | 'location'
  int? boot;              // session mode: chosen run; null = most recent
  double radiusM;         // location mode: radius in metres
  String source;          // location mode: 'all' | 'run' | 'global'
  DateTime? dateFrom, dateTo;       // location mode: date period (null = any)
  int? timeStartMin, timeEndMin;    // location mode: minutes-from-midnight window (null = any)
  double? locLat, locLon;           // location mode: chosen centre

  TrendsConfig({
    this.mode = 'session', this.boot,
    this.radiusM = 150, this.source = 'all',
    this.dateFrom, this.dateTo, this.timeStartMin, this.timeEndMin,
    this.locLat, this.locLon,
  });

  bool get hasLocation => locLat != null && locLon != null;

  Map<String, dynamic> toJson() => {
    'mode': mode, 'boot': boot, 'radiusM': radiusM, 'source': source,
    'dateFrom': dateFrom?.millisecondsSinceEpoch, 'dateTo': dateTo?.millisecondsSinceEpoch,
    'timeStartMin': timeStartMin, 'timeEndMin': timeEndMin,
    'locLat': locLat, 'locLon': locLon,
  };

  static TrendsConfig fromJson(Map<String, dynamic> m) => TrendsConfig(
    mode: (m['mode'] as String?) ?? 'session',
    boot: m['boot'] as int?,
    radiusM: (m['radiusM'] as num?)?.toDouble() ?? 150,
    source: (m['source'] as String?) ?? 'all',
    dateFrom: m['dateFrom'] != null ? DateTime.fromMillisecondsSinceEpoch(m['dateFrom'] as int) : null,
    dateTo: m['dateTo'] != null ? DateTime.fromMillisecondsSinceEpoch(m['dateTo'] as int) : null,
    timeStartMin: m['timeStartMin'] as int?,
    timeEndMin: m['timeEndMin'] as int?,
    locLat: (m['locLat'] as num?)?.toDouble(),
    locLon: (m['locLon'] as num?)?.toDouble(),
  );

  String encode() => jsonEncode(toJson());
  static TrendsConfig decode(String? s) {
    if (s == null || s.isEmpty) return TrendsConfig();
    try { return fromJson(jsonDecode(s) as Map<String, dynamic>); } catch (_) { return TrendsConfig(); }
  }

  /// True if a record's timestamp falls inside the configured date/time period.
  bool inPeriod(int? tsSec, int recvMs) {
    final dt = tsSec != null
        ? DateTime.fromMillisecondsSinceEpoch(tsSec * 1000)
        : DateTime.fromMillisecondsSinceEpoch(recvMs);
    if (dateFrom != null && dt.isBefore(DateTime(dateFrom!.year, dateFrom!.month, dateFrom!.day))) return false;
    if (dateTo != null) {
      final end = DateTime(dateTo!.year, dateTo!.month, dateTo!.day).add(const Duration(days: 1));
      if (!dt.isBefore(end)) return false;
    }
    if (timeStartMin != null && timeEndMin != null) {
      final mod = dt.hour * 60 + dt.minute;
      if (timeStartMin! <= timeEndMin!) {
        if (mod < timeStartMin! || mod > timeEndMin!) return false;
      } else { // overnight window, e.g. 22:00–06:00
        if (mod < timeStartMin! && mod > timeEndMin!) return false;
      }
    }
    return true;
  }
}
