import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/mou_api.dart';
import '../theme.dart';
import 'step1_upload.dart';
import 'step2_details.dart';
import 'step3_verify.dart';
import 'step4_results.dart';

class WizardControllerScreen extends StatefulWidget {
  const WizardControllerScreen({super.key});

  @override
  State<WizardControllerScreen> createState() => _WizardControllerScreenState();
}

class _WizardControllerScreenState extends State<WizardControllerScreen> {
  int _currentStep = 1; // 1–4

  // ── Step 1: Document images ───────────────────────────────────────────────
  XFile? aadhaarImage;
  XFile? rationCardImage;

  // ── Step 2: Intake details ────────────────────────────────────────────────
  String? selectedLanguage;
  Symptom? selectedSymptom;
  String location = '';
  bool isAssisted = false; // FR-2 proxy mode

  // ── Step 3 / 4: Diagnosis result ──────────────────────────────────────────
  Diagnosis? diagnosis;
  String? diagnosisError;

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    }
  }

  void _restart() {
    setState(() {
      _currentStep = 1;
      aadhaarImage = null;
      rationCardImage = null;
      selectedLanguage = null;
      selectedSymptom = null;
      location = '';
      isAssisted = false;
      diagnosis = null;
      diagnosisError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: _buildCurrentStep(),
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
      leading: _currentStep > 1 && _currentStep < 4
          ? IconButton(
              icon: const Icon(Icons.arrow_back,
                  color: AppColors.primary, size: 28),
              onPressed: _previousStep,
            )
          : _currentStep == 4
              ? IconButton(
                  icon: const Icon(Icons.home,
                      color: AppColors.primary, size: 28),
                  onPressed: _restart,
                )
              : const SizedBox(width: 56),
      title: Text(
        _stepTitle(),
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
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
            widthFactor: _currentStep / 4.0,
            child: Container(color: AppColors.secondary),
          ),
        ),
      ),
    );
  }

  String _stepTitle() {
    switch (_currentStep) {
      case 1:
        return 'Step 1 of 4 — Upload Documents';
      case 2:
        return 'Step 2 of 4 — Your Details';
      case 3:
        return 'Step 3 of 4 — Verifying…';
      case 4:
        return 'Your Diagnosis';
      default:
        return 'Mou';
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return Step1Upload(
          aadhaarImage: aadhaarImage,
          rationCardImage: rationCardImage,
          onAadhaarPicked: (f) => setState(() => aadhaarImage = f),
          onRationCardPicked: (f) => setState(() => rationCardImage = f),
          onNext: _nextStep,
        );
      case 2:
        return Step2Details(
          selectedLanguage: selectedLanguage,
          selectedSymptom: selectedSymptom,
          location: location,
          isAssisted: isAssisted,
          onLanguageSelected: (v) => setState(() => selectedLanguage = v),
          onSymptomSelected: (v) => setState(() => selectedSymptom = v),
          onLocationChanged: (v) => setState(() => location = v),
          onAssistedChanged: (v) => setState(() => isAssisted = v),
          onNext: _nextStep,
          onBack: _previousStep,
        );
      case 3:
        return Step3Verify(
          aadhaarImage: aadhaarImage!,
          rationCardImage: rationCardImage!,
          symptom: selectedSymptom ?? Symptom.turnedAwayAtFps,
          fpsLocation: location,
          language: selectedLanguage,
          onDiagnosisReady: (d, err) {
            setState(() {
              diagnosis = d;
              diagnosisError = err;
            });
          },
          onNext: _nextStep,
          onBack: _previousStep,
        );
      case 4:
        return Step4Results(
          diagnosis: diagnosis,
          diagnosisError: diagnosisError,
          fpsLocation: location,
          onStartOver: _restart,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
