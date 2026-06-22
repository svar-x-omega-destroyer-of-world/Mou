import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/mou_api.dart';
import '../demo/demo_scenarios.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import 'welcome.dart';
import 'demo_select.dart';
import 'language_select.dart';
import 'step1_upload.dart';
import 'step2_details.dart';
import 'step3_verify.dart';
import 'step4_results.dart';

/// Flow:
///   0 Welcome → 1 Language → 2 Upload → 3 Details → 4 Verify → 5 Results
///
/// Language is chosen up front (step 1) so every later screen renders in the
/// selected language via [AppText].  Steps 1–5 form the progress bar; the
/// welcome screen (0) is a plain landing page with no app bar.
class WizardControllerScreen extends StatefulWidget {
  const WizardControllerScreen({super.key});

  @override
  State<WizardControllerScreen> createState() => _WizardControllerScreenState();
}

class _WizardControllerScreenState extends State<WizardControllerScreen> {
  static const int _welcome = 0;
  static const int _language = 1;
  static const int _upload = 2;
  static const int _details = 3;
  static const int _verify = 4;
  static const int _results = 5;
  // Demo scenario picker — sits between welcome and language only in the demo
  // flow.  Kept outside the 0–5 numbered range so the "Step X of N" counter and
  // progress bar maths for the real flow are untouched.
  static const int _demoSelect = 6;
  static const int _lastStep = _results;
  // Number of numbered steps shown in the "Step X of N" counter / progress bar.
  static const int _numberedSteps = 5;

  int _currentStep = _welcome;

  // ── Demo Mode: chosen scenario (null ⇒ live verification) ─────────────────
  DemoScenario? demoScenario;

  // ── Step 1: Preferred language (drives all UI copy) ───────────────────────
  String? selectedLanguage;

  // ── Step 2: Document images ───────────────────────────────────────────────
  XFile? aadhaarImage;
  XFile? rationCardImage;

  // ── Step 3: Intake details ────────────────────────────────────────────────
  Symptom? selectedSymptom;
  String location = '';
  bool isAssisted = false; // FR-2 proxy mode

  // ── Step 4 / 5: Diagnosis result ──────────────────────────────────────────
  Diagnosis? diagnosis;
  String? diagnosisError;

  void _nextStep() {
    if (_currentStep >= _lastStep) return;

    // Guard: don't advance past upload without both images — prevents the
    // force-unwrap crash in the verify step (aadhaarImage!).
    if (_currentStep == _upload &&
        (aadhaarImage == null || rationCardImage == null)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings(selectedLanguage ?? 'en').bothPhotosNeeded),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    setState(() => _currentStep++);
  }

  void _previousStep() {
    // The demo picker sits outside the numbered range — back returns to welcome.
    if (_currentStep == _demoSelect) {
      setState(() => _currentStep = _welcome);
      return;
    }
    // From the language step, back returns to the demo picker in the demo flow,
    // otherwise to the welcome screen.
    if (_currentStep == _language) {
      setState(() => _currentStep = demoScenario != null ? _demoSelect : _welcome);
      return;
    }
    if (_currentStep > _welcome && _currentStep <= _lastStep) {
      setState(() => _currentStep--);
    }
  }

  // ── Demo Mode entry ─────────────────────────────────────────────────────────
  void _startDemo() => setState(() => _currentStep = _demoSelect);

  void _onScenarioSelected(DemoScenario s) {
    setState(() {
      demoScenario = s;
      _currentStep = _language; // continue the full, normal flow
    });
  }

  void _restart() {
    setState(() {
      _currentStep = _welcome;
      demoScenario = null;
      selectedLanguage = null;
      aadhaarImage = null;
      rationCardImage = null;
      selectedSymptom = null;
      location = '';
      isAssisted = false;
      diagnosis = null;
      diagnosisError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Publish the selected language to the whole subtree.  Until the user picks
    // one (welcome + language steps) we default to English.
    return AppText(
      lang: selectedLanguage ?? 'en',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _currentStep == _welcome ? null : _buildAppBar(),
        body: SafeArea(child: _buildCurrentStep()),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: const Border(
        bottom: BorderSide(color: AppColors.primary, width: 2),
      ),
      leading: _currentStep > _language && _currentStep < _results
          ? IconButton(
              icon: const Icon(Icons.arrow_back,
                  color: AppColors.primary, size: 28),
              onPressed: _previousStep,
            )
          : _currentStep == _results
              ? IconButton(
                  icon: const Icon(Icons.home,
                      color: AppColors.primary, size: 28),
                  onPressed: _restart,
                )
              : IconButton(
                  // From the language step, back returns to the welcome screen.
                  icon: const Icon(Icons.arrow_back,
                      color: AppColors.primary, size: 28),
                  onPressed: _previousStep,
                ),
      title: Builder(
        builder: (context) => Text(
          _stepTitle(AppText.of(context)),
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      centerTitle: true,
      actions: const [SizedBox(width: 56)],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(8),
        child: Container(
          color: AppColors.surfaceContainerHighest,
          height: 8,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            // demoSelect (outside the numbered range) shows an empty bar.
            widthFactor: _currentStep <= _lastStep
                ? _currentStep / _numberedSteps
                : 0,
            child: Container(color: AppColors.secondary),
          ),
        ),
      ),
    );
  }

  String _stepTitle(AppStrings t) {
    switch (_currentStep) {
      case _demoSelect:
        return t.titleDemo;
      case _language:
        return '${t.stepOf(1, _numberedSteps)} — ${t.titleLanguage}';
      case _upload:
        return '${t.stepOf(2, _numberedSteps)} — ${t.titleUpload}';
      case _details:
        return '${t.stepOf(3, _numberedSteps)} — ${t.titleDetails}';
      case _verify:
        return t.titleVerifying;
      case _results:
        return t.titleDiagnosis;
      default:
        return t.appName;
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case _welcome:
        return WelcomeScreen(onGetStarted: _nextStep, onTryDemo: _startDemo);
      case _demoSelect:
        return DemoSelectScreen(onScenarioSelected: _onScenarioSelected);
      case _language:
        return LanguageSelectScreen(
          selectedLanguage: selectedLanguage,
          onLanguageSelected: (v) => setState(() => selectedLanguage = v),
          onContinue: _nextStep,
        );
      case _upload:
        return Step1Upload(
          aadhaarImage: aadhaarImage,
          rationCardImage: rationCardImage,
          onAadhaarPicked: (f) => setState(() => aadhaarImage = f),
          onRationCardPicked: (f) => setState(() => rationCardImage = f),
          onNext: _nextStep,
        );
      case _details:
        return Step2Details(
          selectedSymptom: selectedSymptom,
          location: location,
          isAssisted: isAssisted,
          onSymptomSelected: (v) => setState(() => selectedSymptom = v),
          onLocationChanged: (v) => setState(() => location = v),
          onAssistedChanged: (v) => setState(() => isAssisted = v),
          onNext: _nextStep,
          onBack: _previousStep,
        );
      case _verify:
        return Step3Verify(
          aadhaarImage: aadhaarImage!,
          rationCardImage: rationCardImage!,
          symptom: selectedSymptom ?? Symptom.turnedAwayAtFps,
          fpsLocation: location,
          language: selectedLanguage,
          // In demo mode the diagnosis is injected deterministically and the
          // backend is never called.  Live verification passes null.
          demoScenario: demoScenario,
          onDiagnosisReady: (d, err) {
            setState(() {
              diagnosis = d;
              diagnosisError = err;
            });
          },
          onNext: _nextStep,
          onBack: _previousStep,
        );
      case _results:
        return Step4Results(
          diagnosis: diagnosis,
          diagnosisError: diagnosisError,
          fpsLocation: location,
          demoScenario: demoScenario,
          onStartOver: _restart,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
