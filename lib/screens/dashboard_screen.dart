import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../state/kutsu_state.dart';
import '../ui/widgets.dart';

/// Mobile-friendly view of the stationary dashboard (3.1.9): the master serves its
/// SPA on the LAN; we embed it. The phone must be on the same network.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  WebViewController? _controller;
  String? _loadedIp;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<KutsuState>();
    final ip = (s.status['ip'] ?? '').toString();
    final role = s.status['role'];
    final canEmbed = ip.isNotEmpty && (role == 'master' || role == 'solo');

    if (!canEmbed) {
      return KCenter(role == 'slave'
          ? 'This unit is a slave — open the master node to see the full dashboard.'
          : 'The dashboard appears when the connected device is on WiFi (stationary master or handheld-local). Set up WiFi first.');
    }

    if (_controller == null || _loadedIp != ip) {
      _loadedIp = ip;
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse('http://$ip/'));
    }
    return WebViewWidget(controller: _controller!);
  }
}
