import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/kutsu_state.dart';
import '../theme.dart';
import '../ui/widgets.dart';
import 'settings_widgets.dart';

const _fields = <String, List<List<String>>>{
  'co2': [['w', 'warn'], ['h', 'alert']], 'eco2': [['w', 'warn'], ['h', 'alert']], 'tvoc': [['w', 'warn'], ['h', 'alert']],
  'voc': [['w', 'warn'], ['h', 'alert']], 'nox': [['w', 'warn'], ['h', 'alert']], 'gas': [['w', 'warn'], ['h', 'alert']],
  'temp': [['wh', 'warn >'], ['hh', 'alert >'], ['hl', 'alert <']],
  'hum': [['wl', 'warn <'], ['wh', 'warn >'], ['hl', 'alert <'], ['hh', 'alert >']],
};
const _labels = <String, String>{
  'co2': 'CO₂ ppm', 'eco2': 'eCO₂ ppm', 'tvoc': 'TVOC ppb', 'voc': 'VOC idx', 'nox': 'NOx idx', 'gas': 'Gas adc', 'temp': 'Temp °C', 'hum': 'Hum %RH',
};

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final k = ktOf(context);
    final s = context.watch<KutsuState>();
    if (!s.connected) return const KCenter('Connect a device to change alerts.');
    final cfg = s.settings;
    final thr = s.thresholds;
    int sel(String key, int dflt) => (cfg[key] is int) ? cfg[key] as int : dflt;

    void save(Map<String, dynamic> o) => s.setSettings(o).catchError((_) {});
    void commit(String m, String f, String t) {
      final v = num.tryParse(t.trim());
      if (v != null) s.setThresholds({m: {f: v}}).catchError((_) {});
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      KCard(title: 'Alarm signals', child: Column(children: [
        SettingOptions(label: 'Buzzer signal', value: sel('buzzer_sig', 0),
            options: const ['Triple', 'Single', 'Long', 'Rapid', 'SOS'], onChanged: (v) => save({'buzzer_sig': v})),
        SettingOptions(label: 'LED — warning', value: sel('led_warn', 1),
            options: const ['Off', 'Slow', 'Fast', 'Solid', 'SOS'], onChanged: (v) => save({'led_warn': v})),
        SettingOptions(label: 'LED — alert', value: sel('led_alert', 3),
            options: const ['Off', 'Slow', 'Fast', 'Solid', 'SOS'], onChanged: (v) => save({'led_alert': v})),
      ])),
      KCard(title: 'Warning thresholds', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final m in _fields.keys)
          if (thr[m] is Map)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: k.line, width: 0.5))),
              child: Row(children: [
                Expanded(child: Text(_labels[m]!, style: TextStyle(color: k.ink, fontWeight: FontWeight.w600))),
                Flexible(child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
                  for (final f in _fields[m]!)
                    if ((thr[m] as Map)[f[0]] != null)
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(f[1], style: TextStyle(color: k.muted, fontSize: 9)),
                        SizedBox(width: 66, child: TextFormField(
                          key: ValueKey('$m.${f[0]}.${(thr[m] as Map)[f[0]]}'),
                          initialValue: '${(thr[m] as Map)[f[0]]}',
                          textAlign: TextAlign.right,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
                          style: TextStyle(color: k.ink, fontSize: 13),
                          decoration: inputDec(k, ''),
                          onFieldSubmitted: (t) => commit(m, f[0], t),
                        )),
                      ]),
                ])),
              ]),
            ),
        const SizedBox(height: 14),
        KBtn('Restore defaults', () => s.setThresholds({'reset': true}), kind: 'ghost'),
        const SizedBox(height: 10),
        Text('Warn = “!” level; Alert = full alarm. Edit a field and press Done to save.',
            style: TextStyle(color: k.muted, fontSize: 12)),
      ])),
    ]);
  }
}
