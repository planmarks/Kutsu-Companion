import 'package:flutter/material.dart';
import '../theme.dart';
import '../screens/connect_screen.dart';
import '../screens/live_screen.dart';
import '../screens/map_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/settings_home.dart';

class RootNav extends StatefulWidget {
  const RootNav({super.key});
  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  int _index = 0;
  static const _titles = ['Device', 'Live', 'Map', 'Stats', 'Settings'];
  final _pages = const [ConnectScreen(), LiveScreen(), MapScreen(), StatsScreen(), SettingsHome()];

  @override
  Widget build(BuildContext context) {
    final k = ktOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: k.brand.withOpacity(0.2),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.sensors), label: 'Device'),
          NavigationDestination(icon: Icon(Icons.eco), label: 'Live'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.insights), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
