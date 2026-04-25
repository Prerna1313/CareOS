import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/confusion_state.dart';
import '../../../models/reminder.dart';
import '../../../models/reminder_log.dart';
import '../../../providers/memory_provider.dart';
import '../../../providers/my_day_provider.dart';
import '../../../providers/patient_session_provider.dart';
import '../../../providers/recognition_provider.dart';
import '../../../providers/reminder_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../services/camera_event_service.dart';
import '../../../services/patient_records_service.dart';
import '../../../services/voice_orientation_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/calming_popup.dart';
import '../../../widgets/reminder_popup.dart';
import '../camera/camera_live_screen.dart';
import '../memories/memories_page.dart';
import '../my_day/my_day_chat_overlay.dart';
import '../my_day/my_day_main_page.dart';
import '../recognition/recognition_activity_screen.dart';
import '../sos/sos_emergency_screen.dart';

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  int _currentIndex = 0;
  String? _lastAutoSupportSignature;

  Future<void> _setTab(int index) async {
    setState(() => _currentIndex = index);

    final activityLabel = switch (index) {
      0 => 'Reviewing home dashboard',
      1 => 'Completing My Day check-in',
      _ => 'Browsing memory library',
    };

    await context.read<PatientSessionProvider>().touchActivity(activityLabel);
  }

  void _maybeTriggerAutoSupport() {
    final session = context.read<PatientSessionProvider>();
    final profile = session.profile;
    if (profile == null || !profile.autoOrientationEnabled) return;

    final reminderState = context
        .read<ReminderProvider>()
        .currentConfusionState;
    final behaviorInsights = context
        .read<PatientRecordsService>()
        .buildBehaviorInsights();
    final shouldSupport =
        reminderState.level == ConfusionLevel.high ||
        reminderState.level == ConfusionLevel.mild ||
        (behaviorInsights['shouldAutoSupport'] as bool? ?? false);

    if (!shouldSupport) {
      _lastAutoSupportSignature = null;
      return;
    }

    final signature =
        '${reminderState.level.name}-${behaviorInsights['riskLevel']}';
    if (_lastAutoSupportSignature == signature) return;
    _lastAutoSupportSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<PatientRecordsService>().logIntervention(
        patientId: profile.patientId,
        triggerType: 'auto_support',
        interventionType: 'orientation_prompt',
        outcome: 'shown',
        notes:
            'Auto orientation support was suggested from confusion or observation behavior signals.',
      );
      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.patientOrientationSupport);
    });
  }

  @override
  Widget build(BuildContext context) {
    final patientSession = context.watch<PatientSessionProvider>();
    if (!patientSession.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!patientSession.hasActiveSession) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_person_rounded, size: 56),
                const SizedBox(height: 16),
                Text(
                  'Patient access required',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please return to the patient access screen and enter the patient ID or access code first.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_currentIndex == 0) {
      _maybeTriggerAutoSupport();
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          body: IndexedStack(
            index: _currentIndex,
            children: [
              PatientHomeScreen(onSwitchTab: _setTab),
              const PatientMyDayWrapper(),
              const MemoriesPage(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _setTab,
            backgroundColor: AppColors.surfaceBright,
            indicatorColor: AppColors.primaryContainer,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.house_outlined),
                selectedIcon: Icon(Icons.house_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today_rounded),
                label: 'My Day',
              ),
              NavigationDestination(
                icon: Icon(Icons.photo_library_outlined),
                selectedIcon: Icon(Icons.photo_library_rounded),
                label: 'Memories',
              ),
            ],
          ),
        ),

        Consumer<MyDayProvider>(
          builder: (context, provider, child) {
            if (_currentIndex == 1 && provider.isOverlayVisible) {
              return const MyDayChatOverlay();
            }
            return const SizedBox.shrink();
          },
        ),

        if (context.watch<ReminderProvider>().currentReminder != null)
          Positioned.fill(
            child: Consumer<ReminderProvider>(
              builder: (context, provider, child) {
                if (provider.currentReminder == null) {
                  return const SizedBox.shrink();
                }
                return ReminderPopup(
                  reminder: provider.currentReminder!,
                  onDone: () => provider.handleResponse(ReminderAction.done),
                  onRemindLater: () =>
                      provider.handleResponse(ReminderAction.remindLater),
                  onIgnore: () =>
                      provider.handleResponse(ReminderAction.ignore),
                );
              },
            ),
          ),

        if (context.watch<ReminderProvider>().currentConfusionState.level ==
            ConfusionLevel.high)
          Positioned.fill(
            child: Consumer<ReminderProvider>(
              builder: (context, provider, child) {
                if (provider.currentConfusionState.level !=
                    ConfusionLevel.high) {
                  return const SizedBox.shrink();
                }
                return Material(
                  color: Colors.black54,
                  child: CalmingPopup(
                    onDismiss: () {
                      final profile = context
                          .read<PatientSessionProvider>()
                          .profile;
                      if (profile != null) {
                        context.read<PatientRecordsService>().logIntervention(
                          patientId: profile.patientId,
                          triggerType: 'confusion_detected',
                          interventionType: 'confusion_popup',
                          outcome: 'dismissed',
                          notes:
                              'The patient dismissed the calming orientation popup.',
                        );
                      }
                      provider.dismissConfusion();
                    },
                    patientName:
                        context
                            .read<PatientSessionProvider>()
                            .profile
                            ?.displayName ??
                        'Friend',
                    caregiverName:
                        context
                            .read<PatientSessionProvider>()
                            .profile
                            ?.caregiverName ??
                        'Rahul',
                    caregiverRelationship:
                        context
                            .read<PatientSessionProvider>()
                            .profile
                            ?.caregiverRelationship ??
                        'daughter',
                    locationLabel:
                        context
                            .read<PatientSessionProvider>()
                            .profile
                            ?.homeLabel ??
                        'home',
                    familiarPeople: context
                        .read<MemoryProvider>()
                        .memories
                        .where((memory) => memory.type.name == 'person')
                        .take(3)
                        .map((memory) => memory.name)
                        .toList(),
                  ),
                );
              },
            ),
          ),

        if (_currentIndex == 0)
          Positioned(
            bottom: 32,
            right: 24,
            child: FloatingActionButton.large(
              onPressed: () async {
                final sessionProvider = context.read<PatientSessionProvider>();
                final recordsService = context.read<PatientRecordsService>();
                final reminderProvider = context.read<ReminderProvider>();
                final profile = sessionProvider.profile;
                if (profile != null) {
                  await recordsService.logIntervention(
                    patientId: profile.patientId,
                    triggerType: 'manual_help',
                    interventionType: 'orientation_prompt',
                    outcome: 'shown',
                    notes:
                        'The patient requested immediate support from the dashboard.',
                  );
                }
                await sessionProvider.touchActivity(
                  'Requested immediate support',
                  contextSummary:
                      'The patient requested fast reassurance and support.',
                );
                if (!context.mounted) return;
                reminderProvider.triggerMockConfusion();
              },
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.help_rounded, size: 40),
                  Text(
                    'HELP',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class PatientHomeScreen extends StatelessWidget {
  final ValueChanged<int> onSwitchTab;
  const PatientHomeScreen({super.key, required this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OrientationHeader(textTheme: textTheme),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const _MyDayCompletionCard(),
                  const _MemoryMomentSection(),
                  const SizedBox(height: 24),
                  _SmartSupportCard(textTheme: textTheme),
                  const SizedBox(height: 24),
                  const _ContextMemoryCueSection(),
                  const SizedBox(height: 24),
                  _PrimaryActionButtons(
                    textTheme: textTheme,
                    onSwitchTab: onSwitchTab,
                  ),
                  const SizedBox(height: 24),
                  _DailySupportSection(textTheme: textTheme),
                  const SizedBox(height: 24),
                  const _BehaviorInsightSection(),
                  const SizedBox(height: 24),
                  const _WellbeingSection(),
                  const SizedBox(height: 24),
                  const _PassiveSafetySection(),
                  const SizedBox(height: 24),
                  _LightEngagementSection(
                    textTheme: textTheme,
                    onSwitchTab: onSwitchTab,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PatientMyDayWrapper extends StatelessWidget {
  const PatientMyDayWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const MyDayMainPage();
  }
}

class _OrientationHeader extends StatelessWidget {
  final TextTheme textTheme;
  const _OrientationHeader({required this.textTheme});

  String _getSeason() {
    final month = DateTime.now().month;
    if (month >= 3 && month <= 5) return 'Spring';
    if (month >= 6 && month <= 8) return 'Summer';
    if (month >= 9 && month <= 11) return 'Autumn';
    return 'Winter';
  }

  Color _getHeaderColor() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return const Color(0xFFE3F2FD);
    if (hour >= 12 && hour < 17) return const Color(0xFFFFF9C4);
    if (hour >= 17 && hour < 20) return const Color(0xFFFFE0B2);
    return const Color(0xFFE1BEE7);
  }

  _WeatherMood _getWeatherMood() {
    final hour = DateTime.now().hour;
    final season = _getSeason();

    if (hour >= 5 && hour < 11) {
      return const _WeatherMood(
        label: 'Clear',
        accent: Color(0xFF42A5F5),
        background: Color(0xFFE3F2FD),
        icon: Icons.wb_sunny_rounded,
      );
    }

    if (hour >= 11 && hour < 16) {
      return _WeatherMood(
        label: season == 'Summer' ? 'Warm' : 'Bright',
        accent: const Color(0xFFFB8C00),
        background: const Color(0xFFFFF3E0),
        icon: Icons.wb_sunny_rounded,
      );
    }

    if (hour >= 16 && hour < 20) {
      return const _WeatherMood(
        label: 'Calm',
        accent: Color(0xFF8E24AA),
        background: Color(0xFFF3E5F5),
        icon: Icons.wb_twilight_rounded,
      );
    }

    return const _WeatherMood(
      label: 'Cool',
      accent: Color(0xFF5C6BC0),
      background: Color(0xFFE8EAF6),
      icon: Icons.nights_stay_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PatientSessionProvider>().profile;
    final now = DateTime.now();
    final weatherMood = _getWeatherMood();
    final timeStr = DateFormat.jm().format(now);
    final dateStr = DateFormat('EEEE, MMM d').format(now);
    final timeOfDay = _getHeaderColor() == const Color(0xFFE3F2FD)
        ? 'morning'
        : (_getHeaderColor() == const Color(0xFFFFF9C4)
              ? 'afternoon'
              : 'evening');

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      decoration: BoxDecoration(
        color: _getHeaderColor(),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeStr,
                    style: textTheme.displayMedium?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: textTheme.titleLarge?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: weatherMood.background,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: weatherMood.accent.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(weatherMood.icon, color: weatherMood.accent, size: 26),
                    const SizedBox(height: 4),
                    Text(
                      weatherMood.label,
                      style: TextStyle(
                        color: weatherMood.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              IconButton(
                tooltip: 'Patient settings',
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.patientSettings),
                icon: const Icon(Icons.settings_rounded),
              ),
              Expanded(
                child: _StatusChip(
                  icon: Icons.home_rounded,
                  text: profile?.homeLabel ?? 'Home',
                  textTheme: textTheme,
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: 'Play orientation help aloud',
                child: GestureDetector(
                  onTap: () async {
                    if (!(profile?.voicePromptsEnabled ?? true)) return;
                    await context.read<PatientSessionProvider>().touchActivity(
                      'Listening to orientation support',
                      contextSummary: profile?.lastKnownContextSummary,
                    );
                    if (!context.mounted) return;
                    await VoiceOrientationService().speak(
                      VoiceOrientationService().getOrientationPhrase(
                        name: profile?.displayName ?? 'Friend',
                        timeOfDay: timeOfDay,
                        location: profile?.homeLabel ?? 'your home',
                        dateStr: dateStr,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (profile?.voicePromptsEnabled ?? true)
                          ? AppColors.primaryContainer.withValues(alpha: 0.3)
                          : AppColors.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.volume_up_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatusChip(
                  icon: Icons.ac_unit_rounded,
                  text: _getSeason(),
                  textTheme: textTheme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatusChip(
            icon: Icons.person_rounded,
            text: profile == null
                ? 'Caregiver ready'
                : 'With ${profile.caregiverName} (${profile.caregiverRelationship})',
            textTheme: textTheme,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final TextTheme textTheme;

  const _StatusChip({
    required this.icon,
    required this.text,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.onSecondaryContainer, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherMood {
  final String label;
  final Color accent;
  final Color background;
  final IconData icon;

  const _WeatherMood({
    required this.label,
    required this.accent,
    required this.background,
    required this.icon,
  });
}

class _SmartSupportCard extends StatelessWidget {
  final TextTheme textTheme;
  const _SmartSupportCard({required this.textTheme});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PatientSessionProvider>().profile;
    final headline = profile == null
        ? 'You are safe and supported'
        : 'This is ${profile.caregiverName}, your ${profile.caregiverRelationship}';
    final supportLine =
        profile?.lastKnownContextSummary ?? 'You are safe at home.';

    return Container(
      height: 256,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: AppColors.surfaceContainerHigh),
          const Center(
            child: Icon(
              Icons.image_outlined,
              size: 48,
              color: AppColors.outlineVariant,
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black87, Colors.transparent],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  supportLine,
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
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

class _ContextMemoryCueSection extends StatelessWidget {
  const _ContextMemoryCueSection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reminderProvider = context.watch<ReminderProvider>();
    final memories = context.watch<MemoryProvider>().memories;
    final personMemory = memories.where(
      (memory) => memory.type.name == 'person',
    );
    final placeMemory = memories.where((memory) => memory.type.name == 'place');
    final primaryPersonMemory = personMemory.isNotEmpty
        ? personMemory.first
        : null;
    final primaryPlaceMemory = placeMemory.isNotEmpty
        ? placeMemory.first
        : null;

    final shouldShowCue =
        reminderProvider.currentConfusionState.level == ConfusionLevel.high ||
        reminderProvider.currentConfusionState.level == ConfusionLevel.mild ||
        primaryPersonMemory != null ||
        primaryPlaceMemory != null;

    if (!shouldShowCue) {
      return const SizedBox.shrink();
    }

    final cueTitle =
        reminderProvider.currentConfusionState.level == ConfusionLevel.high
        ? 'Helpful Memory Cue'
        : 'Memory Support';

    final cueText = primaryPersonMemory != null
        ? 'This is ${primaryPersonMemory.name}. Take a moment to remember them.'
        : primaryPlaceMemory != null
        ? 'Do you remember this place: ${primaryPlaceMemory.name}?'
        : 'You are safe, and your memories are here to support you.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondaryContainer.withValues(alpha: 0.28),
            AppColors.surfaceContainerLow,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_stories_rounded,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 10),
              Text(
                cueTitle,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            cueText,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.onSurface,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (primaryPersonMemory != null)
                ActionChip(
                  label: Text('Remember ${primaryPersonMemory.name}'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MemoriesPage()),
                  ),
                ),
              if (primaryPlaceMemory != null)
                ActionChip(
                  label: Text('Recall ${primaryPlaceMemory.name}'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MemoriesPage()),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButtons extends StatelessWidget {
  final TextTheme textTheme;
  final ValueChanged<int> onSwitchTab;

  const _PrimaryActionButtons({
    required this.textTheme,
    required this.onSwitchTab,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionButton(
          title: 'Talk',
          subtitle: 'Start your daily check-in',
          icon: Icons.mic_rounded,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          textTheme: textTheme,
          onTap: () {
            context.read<PatientSessionProvider>().touchActivity(
              'Starting My Day check-in',
            );
            context.read<MyDayProvider>().startChat();
            onSwitchTab(1);
          },
        ),
        const SizedBox(height: 16),
        _ActionButton(
          title: 'Memory',
          subtitle: 'Browse your photo memories',
          icon: Icons.photo_library_rounded,
          backgroundColor: AppColors.tertiary,
          foregroundColor: AppColors.onTertiary,
          textTheme: textTheme,
          onTap: () {
            context.read<PatientSessionProvider>().touchActivity(
              'Browsing memory library',
            );
            onSwitchTab(2);
          },
        ),
        const SizedBox(height: 16),
        _ActionButton(
          title: 'Observe',
          subtitle: 'Live environment perception',
          icon: Icons.visibility_rounded,
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.onSecondary,
          textTheme: textTheme,
          onTap: () {
            context.read<PatientSessionProvider>().touchActivity(
              'Observing surroundings',
            );
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CameraLiveScreen()));
          },
        ),
        const SizedBox(height: 16),
        _ActionButton(
          title: 'Help',
          subtitle: 'Call for immediate assistance',
          icon: Icons.emergency_rounded,
          backgroundColor: AppColors.error,
          foregroundColor: AppColors.onError,
          textTheme: textTheme,
          onTap: () {
            context.read<PatientSessionProvider>().touchActivity(
              'Opening SOS support',
              contextSummary:
                  'Emergency assistance flow opened from the patient dashboard.',
            );
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SosEmergencyScreen(),
                fullscreenDialog: true,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final TextTheme textTheme;
  final VoidCallback onTap;

  const _ActionButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.textTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: foregroundColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: foregroundColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.headlineSmall?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: textTheme.bodyMedium?.copyWith(
                      color: foregroundColor.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: foregroundColor.withValues(alpha: 0.5),
              size: 32,
            ),
          ],
        ),
      ),
    );
  }
}

class _DailySupportSection extends StatelessWidget {
  final TextTheme textTheme;
  const _DailySupportSection({required this.textTheme});

  IconData _iconForType(ReminderType type) {
    switch (type) {
      case ReminderType.medicine:
        return Icons.medication_rounded;
      case ReminderType.water:
        return Icons.water_drop_rounded;
      case ReminderType.appointment:
        return Icons.calendar_month_rounded;
      case ReminderType.task:
        return Icons.task_alt_rounded;
    }
  }

  Color _colorForType(ReminderType type) {
    switch (type) {
      case ReminderType.medicine:
        return AppColors.primary;
      case ReminderType.water:
        return const Color(0xFF0288D1);
      case ReminderType.appointment:
        return AppColors.tertiary;
      case ReminderType.task:
        return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reminderProvider = context.watch<ReminderProvider>();
    final current = reminderProvider.currentReminder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => reminderProvider.triggerMockReminder(),
                child: Text(
                  'TASKS FOR TODAY',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/patient/event_history'),
                child: Text(
                  'View Activity',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: current != null
                  ? _TaskCard(
                      title: current.title,
                      icon: _iconForType(current.type),
                      iconColor: _colorForType(current.type),
                      textTheme: textTheme,
                      isLive: true,
                    )
                  : _TaskCard(
                      title: 'Take your medicine',
                      icon: Icons.medication_rounded,
                      iconColor: AppColors.primary,
                      textTheme: textTheme,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TaskCard(
                title: 'Take a short walk',
                icon: Icons.directions_walk_rounded,
                iconColor: AppColors.secondary,
                textTheme: textTheme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _TaskCard(
                title: 'Call a loved one',
                icon: Icons.call_rounded,
                iconColor: AppColors.tertiary,
                textTheme: textTheme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.patientObservationHistory,
                ),
                borderRadius: BorderRadius.circular(16),
                child: _TaskCard(
                  title: 'Review observations',
                  icon: Icons.history_rounded,
                  iconColor: AppColors.secondary,
                  textTheme: textTheme,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: InkWell(
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.patientFindItem),
            borderRadius: BorderRadius.circular(16),
            child: _TaskCard(
              title: 'Find an item',
              icon: Icons.search_rounded,
              iconColor: AppColors.primary,
              textTheme: textTheme,
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final TextTheme textTheme;
  final bool isLive;

  const _TaskCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.textTheme,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLive
            ? iconColor.withValues(alpha: 0.08)
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: isLive
            ? Border.all(color: iconColor.withValues(alpha: 0.3), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 32),
              if (isLive) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _WellbeingSection extends StatelessWidget {
  const _WellbeingSection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final profile = context.watch<PatientSessionProvider>().profile;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wellbeing',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _SupportLine(
            icon: Icons.cake_rounded,
            text:
                'Birthday reminder: ${profile?.caregiverName ?? 'Rahul'}\'s birthday is coming soon.',
          ),
          const SizedBox(height: 10),
          const _SupportLine(
            icon: Icons.groups_rounded,
            text:
                'Gentle social prompt: call a loved one or share a memory today.',
          ),
          const SizedBox(height: 10),
          const _SupportLine(
            icon: Icons.park_rounded,
            text: 'Activity suggestion: step outside for a short, calm walk.',
          ),
        ],
      ),
    );
  }
}

class _BehaviorInsightSection extends StatelessWidget {
  const _BehaviorInsightSection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final insights = context
        .watch<PatientRecordsService>()
        .buildBehaviorInsights();
    final patterns = List<String>.from(insights['patterns'] ?? const []);
    final riskLevel = insights['riskLevel'] as String? ?? 'low';
    final color = switch (riskLevel) {
      'high' => AppColors.error,
      'medium' => const Color(0xFFE67E22),
      _ => AppColors.secondary,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: color),
              const SizedBox(width: 10),
              Text(
                'Support Insights',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insights['headline'] as String? ?? 'Recent patterns look calm.',
            style: textTheme.bodyLarge?.copyWith(height: 1.4),
          ),
          if (patterns.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...patterns.map(
              (pattern) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SupportLine(
                  icon: Icons.circle_notifications_rounded,
                  text: pattern,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.patientOrientationSupport,
            ),
            icon: const Icon(Icons.self_improvement_rounded),
            label: const Text('Open Orientation Support'),
          ),
        ],
      ),
    );
  }
}

class _PassiveSafetySection extends StatelessWidget {
  const _PassiveSafetySection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final observations = context
        .watch<CameraEventService>()
        .getAllEvents()
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Safety Monitor',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.patientObservationHistory,
                ),
                child: const Text('View Observations'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _SupportLine(
            icon: Icons.watch_rounded,
            text:
                'Wearable connection placeholder ready for smartwatch integration.',
          ),
          const SizedBox(height: 10),
          const _SupportLine(
            icon: Icons.location_on_rounded,
            text:
                'Background GPS and safe-zone monitoring can be connected here.',
          ),
          const SizedBox(height: 10),
          _SupportLine(
            icon: Icons.visibility_rounded,
            text: 'Recent observations captured: $observations',
          ),
        ],
      ),
    );
  }
}

class _SupportLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SupportLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _LightEngagementSection extends StatelessWidget {
  final TextTheme textTheme;
  final ValueChanged<int> onSwitchTab;

  const _LightEngagementSection({
    required this.textTheme,
    required this.onSwitchTab,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How are you feeling?',
            style: textTheme.titleLarge?.copyWith(
              color: AppColors.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the mic to start your daily check-in',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.onPrimaryContainer.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tap mic to speak...',
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () {
                  context.read<PatientSessionProvider>().touchActivity(
                    'Using quick check-in prompt',
                  );
                  context.read<MyDayProvider>().startChat();
                  onSwitchTab(1);
                },
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.patientActivities),
              icon: const Icon(Icons.extension_rounded),
              label: const Text('Open Mini Activities'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyDayCompletionCard extends StatelessWidget {
  const _MyDayCompletionCard();

  @override
  Widget build(BuildContext context) {
    final myDayProvider = context.watch<MyDayProvider>();
    final textTheme = Theme.of(context).textTheme;

    if (!myDayProvider.isChatCompleted) return const SizedBox.shrink();
    final summary = myDayProvider.todayEntry?.summary;
    if (summary == null || summary.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFA5D6A7), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Great job today!',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    summary,
                    style: textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF2E7D32),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryMomentSection extends StatelessWidget {
  const _MemoryMomentSection();

  @override
  Widget build(BuildContext context) {
    final recognitionProvider = context.watch<RecognitionProvider>();
    final textTheme = Theme.of(context).textTheme;

    if (recognitionProvider.todayTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final task = recognitionProvider.todayTasks.first;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Memory Moment',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      "Let's remember something special together.",
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.onPrimaryContainer.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                context.read<PatientSessionProvider>().touchActivity(
                  'Completing recognition activity',
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecognitionActivityScreen(task: task),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Start Activity'),
            ),
          ),
        ],
      ),
    );
  }
}
