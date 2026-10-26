import 'package:flutter/material.dart';
import '../theme.dart';
import '../ui/widgets.dart';
import 'settings_widgets.dart';

// 3.1.10 — nearby WiFi AP + BLE device collection (wardriving). PLACEHOLDER: the
// firmware logs scans to SD but doesn't yet stream them over BLE; once a scan-data
// feed exists this screen collects them (RSSI/geo/time) and can upload to WiGLE.
class WardrivingScreen extends StatelessWidget {
  const WardrivingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final k = ktOf(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      KCard(title: 'Wardriving (coming soon)', child: Text(
        'Collects nearby WiFi access points and Bluetooth devices the Kutsu scans — with RSSI, '
        'your location and time — for mapping and WiGLE submission. Pending a firmware scan-data '
        'BLE feed; the device already logs scans to its SD card.',
        style: TextStyle(color: k.muted))),
      KCard(title: 'WiGLE submission', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('API name', style: TextStyle(color: k.ink, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(enabled: false, decoration: inputDec(k, 'WiGLE API name (coming soon)')),
        const SizedBox(height: 12),
        Text('API token', style: TextStyle(color: k.ink, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(enabled: false, obscureText: true, decoration: inputDec(k, 'WiGLE API token (coming soon)')),
        const SizedBox(height: 6),
        Text('Credentials from wigle.net → Account. Used to upload collected observations.',
            style: TextStyle(color: k.muted, fontSize: 12)),
      ])),
    ]);
  }
}
