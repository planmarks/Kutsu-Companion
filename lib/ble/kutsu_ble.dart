import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'contract.dart';

/// BLE client speaking the Kutsu GATT contract. flutter_blue_plus queues GATT
/// operations internally, so no manual op-serialization is needed.
class KutsuBle {
  BluetoothDevice? _device;
  final Map<String, BluetoothCharacteristic> _chr = {};
  final List<StreamSubscription> _subs = [];

  // Handlers set by the state layer.
  void Function(Map<String, dynamic>)? onStatus;
  void Function(Map<String, dynamic>)? onSettings;
  void Function(Map<String, dynamic>)? onThresholds;
  void Function(Map<String, dynamic>)? onRecord;
  void Function()? onDisconnect;

  Future<bool> requestPermissions() async {
    final res = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    return res.values.every((s) => s.isGranted || s.isLimited);
  }

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  Future<void> startScan() async {
    await FlutterBluePlus.startScan(
      withServices: [Guid(svcUuid)],
      timeout: const Duration(seconds: 20),
    );
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  Future<void> connect(BluetoothDevice device) async {
    await stopScan();
    await device.connect(timeout: const Duration(seconds: 15));
    _device = device;
    // Larger MTU speeds the SD-log dump (#3); harmless if the platform caps it.
    try { await device.requestMtu(512); } catch (_) {}

    _subs.add(device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected) {
        _cleanup();
        onDisconnect?.call();
      }
    }));

    final services = await device.discoverServices();
    final svc = services.firstWhere((s) => _eq(s.uuid, svcUuid));
    for (final c in svc.characteristics) {
      _chr[c.uuid.str.toLowerCase()] = c;
    }

    await _subscribe(chrStatus, (m) => onStatus?.call(m));
    await _subscribe(chrSettings, (m) => onSettings?.call(m));
    // LIVE is a ~330-byte record. BLE NOTIFICATIONS are capped at MTU-3 and would
    // truncate it (invalid JSON), so instead of subscribing we READ it — a GATT
    // read reassembles any length — on a timer from the state layer (readLive()).

    onStatus?.call(await _readJson(chrStatus));
    onSettings?.call(await _readJson(chrSettings));
    onThresholds?.call(await _readJson(chrThresholds));
    await readLive();
  }

  /// Read the current LIVE record (MTU-independent). Polled by the state layer.
  Future<void> readLive() async {
    final m = await _readJson(chrLive);
    if (m.isNotEmpty) onRecord?.call(m);
  }

  Future<void> disconnect() async {
    _cleanup();
    try { await _device?.disconnect(); } catch (_) {}
    _device = null;
  }

  // ---- Writes ---------------------------------------------------------------
  Future<void> provisionWifi(String ssid, String pw, [String? room]) =>
      _write(chrWifi, {'ssid': ssid, 'password': pw, 'room': room ?? ''});
  Future<void> forgetWifi() => _write(chrWifi, {'ssid': ''});
  Future<void> setSettings(Map<String, dynamic> o) => _write(chrSettings, o);
  Future<void> setThresholds(Map<String, dynamic> patch) => _write(chrThresholds, patch);
  Future<void> syncTimeGeo(int epoch, {double? lat, double? lon}) {
    final body = <String, dynamic>{'epoch': epoch};
    if (lat != null && lon != null) { body['lat'] = lat; body['lon'] = lon; }
    return _write(chrTimeGeo, body);
  }

  Future<Map<String, dynamic>> readThresholds() async {
    final t = await _readJson(chrThresholds);
    onThresholds?.call(t);
    return t;
  }

  /// Download the device's stored JSON-Lines log over BLE (#3). Writes a size
  /// request, then pulls the file in chunks by offset (MTU-agnostic — each chunk
  /// is staged by the write, so a long read reassembles a stable value). Returns
  /// the decoded records; `onProgress(received, total)` reports byte progress.
  Future<List<Map<String, dynamic>>> dumpSdLog({void Function(int received, int total)? onProgress}) async {
    final c = _chr[chrHistory.toLowerCase()];
    if (c == null) throw Exception('This firmware does not support SD import.');

    Future<void> write(Map<String, dynamic> o) => c.write(utf8.encode(jsonEncode(o)), withoutResponse: false);

    await write({'cmd': 'size'});
    final head = _decode(await c.read()) ?? {};
    final total = (head['size'] is num) ? (head['size'] as num).toInt() : 0;
    if (total <= 0) return [];

    final bytes = <int>[];
    var off = 0;
    var guard = 0;
    while (off < total && guard < 100000) {
      guard++;
      await write({'o': off});
      final chunk = await c.read();
      if (chunk.isEmpty) break;
      bytes.addAll(chunk);
      off += chunk.length;
      onProgress?.call(off, total);
    }

    // Split the accumulated JSON-Lines into records (ignore timesync anchors).
    final out = <Map<String, dynamic>>[];
    for (final line in utf8.decode(bytes, allowMalformed: true).split('\n')) {
      final s = line.trim();
      if (s.isEmpty) continue;
      try {
        final v = jsonDecode(s);
        if (v is Map<String, dynamic> && (v['co2'] != null || v['temp'] != null || v['voc'] != null)) {
          out.add(v);
        }
      } catch (_) {}
    }
    return out;
  }

  // ---- internals ------------------------------------------------------------
  bool _eq(Guid g, String uuid) => g.str.toLowerCase() == uuid.toLowerCase();

  Future<void> _subscribe(String uuid, void Function(Map<String, dynamic>) cb) async {
    final c = _chr[uuid.toLowerCase()];
    if (c == null) return;
    await c.setNotifyValue(true);
    _subs.add(c.onValueReceived.listen((bytes) {
      final m = _decode(bytes);
      if (m != null) cb(m);
    }));
  }

  Future<Map<String, dynamic>> _readJson(String uuid) async {
    final c = _chr[uuid.toLowerCase()];
    if (c == null) return {};
    return _decode(await c.read()) ?? {};
  }

  Future<void> _write(String uuid, Map<String, dynamic> obj) async {
    final c = _chr[uuid.toLowerCase()];
    if (c == null) throw Exception('characteristic $uuid not found');
    await c.write(utf8.encode(jsonEncode(obj)), withoutResponse: false);
  }

  Map<String, dynamic>? _decode(List<int> bytes) {
    try {
      final v = jsonDecode(utf8.decode(bytes));
      return v is Map<String, dynamic> ? v : null;
    } catch (_) { return null; }
  }

  void _cleanup() {
    for (final s in _subs) { s.cancel(); }
    _subs.clear();
    _chr.clear();
  }
}
