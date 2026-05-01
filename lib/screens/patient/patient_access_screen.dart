import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/patient_session_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/patient_registry_service.dart';
import '../../services/patient_session_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/gradient_button.dart';

class PatientAccessScreen extends StatefulWidget {
  const PatientAccessScreen({super.key});

  @override
  State<PatientAccessScreen> createState() => _PatientAccessScreenState();
}

class _PatientAccessScreenState extends State<PatientAccessScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final accessCode = _codeController.text.trim();
    if (accessCode.isEmpty) {
      _showMessage('Please enter your patient ID or access code.');
      return;
    }

    setState(() => _isSubmitting = true);
    final registryService = context.read<PatientRegistryService>();
    final patientSessionService = context.read<PatientSessionService>();
    final sessionProvider = context.read<PatientSessionProvider>();
    final remoteProfile = await registryService.getByAccessCode(accessCode);
    if (remoteProfile != null) {
      await patientSessionService.saveLinkedProfile(
        remoteProfile.toPatientProfile(),
      );
    }
    final success = await sessionProvider.bootstrapAccess(
      enteredCode: accessCode,
      preferredName: _nameController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!success) {
      _showMessage('That ID does not match this patient device.');
      return;
    }

    await sessionProvider.touchActivity(
      'Home dashboard opened',
      contextSummary: 'You have opened your patient dashboard safely.',
    );

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.patientDashboard);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final session = context.watch<PatientSessionProvider>().profile;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 38,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Patient Access',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    session == null
                        ? 'Enter the patient ID or passcode to set up this patient device.'
                        : 'Enter the saved patient ID or access code to continue to the dashboard.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                CustomTextField(
                  label: 'Patient ID or access code',
                  controller: _codeController,
                  prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                  hintText: session?.patientId ?? 'patient_1234',
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  label: 'Preferred name (optional)',
                  controller: _nameController,
                  prefixIcon: const Icon(Icons.edit_outlined, size: 20),
                  hintText:
                      session?.displayName ?? 'How should we address you?',
                ),
                if (session != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saved patient profile',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${session.displayName} • ${session.homeLabel}',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'Caregiver: ${session.caregiverName} (${session.caregiverRelationship})',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                GradientButton(
                  text: _isSubmitting ? 'Checking...' : 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _isSubmitting ? null : _continue,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Use the caregiver-issued patient access code to open the linked patient space.',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
