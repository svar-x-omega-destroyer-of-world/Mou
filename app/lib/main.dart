import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

const String _backendUrl = 'http://10.0.2.2:8000'; // Android emulator -> host
// Use 'http://localhost:8000' for iOS simulator or web

/// A tiny valid 1×1 PNG so we can exercise the multipart upload without
/// real document photos.  137 bytes, grey pixel.
final _dummyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGA'
  'WjR9awAAAABJRU5ErkJggg==',
);

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
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0D47A1),
        useMaterial3: true,
      ),
      home: const DiagnoseScreen(),
    );
  }
}

class DiagnoseScreen extends StatefulWidget {
  const DiagnoseScreen({super.key});

  @override
  State<DiagnoseScreen> createState() => _DiagnoseScreenState();
}

class _DiagnoseScreenState extends State<DiagnoseScreen> {
  bool _loading = false;
  String _result = '';
  String? _error;

  Future<void> _diagnose() async {
    setState(() {
      _loading = true;
      _result = '';
      _error = null;
    });

    try {
      final uri = Uri.parse('$_backendUrl/diagnose');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          http.MultipartFile.fromBytes(
            'aadhaar_image',
            _dummyPng,
            filename: 'aadhaar.png',
            contentType: MediaType('image', 'png'),
          ),
        )
        ..files.add(
          http.MultipartFile.fromBytes(
            'ration_card_image',
            _dummyPng,
            filename: 'ration.png',
            contentType: MediaType('image', 'png'),
          ),
        )
        ..fields['symptom'] = 'turned_away_at_fps'
        ..fields['fps_location'] = 'Silchar FPS #4471'
        ..fields['language'] = 'bn';

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final body = const JsonDecoder().convert(response.body);
        final formatted = const JsonEncoder.withIndent('  ').convert(body);
        setState(() => _result = formatted);
      } else {
        setState(() => _error = 'HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() => _error = 'Request failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MOU — Diagnosis Test')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Send two dummy images to /diagnose\nand inspect the mock response.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loading ? null : _diagnose,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(_loading ? 'Diagnosing…' : 'Run Diagnosis'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.red.shade800,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              if (_result.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: SelectableText(
                    _result,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
