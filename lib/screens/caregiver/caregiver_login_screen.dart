import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/caregiver_session.dart';
import '../../routes/app_routes.dart';
import '../../services/app_auth_service.dart';
import '../../services/caregiver_session_service.dart';
import '../../services/patient_registry_service.dart';
import '../../services/patient_session_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/gradient_button.dart';

class CaregiverLoginScreen extends StatefulWidget {
  const CaregiverLoginScreen({super.key});

  @override
  State<CaregiverLoginScreen> createState() => _CaregiverLoginScreenState();
}

class _CaregiverLoginScreenState extends State<CaregiverLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _sessionService = CaregiverSessionService();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your caregiver email.')),
      );
      return;
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final authService = context.read<AppAuthService>();
      final registryService = context.read<PatientRegistryService>();
      final patientSessionService = context.read<PatientSessionService>();
      final profile = await authService.signInCaregiver(
        email: email,
        password: password,
      );
      final linkedPatients = await registryService.getForCaregiver(profile.uid);
      if (linkedPatients.isEmpty) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        Navigator.pushNamed(
          context,
          AppRoutes.caregiverOnboarding,
          arguments: {
            'caregiverEmail': email,
            'caregiverPassword': password,
            'caregiverUid': profile.uid,
            'caregiverName': profile.displayName,
          },
        );
        return;
      }

      for (final patient in linkedPatients) {
        await patientSessionService.saveLinkedProfile(patient.toPatientProfile());
      }
      final primaryPatient = linkedPatients.first;
      final session = CaregiverSession(
        caregiverId: profile.uid,
        caregiverName: profile.displayName,
        caregiverEmail: profile.email,
        patientId: primaryPatient.patientId,
        patientAccessCode: primaryPatient.accessCode,
        patientName: primaryPatient.patientName,
        patientAge: primaryPatient.patientAge,
        condition: primaryPatient.condition,
        location: primaryPatient.homeLocation,
        emergencyPhone: primaryPatient.emergencyPhone,
        doctorInviteCode: primaryPatient.doctorInviteCode,
      );
      await _sessionService.saveSession(session);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.caregiverDashboard,
        arguments: session.toMap(),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.pushNamed(
        context,
        AppRoutes.caregiverOnboarding,
        arguments: {
          'caregiverEmail': email,
          'caregiverPassword': password,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
                const SizedBox(height: 32),
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: AppColors.secondary,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Kindred Path',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Compassionate care coordination',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Caregiver Login',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '"Guiding families through every\nstep of the journey."',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),
                CustomTextField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Password',
                  controller: _passwordController,
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                ),
                const SizedBox(height: 32),
                GradientButton(
                  text: _isSubmitting ? 'Checking...' : 'Login',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _isSubmitting ? null : _handleLogin,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.caregiverOnboarding,
                        arguments: {
                          'caregiverEmail': _emailController.text.trim(),
                          'caregiverPassword': _passwordController.text.trim(),
                        },
                      );
                    },
                    child: RichText(
                      text: TextSpan(
                        text: 'New here? ',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        children: [
                          TextSpan(
                            text: 'Create Account',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
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
