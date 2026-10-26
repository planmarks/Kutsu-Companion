import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/kutsu_state.dart';
import '../theme.dart';
import '../ui/widgets.dart';
import 'settings_widgets.dart';

/// Trends submenu (#7). Chooses how the Stats "Environment trend" chart selects
/// its data: per recording Session, or per map Location (area). The per-use
/// controls (session date, radius, period, location) live on the Stats screen.
class TrendsSettingsScreen extends StatelessWidget {
  const TrendsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final k = ktOf(context);
    final s = context.watch<KutsuState>();
    final t = s.trends;

    return ListView(padding: const EdgeInsets.all(16), children: [
      KCard(title: 'Display trends per', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SettingOptions(
          label: 'Mode',
          value: t.mode == 'location' ? 1 : 0,
          options: const ['Session', 'Location'],
          onChanged: (v) { t.mode = v == 1 ? 'location' : 'session'; s.saveTrends(); }),
        const SizedBox(height: 12),
        Text(
          t.mode == 'location'
              ? 'Location: the Stats chart shows all readings within a radius of a point '
                'you pick on the map, over an optional date/time period, from the source '
                'you choose (All time, This run, or Global). Set the radius, period and '
                'location on the Stats screen.'
              : 'Session: the Stats chart shows one recording session. Pick a date and '
                'session on the Stats screen — it defaults to your most recent session.',
          style: TextStyle(color: k.muted, fontSize: 12.5, height: 1.35)),
      ])),
    ]);
  }
}
