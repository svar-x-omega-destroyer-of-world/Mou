/// Mou API client — typed wrapper around the FastAPI backend (SRS §5).
///
/// Usage:
///   final diagnosis = await MouApi.instance.diagnose(
///     aadhaarImage: myFile,
///     rationCardImage: myFile2,
///     symptom: Symptom.turnedAwayAtFps,
///     fpsLocation: 'Silchar FPS #4471',
///     language: 'en',
///   );
///
/// Base URL: set [MouApi.baseUrl] before first use if connecting to a
/// non-default host (e.g. a physical device over LAN).

library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

// ── Config ──────────────────────────────────────────────────────────────────

/// Change this to your machine's LAN IP when running on a physical device.
/// e.g. 'http://192.168.1.42:8000'
/// For Android emulator: 'http://10.0.2.2:8000'
/// For iOS simulator / Mac desktop: 'http://localhost:8000'
const String _kDefaultBaseUrl = 'http://192.168.0.144:8000';

// ── Enums (mirroring API contract §5) ───────────────────────────────────────

enum Symptom {
  turnedAwayAtFps('turned_away_at_fps', 'Turned away at shop'),
  cardNotFound('card_not_found', 'Card not found at shop'),
  biometricFailed('biometric_failed', 'Biometric / fingerprint failed'),
  nameNotMatching('name_not_matching', 'Name not matching'),
  other('other', 'Other / not sure');

  const Symptom(this.apiValue, this.displayLabel);
  final String apiValue;
  final String displayLabel;
}

enum RootCause {
  nameMismatch('name_mismatch', 'Name Mismatch'),
  dobMismatch('dob_mismatch', 'Date of Birth Mismatch'),
  seedingGap('seeding_gap', 'Aadhaar Seeding Gap'),
  ekycIncomplete('ekyc_incomplete', 'e-KYC Incomplete'),
  biometricFailure('biometric_failure', 'Biometric Failure'),
  unknown('unknown', 'Unknown Cause');

  const RootCause(this.apiValue, this.displayLabel);
  final String apiValue;
  final String displayLabel;

  static RootCause fromApi(String v) =>
      RootCause.values.firstWhere((e) => e.apiValue == v,
          orElse: () => RootCause.unknown);
}

enum Confidence {
  high('high'),
  medium('medium'),
  low('low');

  const Confidence(this.apiValue);
  final String apiValue;

  static Confidence fromApi(String v) =>
      Confidence.values.firstWhere((e) => e.apiValue == v,
          orElse: () => Confidence.low);
}

// ── Response models ──────────────────────────────────────────────────────────

class Extracted {
  final String aadhaarName;
  final String rationNameScript;
  final String rationNameRomanized;
  final String? aadhaarDob;
  final String? rationDob;

  const Extracted({
    required this.aadhaarName,
    required this.rationNameScript,
    required this.rationNameRomanized,
    this.aadhaarDob,
    this.rationDob,
  });

  factory Extracted.fromJson(Map<String, dynamic> j) => Extracted(
        aadhaarName: j['aadhaar_name'] as String? ?? '',
        rationNameScript: j['ration_name_script'] as String? ?? '',
        rationNameRomanized: j['ration_name_romanized'] as String? ?? '',
        aadhaarDob: j['aadhaar_dob'] as String?,
        rationDob: j['ration_dob'] as String?,
      );

  /// Whether names look like a likely mismatch.
  ///
  /// NOTE: The backend uses fuzzy ITRANS-aware matching (rapidfuzz
  /// token_sort_ratio with v→b, ph→f, kh→k normalisation). A Dart-side
  /// strict string compare would give false positives (e.g. "Rahima Begum"
  /// vs "Rahima Begam" → mismatch, but backend may score ≥85). Rely on
  /// the backend's root_cause field instead. This getter is kept for
  /// informational use only and should not drive UI warnings.
  bool get namesLikelyMismatch => false;
}

class NextStep {
  final String office;
  final String form;

  const NextStep({required this.office, required this.form});

  factory NextStep.fromJson(Map<String, dynamic> j) => NextStep(
        office: j['office'] as String? ?? '',
        form: j['form'] as String? ?? '',
      );
}

class Diagnosis {
  final RootCause rootCause;
  final Confidence confidence;
  final Extracted extracted;
  final String explanation;
  final NextStep nextStep;
  final String disclaimer;
  final String explanationSource; // 'gemini' | 'fallback'
  final String caseId;            // 'anon-0042' — links to /feedback

  const Diagnosis({
    required this.rootCause,
    required this.confidence,
    required this.extracted,
    required this.explanation,
    required this.nextStep,
    required this.disclaimer,
    required this.explanationSource,
    this.caseId = '',
  });

  factory Diagnosis.fromJson(Map<String, dynamic> j) => Diagnosis(
        rootCause: RootCause.fromApi(j['root_cause'] as String? ?? ''),
        confidence: Confidence.fromApi(j['confidence'] as String? ?? ''),
        extracted:
            Extracted.fromJson(j['extracted'] as Map<String, dynamic>? ?? {}),
        explanation: j['explanation'] as String? ?? '',
        nextStep:
            NextStep.fromJson(j['next_step'] as Map<String, dynamic>? ?? {}),
        disclaimer: j['disclaimer'] as String? ?? '',
        explanationSource: j['explanation_source'] as String? ?? 'fallback',
        caseId: j['case_id'] as String? ?? '',
      );
}

class Case {
  final String caseId;
  final String pattern;

  const Case({required this.caseId, required this.pattern});

  factory Case.fromJson(Map<String, dynamic> j) => Case(
        caseId: j['case_id'] as String? ?? '',
        pattern: j['pattern'] as String? ?? '',
      );
}

class Cluster {
  final RootCause rootCause;
  final String fpsLocation;
  final int beneficiariesAffected;
  final Confidence confidence;
  final List<Case> cases;

  const Cluster({
    required this.rootCause,
    required this.fpsLocation,
    required this.beneficiariesAffected,
    required this.confidence,
    required this.cases,
  });

  factory Cluster.fromJson(Map<String, dynamic> j) => Cluster(
        rootCause: RootCause.fromApi(j['root_cause'] as String? ?? ''),
        fpsLocation: j['fps_location'] as String? ?? '',
        beneficiariesAffected: j['beneficiaries_affected'] as int? ?? 0,
        confidence: Confidence.fromApi(j['confidence'] as String? ?? ''),
        cases: (j['cases'] as List<dynamic>? ?? [])
            .map((c) => Case.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

// ── API exceptions ───────────────────────────────────────────────────────────

class ApiException implements Exception {
  final int? statusCode;
  final String message;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() =>
      statusCode != null ? 'ApiException($statusCode): $message' : 'ApiException: $message';
}

class UnreadableImageException extends ApiException {
  const UnreadableImageException(super.message) : super(statusCode: 422);
}

// ── Client ───────────────────────────────────────────────────────────────────

class MouApi {
  MouApi._({required String baseUrl}) : _base = Uri.parse(baseUrl);

  static MouApi? _instance;

  /// Override before first use, e.g. in main() for physical-device testing.
  static String baseUrl = _kDefaultBaseUrl;

  static MouApi get instance => _instance ??= MouApi._(baseUrl: baseUrl);

  final Uri _base;
  final http.Client _client = http.Client();

  // ── POST /diagnose ────────────────────────────────────────────────────────

  Future<Diagnosis> diagnose({
    required XFile aadhaarImage,
    required XFile rationCardImage,
    required Symptom symptom,
    String? fpsLocation,
    String? language,
  }) async {
    final uri = _base.replace(path: '/diagnose');
    final request = http.MultipartRequest('POST', uri);

    // Attach images
    request.files.add(await _toMultipart('aadhaar_image', aadhaarImage));
    request.files.add(await _toMultipart('ration_card_image', rationCardImage));

    // Form fields
    request.fields['symptom'] = symptom.apiValue;
    if (fpsLocation != null && fpsLocation.isNotEmpty) {
      request.fields['fps_location'] = fpsLocation;
    }
    if (language != null && language.isNotEmpty) {
      request.fields['language'] = language;
    }

    late http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request).timeout(const Duration(seconds: 30));
    } on SocketException catch (e) {
      throw ApiException(
        'Cannot reach the backend. Make sure the server is running.\n'
        'Details: ${e.message}',
      );
    } on Exception catch (e) {
      throw ApiException('Network error: $e');
    }

    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 422) {
      final decoded = _tryDecodeJson(body);
      final detail = decoded?['detail'];
      String msg = 'The document photo is too blurry to read. Please retake with better lighting.';
      if (detail is Map && detail['message'] != null) {
        msg = detail['message'] as String;
      }
      throw UnreadableImageException(msg);
    }

    if (streamed.statusCode != 200) {
      final decoded = _tryDecodeJson(body);
      final detail = decoded?['detail'] ?? body;
      throw ApiException('Server error: $detail', statusCode: streamed.statusCode);
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    return Diagnosis.fromJson(json);
  }

  // ── GET /clusters ─────────────────────────────────────────────────────────

  Future<List<Cluster>> clusters() async {
    final uri = _base.replace(path: '/clusters');
    late http.Response resp;
    try {
      resp = await _client.get(uri).timeout(const Duration(seconds: 15));
    } on SocketException catch (e) {
      throw ApiException('Cannot reach the backend: ${e.message}');
    }

    if (resp.statusCode != 200) {
      throw ApiException('Clusters error: ${resp.body}', statusCode: resp.statusCode);
    }

    final list = jsonDecode(resp.body) as List<dynamic>;
    return list
        .map((c) => Cluster.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  // ── POST /feedback ────────────────────────────────────────────────────────

  Future<void> submitFeedback({
    required String caseId,
    required RootCause rootCause,
    String? comment,
  }) async {
    final uri = _base.replace(path: '/feedback');
    late http.Response resp;
    try {
      resp = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'case_id': caseId,
              'root_cause': rootCause.apiValue,
              // ignore: use_null_aware_elements
              if (comment != null) 'comment': comment,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } on SocketException catch (e) {
      throw ApiException('Cannot reach the backend: ${e.message}');
    }

    if (resp.statusCode != 200) {
      throw ApiException('Feedback error: ${resp.body}', statusCode: resp.statusCode);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Future<http.MultipartFile> _toMultipart(
      String field, XFile xfile) async {
    final bytes = await xfile.readAsBytes();
    final filename = xfile.name.isNotEmpty ? xfile.name : '$field.jpg';
    // Guess content type from extension
    final ext = filename.split('.').last.toLowerCase();
    final mime = ext == 'png'
        ? MediaType('image', 'png')
        : MediaType('image', 'jpeg');
    return http.MultipartFile.fromBytes(field, bytes,
        filename: filename, contentType: mime);
  }

  static Map<String, dynamic>? _tryDecodeJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
