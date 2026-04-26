import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../routes/app_routes.dart';

/// Caregiver Dashboard — Full Implementation
class CaregiverDashboardScreen extends StatelessWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Extract arguments if passed from onboarding/login
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};

    // Fallback dummy data if no arguments provided
    final String caregiverName =
        args['caregiverName']?.toString().isNotEmpty == true
        ? args['caregiverName']
        : 'Caregiver';
    final String patientName =
        args['patientName']?.toString().isNotEmpty == true
        ? args['patientName']
        : 'Alex Johnson';
    final String condition = args['condition']?.toString().isNotEmpty == true
        ? args['condition']
        : 'Memory Care Patient';
    final String homeLocation = args['location']?.toString().isNotEmpty == true
        ? args['location']
        : 'Home 1';
    final String patientId = args['patientId']?.toString().isNotEmpty == true
        ? args['patientId']
        : 'PT-8429';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Hi, $caregiverName',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        backgroundColor: AppColors.surface.withValues(alpha: 0.8),
        scrolledUnderElevation: 0,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.landing,
                (route) => false,
              );
            },
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.onSurfaceVariant,
            ),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header / Patient Summary
              _PatientHeaderCard(
                patientName: patientName,
                condition: condition,
                location: homeLocation,
                textTheme: textTheme,
              ),
              const SizedBox(height: 16),

              // Patient Login ID Card
              _PatientLoginIdCard(patientId: patientId),
              const SizedBox(height: 24),

              // Metrics Row
              _MetricsRow(textTheme: textTheme),
              const SizedBox(height: 32),

              // Active Alerts
              Text(
                'Active Alerts',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              const _AlertCard(
                title: 'Left Safe Zone',
                description: 'Location: Backyard Perimeter',
                icon: Icons.directions_walk_rounded,
              ),
              const SizedBox(height: 12),
              const _AlertCard(
                title: 'Missed Medication',
                description: 'Donepezil 10mg (Evening dose)',
                icon: Icons.medication_rounded,
              ),
              const SizedBox(height: 32),

              // Daily Insights
              Text(
                'Daily Insights',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              const _InsightCard(
                value: '2',
                label: 'Confusion Count',
                subtitle: 'Moderate',
                subLabel: 'Activity Level',
              ),
              const SizedBox(height: 12),
              const _InsightCard(
                value: 'Medication',
                label: 'Status',
                subtitle: 'Next: 9:00 PM',
                subLabel: '',
              ),
              const SizedBox(height: 32),

              // Quick Actions
              Text(
                'Quick Actions',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: const [
                  _QuickActionButton(
                    title: 'Status',
                    icon: Icons.analytics_outlined,
                    isPrimary: true,
                  ),
                  _QuickActionButton(
                    title: 'Alerts',
                    icon: Icons.notifications_active_outlined,
                    isPrimary: false,
                  ),
                  _QuickActionButton(
                    title: 'History',
                    icon: Icons.event_note_outlined,
                    isPrimary: false,
                  ),
                  _QuickActionButton(
                    title: 'Profile',
                    icon: Icons.person_outline_rounded,
                    isPrimary: false,
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientHeaderCard extends StatelessWidget {
  final String patientName;
  final String condition;
  final String location;
  final TextTheme textTheme;

  const _PatientHeaderCard({
    required this.patientName,
    required this.condition,
    required this.location,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            patientName,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                condition,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '•',
                  style: TextStyle(color: AppColors.outlineVariant),
                ),
              ),
              Text(
                location,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  final TextTheme textTheme;
  const _MetricsRow({required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricItem(
            value: '72',
            unit: 'bpm',
            label: 'Heart Rate',
            color: AppColors.secondaryContainer,
            textColor: AppColors.onSecondaryContainer,
            textTheme: textTheme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricItem(
            value: '1,402',
            unit: '',
            label: 'Steps Today',
            color: AppColors.primaryContainer,
            textColor: AppColors.onPrimaryContainer,
            textTheme: textTheme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricItem(
            value: 'Good',
            unit: '',
            label: 'Sleep Quality',
            color: AppColors.tertiaryContainer,
            textColor: AppColors.onTertiaryContainer,
            textTheme: textTheme,
          ),
        ),
      ],
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final Color color;
  final Color textColor;
  final TextTheme textTheme;

  const _MetricItem({
    required this.value,
    required this.unit,
    required this.label,
    required this.color,
    required this.textColor,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: textTheme.bodySmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _AlertCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.errorContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.onErrorContainer, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.onErrorContainer.withValues(alpha: 0.8),
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

class _InsightCard extends StatelessWidget {
  final String value;
  final String label;
  final String subtitle;
  final String subLabel;

  const _InsightCard({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                subtitle,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              if (subLabel.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subLabel,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isPrimary;

  const _QuickActionButton({
    required this.title,
    required this.icon,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: isPrimary ? AppColors.primaryGradient : null,
            color: isPrimary ? null : AppColors.surfaceContainerLowest,
            border: isPrimary
                ? null
                : Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.15),
                    width: 1,
                  ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: isPrimary ? AppColors.onPrimary : AppColors.primary,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? AppColors.onPrimary : AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientLoginIdCard extends StatelessWidget {
  final String patientId;

  const _PatientLoginIdCard({required this.patientId});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.badge_outlined,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patient Login ID',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use this ID on the patient device',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            patientId,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
