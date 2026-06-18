import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'api/mou_api.dart';
import 'theme.dart';
import 'screens/wizard_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On Android emulator localhost resolves to the emulator itself, not the host.
  // On physical device it also fails. Override to the host machine's LAN IP.
  if (defaultTargetPlatform == TargetPlatform.android) {
    MouApi.baseUrl = kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
  }
  // Physical device override: change this to your Mac's LAN IP when running
  // on a real phone on the same Wi-Fi network.
  // MouApi.baseUrl = 'http://192.168.1.39:8000';

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
