import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/custom_text_field.dart';
import 'dart:math';
import '../../../widgets/gradient_button.dart';
import '../../../models/caregiver_session.dart';
import '../../../models/patient/patient_profile.dart';
import '../../../models/patient_registry_record.dart';
import '../../../services/app_auth_service.dart';
import '../../../services/caregiver_session_service.dart';
import '../../../services/patient_session_service.dart';
import '../../../services/patient_registry_service.dart';

/// Caregiver Onboarding Flow — 3 Steps
/// Step 1: Caregiver Info (from Stitch: "Welcome, Caregiver.")
/// Step 2: Patient Setup (from Stitch: "Patient Setup — Help us personalize")
/// Step 3: Safety & Sync (from Stitch: "Safety & Sync — Establish the safety net")
class CaregiverOnboardingFlow extends StatefulWidget {
  const CaregiverOnboardingFlow({super.key});

  @override
  State<CaregiverOnboardingFlow> createState() =>
      _CaregiverOnboardingFlowState();
}

class _CaregiverOnboardingFlowState extends State<CaregiverOnboardingFlow> {
  int _currentStep = 0;
  final PageController _pageController = PageController();
  bool _seededRouteDefaults = false;
  bool _isSubmitting = false;

  final TextEditingController _caregiverNameController = TextEditingController();
  final TextEditingController _caregiverRelationshipController =
      TextEditingController();
  final TextEditingController _caregiverPhoneController =
      TextEditingController();
  final TextEditingController _caregiverEmailController =
      TextEditingController();
  final TextEditingController _caregiverPasswordController =
      TextEditingController();
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _patientAgeController = TextEditingController();
  final TextEditingController _conditionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _emergencyPhoneController =
      TextEditingController();
  final _caregiverSessionService = CaregiverSessionService();
  final _patientSessionService = PatientSessionService();

  @override
  void dispose() {
    _pageController.dispose();
    _caregiverNameController.dispose();
    _caregiverRelationshipController.dispose();
    _caregiverPhoneController.dispose();
    _caregiverEmailController.dispose();
    _caregiverPasswordController.dispose();
    _patientNameController.dispose();
    _patientAgeController.dispose();
    _conditionController.dispose();
    _locationController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seededRouteDefaults) return;
    _seededRouteDefaults = true;
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is Map) {
      _caregiverEmailController.text =
          routeArgs['caregiverEmail']?.toString().trim() ?? '';
      _caregiverPasswordController.text =
          routeArgs['caregiverPassword']?.toString().trim() ?? '';
      _caregiverNameController.text =
          routeArgs['caregiverName']?.toString().trim() ?? '';
    }
  }

  Future<void> _nextStep() async {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      final caregiverName = _caregiverNameController.text.trim();
      final caregiverEmail = _caregiverEmailController.text.trim();
      final caregiverPassword = _caregiverPasswordController.text.trim();
      final patientName = _patientNameController.text.trim();
      if (caregiverName.isEmpty) {
        _showMessage('Please enter the caregiver name.');
        return;
      }
      if (caregiverEmail.isEmpty) {
        _showMessage('Please enter the caregiver email.');
        return;
      }
      if (caregiverPassword.isEmpty || caregiverPassword.length < 6) {
        _showMessage('Please enter a password with at least 6 characters.');
        return;
      }
      if (patientName.isEmpty) {
        _showMessage('Please enter the patient name.');
        return;
      }

      setState(() => _isSubmitting = true);
      try {
      final String generatedId = 'PT-${1000 + Random().nextInt(9000)}';
      final String accessCode =
          'PT-${1000 + Random().nextInt(9000)}-${10 + Random().nextInt(89)}';
      final String doctorInviteCode =
          'DR-${1000 + Random().nextInt(9000)}-${100 + Random().nextInt(899)}';
      final routeArgs = ModalRoute.of(context)?.settings.arguments;
      final resolvedCaregiverEmailInput =
          _caregiverEmailController.text.trim().isNotEmpty
          ? _caregiverEmailController.text.trim()
          : routeArgs is Map
              ? routeArgs['caregiverEmail']?.toString().trim()
              : null;
      final resolvedCaregiverPasswordInput =
          _caregiverPasswordController.text.trim().isNotEmpty
          ? _caregiverPasswordController.text.trim()
          : routeArgs is Map
              ? routeArgs['caregiverPassword']?.toString().trim()
              : null;
      final caregiverUid = routeArgs is Map
          ? routeArgs['caregiverUid']?.toString().trim()
          : null;
      final caregiverNameFromArgs = routeArgs is Map
          ? routeArgs['caregiverName']?.toString().trim()
          : null;
      final authService = context.read<AppAuthService>();
      final registryService = context.read<PatientRegistryService>();

      String resolvedCaregiverUid = caregiverUid ?? '';
      String resolvedCaregiverName = caregiverNameFromArgs?.isNotEmpty == true
          ? caregiverNameFromArgs!
          : caregiverName;
      String resolvedCaregiverEmail = resolvedCaregiverEmailInput ?? '';
      final patientAge = int.tryParse(_patientAgeController.text.trim()) ?? 78;
      final caregiverRelationship = _caregiverRelationshipController.text
          .trim();

      if (resolvedCaregiverUid.isEmpty && resolvedCaregiverEmail.isNotEmpty) {
        final authProfile = await authService.registerCaregiver(
          email: resolvedCaregiverEmail,
          password: resolvedCaregiverPasswordInput?.isNotEmpty == true
              ? resolvedCaregiverPasswordInput!
              : 'CareOS@12345',
          displayName: resolvedCaregiverName,
        );
        resolvedCaregiverUid = authProfile.uid;
        resolvedCaregiverName = authProfile.displayName;
        resolvedCaregiverEmail = authProfile.email;
      }

      final sessionArgs = {
        'caregiverId': resolvedCaregiverUid.isNotEmpty
            ? resolvedCaregiverUid
            : 'cg_${_caregiverNameController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
        'caregiverName': resolvedCaregiverName,
        'caregiverEmail': resolvedCaregiverEmail,
        'patientName': patientName,
        'condition': _conditionController.text,
        'location': _locationController.text,
        'patientId': generatedId,
        'patientAccessCode': accessCode,
        'emergencyPhone': _emergencyPhoneController.text.trim(),
        'doctorInviteCode': doctorInviteCode,
        'patientAge': patientAge,
      };
      final linkedProfile = PatientProfile.initial(
        patientId: generatedId,
        accessCode: accessCode,
        displayName: patientName,
        age: patientAge,
      ).copyWith(
        homeLabel: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : 'Home',
        caregiverName: _caregiverNameController.text.trim().isNotEmpty
            ? _caregiverNameController.text.trim()
            : 'Caregiver',
        caregiverRelationship:
            caregiverRelationship.isNotEmpty ? caregiverRelationship : 'caregiver',
        lastKnownContextSummary:
            'Your caregiver prepared support for you at ${_locationController.text.trim().isNotEmpty ? _locationController.text.trim() : 'home'}.',
      );
      if (resolvedCaregiverUid.isNotEmpty) {
        await registryService.createPatientRegistryRecord(
          PatientRegistryRecord(
            patientId: generatedId,
            accessCode: accessCode,
            doctorInviteCode: doctorInviteCode,
            patientName: patientName,
            patientAge: patientAge,
            condition: _conditionController.text.trim().isNotEmpty
                ? _conditionController.text.trim()
                : 'Care plan pending',
            homeLocation: _locationController.text.trim().isNotEmpty
                ? _locationController.text.trim()
                : 'Home',
            emergencyPhone: _emergencyPhoneController.text.trim(),
            caregiverUid: resolvedCaregiverUid,
            caregiverName: resolvedCaregiverName,
            caregiverEmail: resolvedCaregiverEmail,
            doctorUids: const [],
            createdAt: DateTime.now(),
          ),
        );
        final currentProfile = await authService.getCurrentProfile();
        if (currentProfile != null) {
          await authService.updateLinkedPatients(
            uid: currentProfile.uid,
            linkedPatientIds: {
              ...currentProfile.linkedPatientIds,
              generatedId,
            }.toList(),
            activePatientId: generatedId,
          );
        }
      }

      await _caregiverSessionService.saveSession(
        CaregiverSession.fromRouteArguments(sessionArgs),
      );
      await _patientSessionService.saveLinkedProfile(linkedProfile);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Access Codes Ready'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patient access code: $accessCode'),
              const SizedBox(height: 8),
              Text('Doctor invite code: $doctorInviteCode'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.caregiverDashboard,
        arguments: sessionArgs,
      );
      } catch (error) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        _showMessage(
          error is Exception
              ? error.toString().replaceFirst('Exception: ', '')
              : 'Caregiver setup failed. Please try again.',
        );
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _showInviteDoctorPreview() async {
    final previewCode =
        'DR-${1000 + Random().nextInt(9000)}-${100 + Random().nextInt(899)}';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Invite Doctor'),
        content: Text(
          'Finish caregiver setup first. CareOS will then generate a doctor invite code like $previewCode for the linked doctor account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Okay'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _previousStep,
                    icon: const Icon(Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Step ${_currentStep + 1} of 3',
                    style: textTheme.titleSmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Progress Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _StepProgressBar(currentStep: _currentStep),
            ),

            const SizedBox(height: 24),

            // ── Step Content ──
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _CaregiverInfoStep(
                    textTheme: textTheme,
                    nameController: _caregiverNameController,
                    relationshipController: _caregiverRelationshipController,
                    phoneController: _caregiverPhoneController,
                    emailController: _caregiverEmailController,
                    passwordController: _caregiverPasswordController,
                  ),
                  _PatientSetupStep(
                    textTheme: textTheme,
                    patientNameController: _patientNameController,
                    patientAgeController: _patientAgeController,
                    conditionController: _conditionController,
                  ),
                  _SafetySyncStep(
                    textTheme: textTheme,
                    locationController: _locationController,
                    emergencyPhoneController: _emergencyPhoneController,
                    onInviteDoctorTap: _showInviteDoctorPreview,
                  ),
                ],
              ),
            ),

            // ── Bottom Button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
              child: GradientButton(
                text: _isSubmitting
                    ? 'Please wait...'
                    : (_currentStep == 2 ? 'Finish Setup' : 'Continue'),
                icon: _currentStep == 2
                    ? Icons.check_rounded
                    : Icons.arrow_forward_rounded,
                onPressed: _isSubmitting ? null : _nextStep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Progress Bar ──
class _StepProgressBar extends StatelessWidget {
  final int currentStep;
  const _StepProgressBar({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (index) {
        final isActive = index <= currentStep;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary
                  : AppColors.outlineVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

// ── Step 1: Caregiver Info ──
class _CaregiverInfoStep extends StatelessWidget {
  final TextTheme textTheme;
  final TextEditingController nameController;
  final TextEditingController relationshipController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  
  const _CaregiverInfoStep({
    required this.textTheme,
    required this.nameController,
    required this.relationshipController,
    required this.phoneController,
    required this.emailController,
    required this.passwordController,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Welcome, Caregiver.',
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Let\'s begin by gathering your details to personalize the care path.',
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // Security notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 18, color: AppColors.primary.withValues(alpha: 0.7)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your information is securely encrypted and only shared with your care team.',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Form Fields
          CustomTextField(
            label: 'Full Name',
            controller: nameController,
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Relationship to Patient',
            controller: relationshipController,
            prefixIcon: Icon(Icons.people_outline_rounded, size: 20),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Phone Number',
            controller: phoneController,
            keyboardType: TextInputType.phone,
            prefixIcon: Icon(Icons.phone_outlined, size: 20),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Email',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icon(Icons.email_outlined, size: 20),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Password',
            controller: passwordController,
            obscureText: true,
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
          ),

          const SizedBox(height: 28),

          // Why we ask
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      'Why we ask',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Knowing your role helps us tailor notifications and specialized guides for your specific care journey.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Step 2: Patient Setup ──
class _PatientSetupStep extends StatelessWidget {
  final TextTheme textTheme;
  final TextEditingController patientNameController;
  final TextEditingController patientAgeController;
  final TextEditingController conditionController;

  const _PatientSetupStep({
    required this.textTheme,
    required this.patientNameController,
    required this.patientAgeController,
    required this.conditionController,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Patient Setup',
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Help us personalize the care experience.',
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // Info card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.psychology_outlined,
                    size: 18,
                    color: AppColors.secondary.withValues(alpha: 0.7)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Setting the cognitive stage helps us adjust the daily activity recommendations and visual complexity for your loved one.',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Form Fields
          CustomTextField(
            label: 'Patient Name',
            controller: patientNameController,
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Age',
            controller: patientAgeController,
            keyboardType: TextInputType.number,
            prefixIcon: Icon(Icons.cake_outlined, size: 20),
          ),
          const SizedBox(height: 16),
          const CustomTextField(
            label: 'Date of Birth',
            prefixIcon: Icon(Icons.calendar_today_outlined, size: 20),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Condition / Stage',
            controller: conditionController,
            prefixIcon: const Icon(Icons.medical_information_outlined, size: 20),
          ),
          const SizedBox(height: 16),
          const CustomTextField(
            label: 'Primary Language',
            prefixIcon: Icon(Icons.language_outlined, size: 20),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Step 3: Safety & Sync ──
class _SafetySyncStep extends StatelessWidget {
  final TextTheme textTheme;
  final TextEditingController locationController;
  final TextEditingController emergencyPhoneController;
  final VoidCallback onInviteDoctorTap;

  const _SafetySyncStep({
    required this.textTheme,
    required this.locationController,
    required this.emergencyPhoneController,
    required this.onInviteDoctorTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Safety & Sync',
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Establish the safety net for your loved one. These details help us provide proactive support when it\'s needed most.',
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // Form Fields
          CustomTextField(
            label: 'Emergency Phone Number',
            controller: emergencyPhoneController,
            keyboardType: TextInputType.phone,
            prefixIcon: const Icon(Icons.emergency_outlined, size: 20),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Home Location',
            controller: locationController,
            prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
          ),

          const SizedBox(height: 28),

          // Optional Connectivity
          Text(
            'Optional Connectivity',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Memory Cues
          _OptionalConnectCard(
            icon: Icons.photo_library_outlined,
            title: 'Add Memory Cues',
            subtitle: 'Voice memos or familiar photos.',
            onTap: () {},
          ),
          const SizedBox(height: 12),

          // Invite Doctor
          _OptionalConnectCard(
            icon: Icons.share_outlined,
            title: 'Invite Doctor',
            subtitle: 'Share logs and progress reports.',
            onTap: onInviteDoctorTap,
          ),

          const SizedBox(height: 28),

          // Quote
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '"Small acts of preparation today create peace of mind for tomorrow."',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Agreement
          Text(
            'By finishing, you agree to our Caregiver Guidelines and Privacy Policy.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Optional Connectivity Card ──
class _OptionalConnectCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionalConnectCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.add_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
