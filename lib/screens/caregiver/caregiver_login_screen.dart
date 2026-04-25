import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../routes/app_routes.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/gradient_button.dart';

/// Caregiver Login Screen
/// From Stitch: "Kindred Path — Compassionate care coordination"
/// Caregiver Login with email/password, login button, create account option.
/// Quote: "Guiding families through every step of the journey."
class CaregiverLoginScreen extends StatelessWidget {
  const CaregiverLoginScreen({super.key});

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

                // ── Back Button ──
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

                // ── Brand Logo ──
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

                // ── Brand Name ──
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

                // ── Section Title ──
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

                // ── Form Fields ──
                const CustomTextField(
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                ),
                const SizedBox(height: 16),
                const CustomTextField(
                  label: 'Password',
                  obscureText: true,
                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                ),

                const SizedBox(height: 32),

                // ── Login Button ──
                GradientButton(
                  text: 'Login',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.caregiverOnboarding);
                  },
                ),
                const SizedBox(height: 16),

                // ── Create Account ──
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.caregiverOnboarding);
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
