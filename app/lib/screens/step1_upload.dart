import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';

class Step1Upload extends StatelessWidget {
  final XFile? aadhaarImage;
  final XFile? rationCardImage;
  final ValueChanged<XFile?> onAadhaarPicked;
  final ValueChanged<XFile?> onRationCardPicked;
  final VoidCallback onNext;

  const Step1Upload({
    super.key,
    required this.aadhaarImage,
    required this.rationCardImage,
    required this.onAadhaarPicked,
    required this.onRationCardPicked,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final bool canContinue = aadhaarImage != null && rationCardImage != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Upload Your Documents',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.primary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'Take a clear photo of each card.\nBoth are needed to check for mismatches.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 32),

          _PhotoCard(
            title: 'Aadhaar Card',
            subtitle: 'Government ID / Aadhaar',
            icon: Icons.badge_outlined,
            picked: aadhaarImage,
            onPick: () => _pickImage(context, onAadhaarPicked),
          ),
          const SizedBox(height: 16),
          _PhotoCard(
            title: 'Ration Card',
            subtitle: 'PDS / ONORC ration card',
            icon: Icons.receipt_long_outlined,
            picked: rationCardImage,
            onPick: () => _pickImage(context, onRationCardPicked),
          ),

          const SizedBox(height: 40),

          // FR-4 hint
          if (!canContinue)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.outlineVariant, width: 1.5),
              ),
              child: const Row(
                children: [
                  Icon(Icons.tips_and_updates_outlined,
                      color: AppColors.secondary, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tip: Hold your card flat with good lighting. Avoid shadows and glare.',
                      style: TextStyle(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: canContinue ? onNext : null,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continue to Step 2'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  canContinue ? AppColors.secondary : AppColors.surfaceContainerHigh,
              foregroundColor:
                  canContinue ? Colors.white : AppColors.outline,
            ),
          ),

          if (!canContinue)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Upload both documents to continue.',
                style: TextStyle(
                    color: AppColors.onSurfaceVariant, fontSize: 14),
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _pickImage(
      BuildContext context, ValueChanged<XFile?> onPicked) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Choose photo source',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.primary)),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_camera, color: AppColors.primary),
              title: const Text('Take a photo',
                  style: TextStyle(fontSize: 17)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library,
                  color: AppColors.primary),
              title: const Text('Choose from gallery',
                  style: TextStyle(fontSize: 17)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2000,
    );
    onPicked(file);
  }
}

// ── Photo card widget ─────────────────────────────────────────────────────────

class _PhotoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final XFile? picked;
  final VoidCallback onPick;

  const _PhotoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.picked,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasPic = picked != null;

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        decoration: BoxDecoration(
          color: hasPic ? const Color(0xFFEEF7F1) : AppColors.surfaceContainerLowest,
          border: Border.all(
            color: hasPic ? AppColors.secondary : AppColors.primary,
            width: hasPic ? 3 : 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: hasPic
            ? _PickedPreview(file: picked!, onRetake: onPick, title: title)
            : _EmptySlot(icon: icon, title: title, subtitle: subtitle),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptySlot(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 52, color: AppColors.primary),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 15, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 20),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_camera, size: 20, color: Colors.white),
                SizedBox(width: 8),
                Text('Take Photo',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickedPreview extends StatelessWidget {
  final XFile file;
  final VoidCallback onRetake;
  final String title;

  const _PickedPreview(
      {required this.file, required this.onRetake, required this.title});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(file.path),
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
          ),
        ),
        // Checkmark badge
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)
              ],
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 20),
          ),
        ),
        // Retake button bottom
        Positioned(
          bottom: 10,
          right: 10,
          child: GestureDetector(
            onTap: onRetake,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.replay, color: Colors.white, size: 15),
                  SizedBox(width: 4),
                  Text('Retake',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
        // Title badge top-left
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
