import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../routes/app_routes.dart';
import '../../services/app_auth_service.dart';
import '../../services/patient_registry_service.dart';
import '../../services/patient_session_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/gradient_button.dart';

class DoctorLoginScreen extends StatefulWidget {
  const DoctorLoginScreen({super.key});

  @override
  State<DoctorLoginScreen> createState() => _DoctorLoginScreenState();
}

class _DoctorLoginScreenState extends State<DoctorLoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  bool _isSubmitting = false;
  bool _isRegisterMode = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter your email and password.');
      return;
    }
    if (_isRegisterMode &&
        (_nameController.text.trim().isEmpty ||
            _inviteCodeController.text.trim().isEmpty)) {
      _showMessage('Doctor registration needs your name and invite code.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final authService = context.read<AppAuthService>();
      final registryService = context.read<PatientRegistryService>();
      final patientSessionService = context.read<PatientSessionService>();

      final profile = _isRegisterMode
          ? await authService.registerDoctor(
              email: email,
              password: password,
              displayName: _nameController.text.trim(),
              doctorInviteCode: _inviteCodeController.text.trim(),
            )
          : await authService.signInDoctor(email: email, password: password);

      var linkedPatients = await registryService.getForDoctor(profile.uid);
      if (linkedPatients.isEmpty && profile.linkedPatientIds.isNotEmpty) {
        linkedPatients = await registryService.getByPatientIds(
          profile.linkedPatientIds,
        );
      }
      for (final patient in linkedPatients) {
        await patientSessionService.saveLinkedProfile(patient.toPatientProfile());
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.pushReplacementNamed(context, AppRoutes.doctorDashboard);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showMessage(
        error is Exception ? error.toString().replaceFirst('Exception: ', '') : 'Doctor sign-in failed.',
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
                const SizedBox(height: 40),
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.tertiaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.medical_services_rounded,
                      color: AppColors.tertiary,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _isRegisterMode ? 'Doctor Registration' : 'Doctor Login',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isRegisterMode
                      ? 'Create a doctor account using the caregiver-generated invite code.'
                      : 'Enter your credentials to access linked patient insights.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                if (_isRegisterMode) ...[
                  CustomTextField(
                    label: 'Doctor Name',
                    controller: _nameController,
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                  ),
                  const SizedBox(height: 16),
                ],
                CustomTextField(
                  label: 'Professional Email',
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
                if (_isRegisterMode) ...[
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Doctor Invite Code',
                    controller: _inviteCodeController,
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                  ),
                ],
                const SizedBox(height: 24),
                GradientButton(
                  text: _isSubmitting
                      ? 'Please wait...'
                      : (_isRegisterMode ? 'Create Doctor Account' : 'Login'),
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _isSubmitting ? null : _submit,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() => _isRegisterMode = !_isRegisterMode);
                    },
                    child: Text(
                      _isRegisterMode
                          ? 'Already registered? Sign in'
                          : 'Need a doctor account? Register here',
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
