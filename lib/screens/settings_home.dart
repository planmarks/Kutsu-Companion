import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/kutsu_state.dart';
import '../store/db.dart';
import '../services/community_service.dart';
import '../theme.dart';
import '../ui/widgets.dart';
import 'device_settings_screen.dart';
import 'alerts_screen.dart';
import 'sensors_screen.dart';
import 'trends_settings_screen.dart';
import 'wifi_screen.dart';
import 'dashboard_screen.dart';
import 'wardriving_screen.dart';

class SettingsHome extends StatefulWidget {
  const SettingsHome({super.key});
  @override
  State<SettingsHome> createState() => _SettingsHomeState();
}

class _SettingsHomeState extends State<SettingsHome> {
  int _count = 0;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final c = await KutsuDb.instance.count();
    final r = await KutsuDb.instance.recent(300);
    if (mounted) setState(() { _count = c; _rows = r; });
  }

  double? _avg(String key) {
    final xs = _rows.map((r) => r[key]).whereType<num>().map((n) => n.toDouble()).toList();
    return xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
  }
  String _f(double? v, [int d = 0]) => v == null ? '—' : v.toStringAsFixed(d);

  void _push(String title, Widget child) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(title)), body: child)));

  @override
  Widget build(BuildContext context) {
    final k = ktOf(context);
    final items = <List<dynamic>>[
      ['Device settings', 'Name, mode, outputs, wardriving', const DeviceSettingsScreen()],
      ['Alerts', 'Alarm signals + warning thresholds', const AlertsScreen()],
      ['Sensors', 'Sensor refresh rate', const SensorsScreen()],
      ['Trends', 'Stats display: session or location', const TrendsSettingsScreen()],
      ['WiFi setup', 'Join a network, room label', const WifiScreen()],
      ['Dashboard', 'Stationary master dashboard (same network)', const DashboardScreen()],
      ['Wardriving', 'WiFi/BLE collection + WiGLE (coming soon)', const WardrivingScreen()],
    ];

    return RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
      KCard(title: 'Settings', child: Column(children: [
        for (final it in items)
          InkWell(onTap: () => _push(it[0] as String, it[2] as Widget), child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: k.line, width: 0.5))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it[0] as String, style: TextStyle(color: k.ink, fontWeight: FontWeight.w600)),
                Text(it[1] as String, style: TextStyle(color: k.muted, fontSize: 12)),
              ])),
              Icon(Icons.chevron_right, color: k.muted),
            ]),
          )),
      ])),

      KCard(title: 'Collected data', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KRow('Stored samples', '$_count'),
        KRow('Avg CO₂ (recent)', '${_f(_avg('co2'))} ppm'),
        KRow('Avg temp', '${_f(_avg('temp'), 1)} °C'),
        KRow('Avg humidity', '${_f(_avg('hum'))} %'),
        const SizedBox(height: 12),
        KBtn('Import from device SD card', _importFromDevice, kind: 'ghost'),
        const SizedBox(height: 6),
        Text('Pulls the readings stored on the device over Bluetooth. Located readings '
            'appear on the Map; the rest show in Stats.', style: TextStyle(color: k.muted, fontSize: 12)),
        const SizedBox(height: 12),
        KBtn('Clear stored data', () => _confirmClear(), kind: 'danger'),
      ])),

      KCard(title: 'Community', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KBtn('Contribute to community map', _contribute),
        const SizedBox(height: 8),
        Text('Anonymously share your readings to a shared global air-quality map '
            '(no device id or personal data). ${CommunityService.configured ? '' : 'Needs Firebase setup first.'}',
            style: TextStyle(color: k.muted, fontSize: 12)),
      ])),

      KCard(title: 'Wardriving', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KRow('BLE devices', '—'),
        KRow('2.4G APs', '—'),
        KRow('5G APs', '—'),
        const SizedBox(height: 12),
        KBtn('Upload to WiGLE (coming soon)', () {}, kind: 'ghost'),
        const SizedBox(height: 8),
        KBtn('Delete stored data', () => _confirmClear(), kind: 'danger'),
        const SizedBox(height: 8),
        Text('Wardriving collection is pending a firmware scan-data feed.', style: TextStyle(color: k.muted, fontSize: 12)),
      ])),
    ]));
  }

  Future<void> _contribute() async {
    try {
      final n = await CommunityService.contribute();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Shared $n readings to the community map.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _importFromDevice() async {
    final s = context.read<KutsuState>();
    if (!s.connected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connect to the device first.')));
      return;
    }
    final progress = ValueNotifier<double>(0);
    showDialog(context: context, barrierDismissible: false, builder: (_) {
      final k = ktOf(context);
      return AlertDialog(
        backgroundColor: k.panel,
        title: Text('Importing from device', style: TextStyle(color: k.ink)),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, v, __) => Column(mainAxisSize: MainAxisSize.min, children: [
            LinearProgressIndicator(value: v == 0 ? null : v),
            const SizedBox(height: 10),
            Text(v == 0 ? 'Reading…' : '${(v * 100).round()}%', style: TextStyle(color: k.muted)),
          ]),
        ),
      );
    });
    try {
      final n = await s.importFromDevice(onProgress: (rec, total) {
        if (total > 0) progress.value = (rec / total).clamp(0, 1);
      });
      if (mounted) Navigator.of(context).pop(); // close progress
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $n readings from the device.')));
        _load();
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: ${'$e'.replaceFirst('Exception: ', '')}')));
    } finally {
      progress.dispose();
    }
  }

  void _confirmClear() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Clear data'),
      content: const Text('Delete all stored readings on this phone?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () async { Navigator.pop(context); await KutsuDb.instance.clear(); _load(); }, child: const Text('Delete')),
      ],
    ));
  }
}
