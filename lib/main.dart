import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'state/kutsu_state.dart';
import 'navigation/root_nav.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // App still runs locally if Firebase init fails; only the community map needs it.
  }
  runApp(const KutsuApp());
}

class KutsuApp extends StatelessWidget {
  const KutsuApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => KutsuState(),
      child: MaterialApp(
        title: 'Kutsu Companion',
        debugShowCheckedModeBanner: false,
        theme: kutsuTheme(Brightness.light),
        darkTheme: kutsuTheme(Brightness.dark),
        home: const SplashScreen(),
        routes: {'/home': (_) => const RootNav()},
      ),
    );
  }
}
