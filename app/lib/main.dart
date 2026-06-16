import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/wizard_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
