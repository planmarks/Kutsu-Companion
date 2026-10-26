import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/kutsu_state.dart';
import '../theme.dart';
import '../ui/widgets.dart';

class WifiScreen extends StatefulWidget {
  const WifiScreen({super.key});
  @override
  State<WifiScreen> createState() => _WifiScreenState();
}

class _WifiScreenState extends State<WifiScreen> {
  final _ssid = TextEditingController();
  final _pw = TextEditingController();
  final _room = TextEditingController();

  @override
  void dispose() { _ssid.dispose(); _pw.dispose(); _room.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final k = ktOf(context);
    final s = context.watch<KutsuState>();
    if (!s.connected) return const KCenter('Connect a device to set up WiFi.');
    final st = s.status;
    final online = (st['ip'] ?? '').toString().isNotEmpty;

    void connect() {
      if (_ssid.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a network name')));
        return;
      }
      s.provisionWifi(_ssid.text.trim(), _pw.text, _room.text.trim().isEmpty ? null : _room.text.trim())
          .then((_) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent — joining the network…'))))
          .catchError((e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'))));
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      KCard(title: 'Status', child: Column(children: [
        KRow('WiFi', online ? '${st['ip']}' : 'not connected'),
        KRow('Role', '${st['role'] ?? 'solo'}'),
        KRow('Room', '${(st['room'] ?? '').toString().isEmpty ? '—' : st['room']}'),
      ])),
      KCard(title: 'WiFi setup', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _label(k, 'Network name (SSID)'), _field(k, _ssid, 'e.g. Workshop-2G'),
        _label(k, 'Password'), _field(k, _pw, 'Network password', obscure: true),
        _label(k, 'Room (optional)'), _field(k, _room, 'e.g. Kitchen'),
        Row(children: [
          Expanded(child: KBtn('Save & connect', connect)),
          const SizedBox(width: 10),
          Expanded(child: KBtn('Forget WiFi', () => s.forgetWifi(), kind: 'danger')),
        ]),
        const SizedBox(height: 10),
        Text('Prefer a 2.4 GHz network — every Kutsu module supports it; only the C5 also joins 5 GHz.',
            style: TextStyle(color: k.muted, fontSize: 12)),
      ])),
    ]);
  }

  Widget _label(KT k, String t) => Padding(padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Text(t, style: TextStyle(color: k.ink, fontWeight: FontWeight.w600)));

  Widget _field(KT k, TextEditingController c, String hint, {bool obscure = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, obscureText: obscure, autocorrect: false,
          decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: k.muted), isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: k.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: k.brand)))),
      );
}
