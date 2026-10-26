import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../store/db.dart';

/// Uploads anonymous readings to a shared community air-quality map (#4).
///
/// Privacy: contributions are ANONYMOUS — Firebase Anonymous Auth gives a throwaway
/// identity (so the DB isn't open to spam) but no name/account, and only time, coarse
/// location and the readings are sent — never the device id / MAC.
/// Firestore collection: `observations` (append-only; see security rules).
class CommunityService {
  static bool get configured => true;

  /// Uploads stored geotagged readings. Returns how many were sent.
  static Future<int> contribute({int maxRows = 5000}) async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) await auth.signInAnonymously();

    final rows = await KutsuDb.instance.recent(maxRows);
    final col = FirebaseFirestore.instance.collection('observations');
    var batch = FirebaseFirestore.instance.batch();
    var pending = 0, sent = 0;

    for (final r in rows) {
      if (r['lat'] == null || r['lon'] == null) continue;
      batch.set(col.doc(), {
        'ts': r['ts'] ?? (r['recv'] as int) ~/ 1000,
        'lat': r['lat'], 'lon': r['lon'], 'sev': r['sev'],
        'co2': r['co2'], 'voc': r['voc'], 'nox': r['nox'], 'temp': r['temp'], 'hum': r['hum'],
        'src': 'kutsu',                      // anonymous: no device id / mac
        'uploadedAt': FieldValue.serverTimestamp(),
      });
      sent++;
      if (++pending >= 400) { await batch.commit(); batch = FirebaseFirestore.instance.batch(); pending = 0; }
    }
    if (pending > 0) await batch.commit();
    return sent;
  }

  /// Pulls shared community observations for the Global map tab (#4). Returns rows
  /// shaped like local records (lat/lon/co2/.../sev) so the map can render them with
  /// the same tiers. Newest first, capped.
  static Future<List<Map<String, dynamic>>> fetchGlobal({int limit = 3000}) async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) await auth.signInAnonymously();
    final snap = await FirebaseFirestore.instance
        .collection('observations')
        .orderBy('uploadedAt', descending: true)
        .limit(limit)
        .get();
    return _mapDocs(snap.docs);
  }

  /// Community observations within one calendar day (local time) — for the Global
  /// tab's calendar filter (#4 / date picker). `ts` is stored in seconds.
  static Future<List<Map<String, dynamic>>> fetchGlobalOnDate(DateTime day, {int limit = 3000}) async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) await auth.signInAnonymously();
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch ~/ 1000;
    final end = start + const Duration(days: 1).inSeconds;
    final snap = await FirebaseFirestore.instance
        .collection('observations')
        .where('ts', isGreaterThanOrEqualTo: start)
        .where('ts', isLessThan: end)
        .orderBy('ts', descending: true)
        .limit(limit)
        .get();
    return _mapDocs(snap.docs);
  }

  static List<Map<String, dynamic>> _mapDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final out = <Map<String, dynamic>>[];
    for (final d in docs) {
      final m = d.data();
      if (m['lat'] is! num || m['lon'] is! num) continue;
      out.add({
        'lat': m['lat'], 'lon': m['lon'], 'sev': m['sev'],
        'co2': m['co2'], 'voc': m['voc'], 'nox': m['nox'], 'temp': m['temp'], 'hum': m['hum'],
        'ts': m['ts'], 'recv': (m['ts'] is num) ? (m['ts'] as num).toInt() * 1000 : null,
        'src': 'community',
      });
    }
    return out;
  }
}
