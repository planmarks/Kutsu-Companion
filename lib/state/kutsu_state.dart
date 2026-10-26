import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../ble/kutsu_ble.dart';
import '../store/db.dart';
import 'trends.dart';

/// App-wide Kutsu connection + device state.
class KutsuState extends ChangeNotifier {
  final KutsuBle ble = KutsuBle();

  final List<BluetoothDevice> devices = [];
  bool scanning = false;
  bool connecting = false;
  bool connected = false;
  String? connectedId;           // remoteId of the currently/last connected device (#5.2)

  // Bind-for-autoconnect (#1.1): remember a device and reconnect automatically.
  bool autoConnect = false;
  String? boundId;
  bool _manualDisconnect = false;
  bool _reconnecting = false;
  Map<String, dynamic> status = {};
  Map<String, dynamic> settings = {};
  Map<String, dynamic> thresholds = {};
  Map<String, dynamic>? record;
  final List<Map<String, dynamic>> history = []; // rolling window for the Live graphs
  static const _historyMax = 90;
  int dataVersion = 0;           // bumped after every stored record (map/stats auto-refresh)
  Timer? _livePoll;
  StreamSubscription<Position>? _posSub;
  Position? _lastPos;
  DateTime? _lastGeoPush;

  // Live user position for the map (blue heading arrow) + a reverse-geocoded label.
  double? userLat, userLon, userHeading;
  String? placeLabel;            // "City, Country"
  DateTime? _lastGeocode;

  KutsuState() {
    ble.onStatus = (s) { status = s; notifyListeners(); };
    ble.onSettings = (s) { settings = s; notifyListeners(); };
    ble.onThresholds = (t) { thresholds = t; notifyListeners(); };
    ble.onRecord = (r) {
      // Stamp each stored record with the phone's CURRENT location so a walk makes
      // a route, not one dot. (The device's own lat/lon only updates per TIMEGEO push.)
      if (_lastPos != null) {
        r['lat'] = _lastPos!.latitude;
        r['lon'] = _lastPos!.longitude;
        r['loc_ts'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      }
      record = r;
      history.add(r);
      if (history.length > _historyMax) history.removeAt(0);
      dataVersion++;
      KutsuDb.instance.insert(r); notifyListeners();
    };
    ble.onDisconnect = () {
      _stopTracking(); connected = false; record = null; notifyListeners();
      // Auto-reconnect unless the user disconnected on purpose.
      if (autoConnect && !_manualDisconnect) _autoReconnect();
    };
    ble.scanResults.listen((results) {
      for (final r in results) {
        if (!devices.any((d) => d.remoteId == r.device.remoteId)) devices.add(r.device);
      }
      notifyListeners();
    });
    _loadPrefs();
  }

  // Trends display preferences (#7).
  TrendsConfig trends = TrendsConfig();
  Future<void> saveTrends() async { await KutsuDb.instance.kvSet('trends', trends.encode()); notifyListeners(); }

  // Load persisted bind/autoconnect + trends prefs and, if enabled, start reconnecting.
  Future<void> _loadPrefs() async {
    autoConnect = (await KutsuDb.instance.kvGet('autoconnect')) == '1';
    boundId = await KutsuDb.instance.kvGet('bound_id');
    trends = TrendsConfig.decode(await KutsuDb.instance.kvGet('trends'));
    notifyListeners();
    if (autoConnect && boundId != null && !connected) _autoReconnect();
  }

  /// Toggle binding the current (or last) device for auto-connect (#1.1).
  Future<void> setAutoConnect(bool on) async {
    autoConnect = on;
    await KutsuDb.instance.kvSet('autoconnect', on ? '1' : '0');
    if (on) {
      final id = connectedId ?? boundId;
      if (id != null) { boundId = id; await KutsuDb.instance.kvSet('bound_id', id); }
    }
    notifyListeners();
    if (on && !connected && boundId != null) _autoReconnect();
  }

  Future<void> _autoReconnect() async {
    if (_reconnecting || connected || !autoConnect || boundId == null) return;
    _reconnecting = true;
    try {
      for (var attempt = 0; attempt < 30 && autoConnect && !connected && !_manualDisconnect; attempt++) {
        try {
          if (!await ble.requestPermissions()) break;
          await connect(BluetoothDevice.fromId(boundId!));
          break;
        } catch (_) {
          await Future.delayed(const Duration(seconds: 6));
        }
      }
    } finally { _reconnecting = false; }
  }

  Future<void> startScan() async {
    if (!await ble.requestPermissions()) throw Exception('Bluetooth/location permission denied');
    devices.clear();
    scanning = true; notifyListeners();
    await ble.startScan();
    scanning = false; notifyListeners();   // startScan resolves when the timeout elapses
  }

  Future<void> stopScan() async { await ble.stopScan(); scanning = false; notifyListeners(); }

  Future<void> connect(BluetoothDevice d) async {
    _manualDisconnect = false;
    connecting = true; history.clear(); notifyListeners();
    try {
      await ble.connect(d);
      connected = true; connectedId = d.remoteId.str; notifyListeners();
      // Keep the bound device pointed at the latest one we connect to.
      if (autoConnect && boundId != connectedId) {
        boundId = connectedId; KutsuDb.instance.kvSet('bound_id', connectedId!);
      }
      _startLivePoll();
      _contributeTimeGeo();   // immediate clock + first fix
      _startTracking();       // then continuous location
    } finally { connecting = false; notifyListeners(); }
  }

  void _startLivePoll() {
    _livePoll?.cancel();
    _livePoll = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (!connected) return;
      try { await ble.readLive(); } catch (_) {}
    });
  }

  // Continuous location: updates _lastPos (used to stamp records) and pushes the
  // fix to the device over TIMEGEO at most every 15 s so the device log is tagged too.
  Future<void> _startTracking() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) return;
      _posSub?.cancel();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
      ).listen((pos) {
        _lastPos = pos;
        userLat = pos.latitude; userLon = pos.longitude;
        if (pos.heading >= 0) userHeading = pos.heading;
        notifyListeners();
        final now = DateTime.now();
        if (_lastGeoPush == null || now.difference(_lastGeoPush!) > const Duration(seconds: 15)) {
          _lastGeoPush = now;
          ble.syncTimeGeo(now.millisecondsSinceEpoch ~/ 1000, lat: pos.latitude, lon: pos.longitude).catchError((_) {});
        }
        _reverseGeocode(pos.latitude, pos.longitude);
      });
    } catch (_) {}
  }

  Future<void> _reverseGeocode(double lat, double lon) async {
    final now = DateTime.now();
    if (_lastGeocode != null && now.difference(_lastGeocode!) < const Duration(seconds: 30)) return;
    _lastGeocode = now;
    try {
      final marks = await placemarkFromCoordinates(lat, lon);
      if (marks.isNotEmpty) {
        final m = marks.first;
        final city = (m.locality?.isNotEmpty ?? false) ? m.locality : m.subAdministrativeArea;
        final label = [city, m.country].where((e) => e != null && e.isNotEmpty).join(', ');
        if (label.isNotEmpty && label != placeLabel) { placeLabel = label; notifyListeners(); }
      }
    } catch (_) {}
  }

  void _stopTracking() { _livePoll?.cancel(); _posSub?.cancel(); _posSub = null; }

  Future<void> disconnect() async {
    _manualDisconnect = true;   // user-initiated → don't auto-reconnect
    _stopTracking();
    await ble.disconnect();
    connected = false; record = null; notifyListeners();
  }

  Future<void> setSettings(Map<String, dynamic> o) async {
    await ble.setSettings(o);
    settings = {...settings, ...o}; notifyListeners();
  }

  Future<void> setThresholds(Map<String, dynamic> patch) async {
    await ble.setThresholds(patch);
    await ble.readThresholds();
  }

  Future<void> provisionWifi(String ssid, String pw, String? room) => ble.provisionWifi(ssid, pw, room);
  Future<void> forgetWifi() => ble.forgetWifi();

  /// Import the device's stored SD/flash log over BLE (#3). Returns how many
  /// records were added. Geotagged ones reach the Map; the rest, Stats only.
  Future<int> importFromDevice({void Function(int received, int total)? onProgress}) async {
    final recs = await ble.dumpSdLog(onProgress: onProgress);
    final n = await KutsuDb.instance.importRecords(recs);
    dataVersion++; notifyListeners();
    return n;
  }

  Future<void> _contributeTimeGeo() async {
    final epoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    double? lat, lon;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
        );
        lat = pos.latitude; lon = pos.longitude;
      }
    } catch (_) {}
    try { await ble.syncTimeGeo(epoch, lat: lat, lon: lon); } catch (_) {}
  }
}
