import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/kutsu_state.dart';
import '../theme.dart';
import '../ui/widgets.dart';

class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final k = ktOf(context);
    final s = context.watch<KutsuState>();

    if (s.connected) {
      final st = s.status;
      final online = (st['ip'] ?? '').toString().isNotEmpty;
      return ListView(padding: const EdgeInsets.all(16), children: [
        KCard(title: 'Device', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _pill(k, 'Connected · ${st['role'] ?? 'solo'}', k.good),
            KBtn('Disconnect', () => s.disconnect(), kind: 'ghost'),
          ]),
          const SizedBox(height: 8),
          KRow('Name', '${st['name'] ?? '—'}'),
          KRow('Device ID', '${st['mac'] ?? '—'}'),
          KRow('WiFi', online ? '${st['ip']}' : 'not connected'),
          KRow('Room', '${(st['room'] ?? '').toString().isEmpty ? '—' : st['room']}'),
          KRow('Clock', (st['synced'] == true) ? 'synced' : 'not set'),
          KRow('Location', s.placeLabel ?? (st['geo'] == true ? '${st['lat']}, ${st['lon']}' : 'not set')),
        ])),
      ]);
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      KCard(title: 'Connect over Bluetooth', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (s.connecting)
          Row(children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10), Text('Connecting…', style: TextStyle(color: k.ink))])
        else
          KBtn(s.scanning ? 'Scanning…' : 'Scan for Kutsu devices',
              () => s.scanning ? s.stopScan() : _scan(context)),
        const SizedBox(height: 10),
        Text('Power the device on and keep it nearby. It advertises as “Kutsu-…” or its creature name.',
            style: TextStyle(color: k.muted, fontSize: 13)),
      ])),
      if (s.devices.isNotEmpty)
        KCard(title: 'Found', child: Column(children: [
          for (final d in s.devices)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: k.line, width: 0.5))),
              child: Row(children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: k.chip, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.memory, color: k.brand, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.platformName.isEmpty ? d.remoteId.str : d.platformName,
                      style: TextStyle(color: k.ink, fontWeight: FontWeight.w600)),
                  Text(d.remoteId.str, style: TextStyle(color: k.muted, fontSize: 12)),
                ])),
                KBtn('Connect', () => s.connect(d)),
              ]),
            ),
        ])),
    ]);
  }

  Future<void> _scan(BuildContext context) async {
    try {
      await context.read<KutsuState>().startScan();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
    }
  }

  Widget _pill(KT k, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: k.chip, borderRadius: BorderRadius.circular(999), border: Border.all(color: k.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Text(text, style: TextStyle(color: k.ink, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );
}
