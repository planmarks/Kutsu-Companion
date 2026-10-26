import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/kutsu_state.dart';
import '../theme.dart';
import '../ui/widgets.dart';
import 'settings_widgets.dart';

/// Sensors submenu (#6): sensor refresh (sample) rate + restore to default.
/// The rate is sent to the device over the SETTINGS characteristic as `sample_ms`;
/// firmware applies it to the sampling loop.
class SensorsScreen extends StatelessWidget {
  const SensorsScreen({super.key});

  static const int _defaultMs = 1000;
  static const _opts = <List<dynamic>>[
    ['1 s', 1000], ['2 s', 2000], ['5 s', 5000], ['10 s', 10000], ['30 s', 30000],
  ];

  @override
  Widget build(BuildContext context) {
    final k = ktOf(context);
    final s = context.watch<KutsuState>();
    if (!s.connected) return const KCenter('Connect a device to change sensor settings.');

    final cur = (s.settings['sample_ms'] as num?)?.toInt() ?? _defaultMs;
    var idx = _opts.indexWhere((o) => o[1] == cur);
    if (idx < 0) idx = 0;

    void save(int ms) => s.setSettings({'sample_ms': ms})
        .catchError((e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Couldn't save: $e"))));

    return ListView(padding: const EdgeInsets.all(16), children: [
      KCard(title: 'Sensor refresh rate', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SettingOptions(
          label: 'Sample every',
          value: idx,
          options: [for (final o in _opts) o[0] as String],
          onChanged: (i) => save(_opts[i][1] as int)),
        const SizedBox(height: 10),
        Text('How often the device reads its sensors and logs a record. Faster rates give '
            'finer detail but use more power; slower rates extend battery life.',
            style: TextStyle(color: k.muted, fontSize: 12)),
      ])),

      KCard(title: 'Defaults', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KBtn('Restore to default', () => save(_defaultMs), kind: 'ghost'),
        const SizedBox(height: 8),
        Text('Resets the sample rate to ${_defaultMs ~/ 1000} s.', style: TextStyle(color: k.muted, fontSize: 12)),
      ])),
    ]);
  }
}
