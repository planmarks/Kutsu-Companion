import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/kutsu_state.dart';
import '../theme.dart';
import '../ui/widgets.dart';
import 'settings_widgets.dart';

// Device settings: Identity, Mode, Outputs, Wardriving (WiFi/BLE scanning).
// Alarm signals + thresholds live on the Alerts screen.
class DeviceSettingsScreen extends StatefulWidget {
  const DeviceSettingsScreen({super.key});
  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  final _name = TextEditingController();
  String _lastName = '';

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final k = ktOf(context);
    final s = context.watch<KutsuState>();
    if (!s.connected) return const KCenter('Connect a device to change settings.');
    final cfg = s.settings;

    final name = (cfg['name'] ?? '').toString();
    if (name != _lastName) { _lastName = name; _name.text = name; }

    void save(Map<String, dynamic> o) => s.setSettings(o)
        .catchError((e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Couldn't save: $e"))));
    bool on(String key) => cfg[key] == 1;

    return ListView(padding: const EdgeInsets.all(16), children: [
      KCard(title: 'Identity', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Device name', style: TextStyle(color: k.ink, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: TextField(controller: _name, decoration: inputDec(k, 'e.g. Otter-C3'))),
          const SizedBox(width: 8),
          KBtn('Save', () => save({'name': _name.text.trim()}), kind: 'ghost'),
        ]),
        const SizedBox(height: 6),
        Text('Clear and save to restore the factory creature name.', style: TextStyle(color: k.muted, fontSize: 12)),
      ])),

      KCard(title: 'Connection', child: Column(children: [
        SettingToggle(
          label: 'Bind for auto-connect',
          desc: 'Remember this device and reconnect to it automatically when it is in range.',
          value: s.autoConnect,
          onChanged: (v) => s.setAutoConnect(v)),
      ])),

      KCard(title: 'Mode', child: SettingOptions(
          label: 'Mode', value: cfg['mode'] == 'stationary' ? 1 : 0, options: const ['Handheld', 'Stationary'],
          onChanged: (v) => save({'mode': v == 1 ? 'stationary' : 'handheld'}))),

      KCard(title: 'Outputs', child: Column(children: [
        SettingToggle(label: 'Buzzer', value: on('buzzer'), onChanged: (v) => save({'buzzer': v ? 1 : 0})),
        SettingToggle(label: 'Warning LED', value: on('led'), onChanged: (v) => save({'led': v ? 1 : 0})),
        SettingToggle(label: 'Display', value: on('display'), onChanged: (v) => save({'display': v ? 1 : 0})),
      ])),

      KCard(title: 'Wardriving', child: Column(children: [
        SettingToggle(label: 'WiFi & BLE scanning', value: on('scan'), onChanged: (v) => save({'scan': v ? 1 : 0})),
        Padding(padding: const EdgeInsets.only(top: 8),
          child: Text('Scans nearby networks and Bluetooth devices. Setup stays reachable either way.',
              style: TextStyle(color: k.muted, fontSize: 12))),
      ])),
    ]);
  }
}
