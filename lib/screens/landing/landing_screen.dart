import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../routes/app_routes.dart';

/// Landing Page — Role Selection
/// From Stitch: "CareOS - Designed for Cognitive Clarity and Emotional Peace"
/// Three role cards: Patient, Caregiver, Doctor
/// Below: "How CareOS Works" section with Connect, Monitor, Support
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Hero Section ──
              _buildHeroSection(context, textTheme),

              const SizedBox(height: 40),

              // ── Role Selection ──
              _buildRoleSelectionSection(context, textTheme),

              const SizedBox(height: 56),

              // ── How CareOS Works ──
              _buildHowItWorksSection(context, textTheme),

              const SizedBox(height: 56),

              // ── Footer ──
              _buildFooterSection(context, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryContainer.withValues(alpha: 0.3),
            AppColors.surface,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: AppColors.onPrimary,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'CareOS',
            style: textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),

          // Subtitle
          Text(
            'Designed for Cognitive Clarity\nand Emotional Peace.',
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'CareOS is more than an app; it\'s a digital sanctuary built to simplify care, preserve memories, and bridge the gap between loved ones and healthcare professionals.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelectionSection(BuildContext context, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            'Who is using CareOS today?',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your path to access your personalized dashboard.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),

          // Patient Card
          _RoleCard(
            title: 'Patient',
            subtitle: 'I am here for my daily journal,\nmeds, and memories.',
            icon: Icons.person_rounded,
            backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.3),
            iconColor: AppColors.primary,
            onTap: () => Navigator.pushNamed(context, AppRoutes.patientAccess),
          ),
          const SizedBox(height: 16),

          // Caregiver Card
          _RoleCard(
            title: 'Caregiver',
            subtitle: 'I am supporting a loved one and\nmanaging their schedule.',
            icon: Icons.favorite_rounded,
            backgroundColor: AppColors.secondaryContainer.withValues(alpha: 0.3),
            iconColor: AppColors.secondary,
            onTap: () => Navigator.pushNamed(context, AppRoutes.caregiverLogin),
          ),
          const SizedBox(height: 16),

          // Doctor Card
          _RoleCard(
            title: 'Doctor',
            subtitle: 'I am a medical professional reviewing\npatient clinical data.',
            icon: Icons.medical_services_rounded,
            backgroundColor: AppColors.tertiaryContainer.withValues(alpha: 0.3),
            iconColor: AppColors.tertiary,
            onTap: () => Navigator.pushNamed(context, AppRoutes.doctorLogin),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksSection(BuildContext context, TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      color: AppColors.surfaceContainerLow,
      child: Column(
        children: [
          Text(
            'How CareOS Works',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 32),

          _HowItWorksItem(
            icon: Icons.link_rounded,
            title: 'Connect',
            description:
                'Link patients with their dedicated care circle and healthcare providers in one unified platform.',
            color: AppColors.primaryContainer,
          ),
          const SizedBox(height: 20),

          _HowItWorksItem(
            icon: Icons.monitor_heart_rounded,
            title: 'Monitor',
            description:
                'Track medication adherence, mood trends, and cognitive health markers with simple, low-friction tools.',
            color: AppColors.secondaryContainer,
          ),
          const SizedBox(height: 20),

          _HowItWorksItem(
            icon: Icons.support_agent_rounded,
            title: 'Support',
            description:
                'Receive real-time insights and proactive alerts, ensuring support is always there when it\'s needed most.',
            color: AppColors.tertiaryContainer,
          ),
        ],
      ),
    );
  }

  Widget _buildFooterSection(BuildContext context, TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: AppColors.surfaceContainer,
      child: Column(
        children: [
          // Logo
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.favorite_rounded,
                    color: AppColors.onPrimary, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'CareOS',
                style: textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Bringing clarity and peace to\nlong-term care management.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Contact info
          Text(
            'support@careos.com',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '1-800-CARE-SOS',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Role Selection Card ──
class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 24, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── How It Works Item ──
class _HowItWorksItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _HowItWorksItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: AppColors.onSurface),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
