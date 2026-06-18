import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'api/mou_api.dart';
import 'theme.dart';
import 'screens/wizard_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Default points to Railway production backend (works from any device).
  // For local dev uncomment one of these:
  // MouApi.baseUrl = 'http://localhost:8000';         // iOS sim / Mac desktop
  // MouApi.baseUrl = 'http://10.0.2.2:8000';         // Android emulator
  // MouApi.baseUrl = 'http://192.168.1.39:8000';     // physical device on LAN

  runApp(const MouApp());
}

class MouApp extends StatelessWidget {
  const MouApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MOU',
      theme: appTheme,
      home: const WizardControllerScreen(),
    );
  }
}
