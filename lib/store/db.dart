import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../ble/contract.dart';

/// Local storage of collected readings (3.1.4).
class KutsuDb {
  static final KutsuDb instance = KutsuDb._();
  KutsuDb._();
  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'kutsu.db'),
      version: 3,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE records (
            rid INTEGER PRIMARY KEY AUTOINCREMENT,
            dev TEXT, mac TEXT, recv INTEGER, boot INTEGER,
            ts INTEGER, up INTEGER, sev INTEGER,
            lat REAL, lon REAL,
            co2 REAL, voc REAL, nox REAL, temp REAL, hum REAL, eco2 REAL, tvoc REAL, gas REAL,
            json TEXT
          )''');
        await db.execute('CREATE INDEX idx_recv ON records(recv)');
        await db.execute('CREATE INDEX idx_boot ON records(boot)');
        await db.execute('CREATE INDEX idx_geo ON records(lat, lon)');
        await _createV2(db);
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) await _createV2(db);
        if (oldV < 3) await _migrateV3(db);
      },
    );
    return _db!;
  }

  // v2: user-placed map markers (#4.2) + a small key/value store for app prefs
  // (bound device id, trends prefs, map style, sensor-rate cache, etc.).
  static Future<void> _createV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS markers (
        mid INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT, color INTEGER, lat REAL, lon REAL, created INTEGER
      )''');
    await db.execute('CREATE TABLE IF NOT EXISTS kv (k TEXT PRIMARY KEY, v TEXT)');
  }

  // v3: a session = one device power-on period. Recompute `boot` for existing rows
  // from the device clock (power-on epoch = ts - up), which is stable across a
  // whole power cycle — the old `recv - up*1000` jittered per reading and split
  // each session into many 1-reading fragments. Rows without a usable device clock
  // (ts missing / unsynced) keep their previous key.
  static Future<void> _migrateV3(Database db) async {
    await db.execute(
      'UPDATE records SET boot = (ts - up) * 1000 WHERE ts IS NOT NULL AND up > 0 AND ts > up');
  }

  // Stable session key (ms): device power-on epoch when the device clock is usable,
  // else a coarse fallback from the phone estimate before the clock is synced.
  static int sessionKey(int? ts, int up, int recv) {
    if (ts != null && up > 0 && ts > up) return (ts - up) * 1000;
    return ((recv - up * 1000) / 5000).round() * 5000; // quantise to 5 s pre-sync
  }

  // ---- Markers (#4.2) --------------------------------------------------------
  Future<int> addMarker({required String title, required int color, required double lat, required double lon}) async =>
      (await _database).insert('markers', {
        'title': title, 'color': color, 'lat': lat, 'lon': lon,
        'created': DateTime.now().millisecondsSinceEpoch,
      });

  Future<List<Map<String, dynamic>>> markers() async =>
      (await _database).query('markers', orderBy: 'created DESC');

  Future<void> deleteMarker(int mid) async =>
      (await _database).delete('markers', where: 'mid = ?', whereArgs: [mid]);

  // ---- Key/value prefs -------------------------------------------------------
  Future<String?> kvGet(String key) async {
    final r = await (await _database).query('kv', where: 'k = ?', whereArgs: [key], limit: 1);
    return r.isEmpty ? null : r.first['v'] as String?;
  }

  Future<void> kvSet(String key, String value) async =>
      (await _database).insert('kv', {'k': key, 'v': value}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> insert(Map<String, dynamic> r, {int? recvMs}) async {
    final db = await _database;
    final up = asInt(r['up']) ?? 0;
    final ts = asInt(r['ts']);
    final recv = recvMs ?? DateTime.now().millisecondsSinceEpoch;
    await db.insert('records', {
      'dev': r['id'] ?? '', 'mac': r['mac'] ?? '', 'recv': recv, 'boot': sessionKey(ts, up, recv),
      'ts': ts, 'up': up, 'sev': asInt(r['sev']) ?? 0,
      'lat': asDouble(r['lat']), 'lon': asDouble(r['lon']),
      'co2': asDouble(r['co2']), 'voc': asDouble(r['voc']), 'nox': asDouble(r['nox']),
      'temp': asDouble(r['temp']), 'hum': asDouble(r['hum']),
      'eco2': asDouble(r['eco2']), 'tvoc': asDouble(r['tvoc']), 'gas': asDouble(r['gas']),
      'json': jsonEncode(r),
    });
  }

  // Import records pulled from the device's SD log (#3). Each record keeps its
  // own timestamp (recv = ts, so it sorts to its real date), and geotagged rows
  // (lat/lon present) show on the Map while un-geotagged rows appear in Stats only.
  // Returns how many were inserted. De-dups within this call by (ts,up) key.
  Future<int> importRecords(List<Map<String, dynamic>> records) async {
    final db = await _database;
    final batch = db.batch();
    final seen = <String>{};
    var n = 0;
    for (final r in records) {
      final ts = asInt(r['ts']);
      final up = asInt(r['up']) ?? 0;
      final key = '${ts ?? 0}_$up';
      if (!seen.add(key)) continue;
      final recv = (ts != null && ts > 0) ? ts * 1000 : DateTime.now().millisecondsSinceEpoch;
      batch.insert('records', {
        'dev': r['id'] ?? '', 'mac': r['mac'] ?? '', 'recv': recv, 'boot': sessionKey(ts, up, recv),
        'ts': ts, 'up': up, 'sev': asInt(r['sev']) ?? 0,
        'lat': asDouble(r['lat']), 'lon': asDouble(r['lon']),
        'co2': asDouble(r['co2']), 'voc': asDouble(r['voc']), 'nox': asDouble(r['nox']),
        'temp': asDouble(r['temp']), 'hum': asDouble(r['hum']),
        'eco2': asDouble(r['eco2']), 'tvoc': asDouble(r['tvoc']), 'gas': asDouble(r['gas']),
        'json': jsonEncode(r),
      });
      n++;
    }
    await batch.commit(noResult: true);
    return n;
  }

  Future<List<Map<String, dynamic>>> recent([int limit = 500]) async =>
      (await _database).query('records', orderBy: 'recv DESC', limit: limit);

  Future<List<Map<String, dynamic>>> geoRows([int limit = 2000]) async =>
      (await _database).query('records',
          where: 'lat IS NOT NULL AND lon IS NOT NULL', orderBy: 'recv DESC', limit: limit);

  Future<List<Map<String, dynamic>>> runRows() async {
    final db = await _database;
    final top = await db.query('records', columns: ['boot'], orderBy: 'recv DESC', limit: 1);
    if (top.isEmpty) return [];
    return db.query('records',
        where: 'boot = ? AND lat IS NOT NULL AND lon IS NOT NULL',
        whereArgs: [top.first['boot']], orderBy: 'recv ASC');
  }

  // Geo rows within a calendar day (local time).
  Future<List<Map<String, dynamic>>> geoRowsOnDate(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = start + const Duration(days: 1).inMilliseconds;
    return (await _database).query('records',
        where: 'recv >= ? AND recv < ? AND lat IS NOT NULL AND lon IS NOT NULL',
        whereArgs: [start, end], orderBy: 'recv ASC');
  }

  // Geo rows for one run (boot session).
  Future<List<Map<String, dynamic>>> geoRowsForBoot(int boot) async =>
      (await _database).query('records',
          where: 'boot = ? AND lat IS NOT NULL AND lon IS NOT NULL', whereArgs: [boot], orderBy: 'recv ASC');

  // Most recent run (boot), or null if empty. (#7.1.1 default session.)
  Future<int?> latestBoot() async {
    final r = await (await _database).query('records', columns: ['boot'], orderBy: 'recv DESC', limit: 1);
    return r.isEmpty ? null : r.first['boot'] as int?;
  }

  // All records for one run (boot), geotagged or not, oldest → newest (#7.1.1).
  Future<List<Map<String, dynamic>>> rowsForBoot(int boot) async =>
      (await _database).query('records', where: 'boot = ?', whereArgs: [boot], orderBy: 'recv ASC');

  // Distinct runs (boots) with records on a day, each with its start time + count.
  Future<List<Map<String, dynamic>>> runsOnDate(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = start + const Duration(days: 1).inMilliseconds;
    return (await _database).rawQuery(
        'SELECT boot, MIN(recv) AS start, COUNT(*) AS n FROM records '
        'WHERE recv >= ? AND recv < ? GROUP BY boot ORDER BY start ASC',
        [start, end]);
  }

  Future<int> count() async =>
      Sqflite.firstIntValue(await (await _database).rawQuery('SELECT COUNT(*) FROM records')) ?? 0;

  Future<void> clear() async => (await _database).delete('records');

  // Export all records as a CSV string (3.1.4 / EXPORT section).
  Future<String> exportCsv() async {
    final db = await _database;
    final rows = await db.query('records', orderBy: 'recv ASC');
    const cols = ['recv', 'ts', 'up', 'sev', 'lat', 'lon', 'co2', 'voc', 'nox', 'temp', 'hum', 'eco2', 'tvoc', 'gas', 'dev', 'mac'];
    final sb = StringBuffer(cols.join(','))..write('\n');
    for (final r in rows) {
      sb.write(cols.map((c) {
        final v = r[c];
        if (v == null) return '';
        final s = v.toString();
        return s.contains(',') ? '"$s"' : s;
      }).join(','));
      sb.write('\n');
    }
    return sb.toString();
  }
}
