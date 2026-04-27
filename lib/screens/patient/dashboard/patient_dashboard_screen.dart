import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/camera_event.dart';
import '../../../models/confusion_state.dart';
import '../../../models/interaction_signal.dart';
import '../../../models/reminder.dart';
import '../../../models/reminder_log.dart';
import '../../../providers/memory_provider.dart';
import '../../../providers/my_day_provider.dart';
import '../../../providers/patient_session_provider.dart';
import '../../../providers/recognition_provider.dart';
import '../../../providers/reminder_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../services/camera_event_service.dart';
import '../../../services/interaction_signal_service.dart';
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
import '../recognition/recognition_tasks_page.dart';

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  int _currentIndex = 0;
  String? _lastAutoSupportSignature;
  DateTime? _lastTabChangeAt;
  String? _lastScreenName;
  bool _loggedInitialHomeVisit = false;

  Future<void> _openCompanion() async {
    final sessionProvider = context.read<PatientSessionProvider>();
    final profile = sessionProvider.profile;
    if (profile != null) {
      await context.read<InteractionSignalService>().logSignal(
        InteractionSignal(
          id: 'companion_open_${DateTime.now().microsecondsSinceEpoch}',
          patientId: profile.patientId,
          timestamp: DateTime.now(),
          type: InteractionSignalType.actionStarted,
          screenName: 'sprout_companion',
          summary: 'Sprout companion was opened from the patient dashboard.',
        ),
      );
    }
    await sessionProvider.touchActivity(
      'Talking with Sprout companion',
      contextSummary:
          'The patient opened the guided companion for support.',
    );
    if (!mounted) return;
    final result = await Navigator.pushNamed(context, AppRoutes.patientCompanion);
    if (!mounted) return;
    switch (result) {
      case 'my_day':
        await _setTab(1);
        break;
      case 'memories':
        await _setTab(2);
        break;
      case 'tasks':
        await _setTab(3);
        break;
    }
  }

  Future<void> _triggerQuickHelp() async {
    final sessionProvider = context.read<PatientSessionProvider>();
    final recordsService = context.read<PatientRecordsService>();
    final reminderProvider = context.read<ReminderProvider>();
    final interactionSignalService = context.read<InteractionSignalService>();
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
      await interactionSignalService.logSignal(
        InteractionSignal(
          id: 'manual_help_${DateTime.now().microsecondsSinceEpoch}',
          patientId: profile.patientId,
          timestamp: DateTime.now(),
          type: InteractionSignalType.actionStarted,
          screenName: 'patient_home',
          summary: 'The patient requested immediate support from the dashboard.',
        ),
      );
    }
    await sessionProvider.touchActivity(
      'Requested immediate support',
      contextSummary:
          'The patient requested fast reassurance and support.',
    );
    if (!mounted) return;
    await Navigator.pushNamed(context, AppRoutes.patientOrientationSupport);
    reminderProvider.triggerMockConfusion();
  }

  Future<void> _setTab(int index) async {
    setState(() => _currentIndex = index);
    final sessionProvider = context.read<PatientSessionProvider>();
    final interactionSignalService = context.read<InteractionSignalService>();
    final profile = sessionProvider.profile;
    final screenName = _screenNameForIndex(index);
    final now = DateTime.now();
    if (profile != null) {
      if (_lastTabChangeAt != null &&
          _lastScreenName != null &&
          _lastScreenName != screenName &&
          now.difference(_lastTabChangeAt!).inSeconds <= 8) {
        await interactionSignalService.logSignal(
          InteractionSignal(
            id: 'nav_hesitation_${now.microsecondsSinceEpoch}',
            patientId: profile.patientId,
            timestamp: now,
            type: InteractionSignalType.navigationHesitation,
            screenName: screenName,
            summary:
                'The patient switched quickly from $_lastScreenName to $screenName.',
            metadata: {
              'from': _lastScreenName,
              'to': screenName,
              'secondsSinceLastVisit':
                  now.difference(_lastTabChangeAt!).inSeconds,
            },
          ),
        );
      }

      await interactionSignalService.logSignal(
        InteractionSignal(
          id: 'screen_visit_${screenName}_${now.microsecondsSinceEpoch}',
          patientId: profile.patientId,
          timestamp: now,
          type: InteractionSignalType.screenVisit,
          screenName: screenName,
          summary: 'The patient opened the $screenName screen.',
        ),
      );
    }
    _lastTabChangeAt = now;
    _lastScreenName = screenName;

    final activityLabel = switch (index) {
      0 => 'Reviewing home dashboard',
      1 => 'Completing My Day check-in',
      2 => 'Browsing memory library',
      _ => 'Practicing recognition tasks',
    };

    await sessionProvider.touchActivity(activityLabel);
  }

  String _screenNameForIndex(int index) {
    switch (index) {
      case 0:
        return 'home';
      case 1:
        return 'my_day';
      case 2:
        return 'memories';
      case 3:
        return 'tasks';
      default:
        return 'patient_dashboard';
    }
  }

  void _maybeTriggerAutoSupport() {
    final session = context.read<PatientSessionProvider>();
    final profile = session.profile;
    if (profile == null || !profile.autoOrientationEnabled) return;

    final reminderProvider = context.read<ReminderProvider>();
    final reminderState = reminderProvider.currentConfusionState;
    final recordsService = context.read<PatientRecordsService>();
    final behaviorInsights = recordsService.buildBehaviorInsights();
    final routineDigest = recordsService.buildRoutineDigest(
      patientId: profile.patientId,
      activeReminder: reminderProvider.currentReminder,
    );
    final routineNeedsSupport =
        routineDigest['shouldAutoSupport'] as bool? ?? false;
    final shouldSupport =
        reminderState.level == ConfusionLevel.high ||
        reminderState.level == ConfusionLevel.mild ||
        (behaviorInsights['shouldAutoSupport'] as bool? ?? false) ||
        routineNeedsSupport;

    if (!shouldSupport) {
      _lastAutoSupportSignature = null;
      return;
    }

    final supportType = reminderState.level == ConfusionLevel.high ||
            (behaviorInsights['riskLevel'] as String? ?? 'low') == 'high'
        ? 'orientation'
        : (routineDigest['frictionLevel'] as String? ?? 'low') == 'medium' ||
                (routineDigest['frictionLevel'] as String? ?? 'low') == 'high'
            ? 'routine_prompt'
            : 'orientation';
    final signature =
        '${reminderState.level.name}-${behaviorInsights['riskLevel']}-${routineDigest['frictionLevel']}-${reminderProvider.currentReminder?.id ?? 'none'}';
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
            'Auto support was suggested from confusion, observation, or routine friction signals.',
      );
      if (!mounted) return;
      if (supportType == 'routine_prompt') {
        final suggestion = recordsService.buildContextSupportSuggestion(
          profile: profile,
          confusionState: reminderState,
          activeReminder: reminderProvider.currentReminder,
        );
        _showRoutineSupportPrompt(
          headline: suggestion['headline'] as String? ??
              'A gentle support check-in may help.',
          guidance: suggestion['guidance'] as String? ??
              'Let\'s focus on one calm next step.',
          actionLabel: suggestion['actionLabel'] as String? ?? 'Open Sprout',
          actionType: suggestion['actionType'] as String? ?? 'companion',
        );
        return;
      }
      Navigator.pushNamed(context, AppRoutes.patientOrientationSupport);
    });
  }

  Future<void> _showRoutineSupportPrompt({
    required String headline,
    required String guidance,
    required String actionLabel,
    required String actionType,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _RoutineSupportPromptDialog(
          headline: headline,
          guidance: guidance,
          actionLabel: actionLabel,
          onPrimaryAction: () {
            Navigator.of(dialogContext).pop();
            _handleSupportAction(actionType);
          },
          onDismiss: () => Navigator.of(dialogContext).pop(),
        );
      },
    );
  }

  Future<void> _handleSupportAction(String actionType) async {
    switch (actionType) {
      case 'orientation':
        if (!mounted) return;
        Navigator.pushNamed(context, AppRoutes.patientOrientationSupport);
        break;
      case 'tasks':
        await _setTab(3);
        break;
      case 'my_day':
        await _setTab(1);
        break;
      case 'find_item':
        if (!mounted) return;
        Navigator.pushNamed(context, AppRoutes.patientFindItem);
        break;
      case 'memories':
        await _setTab(2);
        break;
      case 'companion':
      default:
        await _openCompanion();
        break;
    }
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

    final profile = patientSession.profile!;
    if (!_loggedInitialHomeVisit) {
      _loggedInitialHomeVisit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _setTab(0);
      });
    }

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(profile.textScaleFactor),
      ),
      child: TickerMode(
        enabled: !profile.reducedMotionEnabled,
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: AppColors.background,
              body: IndexedStack(
                index: _currentIndex,
                children: [
                  PatientHomeScreen(onSwitchTab: _setTab),
                  const PatientMyDayWrapper(),
                  const MemoriesPage(),
                  const RecognitionTasksPage(),
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
                  NavigationDestination(
                    icon: Icon(Icons.extension_outlined),
                    selectedIcon: Icon(Icons.extension_rounded),
                    label: 'Tasks',
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
                        onStartRecognitionTask: () async {
                          final memoryProvider = context.read<MemoryProvider>();
                          final recognitionProvider = context
                              .read<RecognitionProvider>();
                          if (memoryProvider.memories.isEmpty) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Add a few memories first so recognition support can help.',
                                ),
                              ),
                            );
                            return;
                          }
                          final candidate = memoryProvider.memories.firstWhere(
                            (memory) =>
                                memory.type.name == 'person' ||
                                memory.type.name == 'place',
                            orElse: () => memoryProvider.memories.first,
                          );
                          final task = await recognitionProvider
                              .createConfusionSupportTask(candidate);
                          if (!context.mounted || task == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  RecognitionActivityScreen(task: task),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

            Positioned(
              right: 18,
              bottom: 96,
              child: _FloatingPatientSupportButtons(
                onOpenCompanion: _openCompanion,
                onOpenHelp: _triggerQuickHelp,
                highContrast: profile.highContrastEnabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PatientHomeScreen extends StatelessWidget {
  final ValueChanged<int> onSwitchTab;
  const PatientHomeScreen({super.key, required this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final profile = context.watch<PatientSessionProvider>().profile;
    final simpleLayout = profile?.simpleLayoutEnabled ?? false;
    final sectionGap = simpleLayout ? 16.0 : 24.0;
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
                  SizedBox(height: sectionGap),
                  const _DailySummarySnapshotCard(),
                  SizedBox(height: sectionGap),
                  const _MemoryMomentSection(),
                  SizedBox(height: sectionGap),
                  _SmartSupportCard(textTheme: textTheme),
                  SizedBox(height: sectionGap),
                  const _ContextMemoryCueSection(),
                  SizedBox(height: sectionGap),
                  _PrimaryActionButtons(textTheme: textTheme),
                  SizedBox(height: sectionGap),
                  _DailySupportSection(textTheme: textTheme),
                  SizedBox(height: sectionGap),
                  const _BehaviorInsightSection(),
                  if (!simpleLayout) ...[
                    SizedBox(height: sectionGap),
                    const _WellbeingSection(),
                    SizedBox(height: sectionGap),
                    const _PassiveSafetySection(),
                  ],
                  SizedBox(height: sectionGap),
                  _LightEngagementSection(
                    textTheme: textTheme,
                    onSwitchTab: onSwitchTab,
                  ),
                  SizedBox(height: sectionGap),
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
    final reminderProvider = context.watch<ReminderProvider>();
    final recordsService = context.watch<PatientRecordsService>();
    final suggestion = profile == null
        ? const {
            'headline': 'You are safe and supported',
            'guidance':
                'Open Sprout, orientation support, or item finding whenever you need a little help.',
            'actionLabel': 'Open Sprout',
            'actionType': 'companion',
          }
        : recordsService.buildContextSupportSuggestion(
            profile: profile,
            confusionState: reminderProvider.currentConfusionState,
            activeReminder: reminderProvider.currentReminder,
          );
    final headline = suggestion['headline'] as String? ?? 'You are safe and supported';
    final supportLine = suggestion['guidance'] as String? ??
        (profile?.lastKnownContextSummary ?? 'You are safe at home.');
    final actionLabel = suggestion['actionLabel'] as String? ?? 'Open Sprout';
    final actionType = suggestion['actionType'] as String? ?? 'companion';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceContainerLowest,
            AppColors.primaryContainer.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.assistant_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: textTheme.titleLarge?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      supportLine,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppColors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => _handleSupportAction(context, actionType),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(actionLabel),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.patientCompanion),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('Ask Sprout'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleSupportAction(BuildContext context, String actionType) {
    switch (actionType) {
      case 'orientation':
        Navigator.pushNamed(context, AppRoutes.patientOrientationSupport);
        break;
      case 'tasks':
        DefaultTabController.maybeOf(context);
        Navigator.pushNamed(context, AppRoutes.patientActivities);
        break;
      case 'find_item':
        Navigator.pushNamed(context, AppRoutes.patientFindItem);
        break;
      default:
        Navigator.pushNamed(context, AppRoutes.patientCompanion);
    }
  }
}

class _ContextMemoryCueSection extends StatelessWidget {
  const _ContextMemoryCueSection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reminderProvider = context.watch<ReminderProvider>();
    final recordsService = context.watch<PatientRecordsService>();
    final profile = context.watch<PatientSessionProvider>().profile;
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

    CameraEvent? latestImportantItem;
    if (profile != null) {
      for (final item in profile.importantItems) {
        final sighting = recordsService.findLatestObjectSighting(item);
        if (sighting != null) {
          latestImportantItem = sighting;
          break;
        }
      }
    }

    final cueText = primaryPersonMemory != null
        ? 'This is ${primaryPersonMemory.name}. Take a moment to remember them.'
        : primaryPlaceMemory != null
        ? 'Do you remember this place: ${primaryPlaceMemory.name}?'
        : latestImportantItem != null
        ? 'I recently noticed ${latestImportantItem.detectedObjects.isNotEmpty ? latestImportantItem.detectedObjects.first : 'an important item'} around ${latestImportantItem.locationHint}.'
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
              if (latestImportantItem != null)
                ActionChip(
                  label: const Text('Find an item'),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.patientFindItem),
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

  const _PrimaryActionButtons({
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
          title: 'Orientation',
          subtitle: 'Open calm support and grounding cues',
          icon: Icons.self_improvement_rounded,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          textTheme: textTheme,
          onTap: () {
            context.read<PatientSessionProvider>().touchActivity(
              'Opening orientation support',
              contextSummary:
                  'The patient opened the orientation support screen from the dashboard.',
            );
            Navigator.pushNamed(context, AppRoutes.patientOrientationSupport);
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

class _FloatingPatientSupportButtons extends StatelessWidget {
  final Future<void> Function() onOpenCompanion;
  final Future<void> Function() onOpenHelp;
  final bool highContrast;

  const _FloatingPatientSupportButtons({
    required this.onOpenCompanion,
    required this.onOpenHelp,
    required this.highContrast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpenCompanion,
            customBorder: const CircleBorder(),
            child: Ink(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: highContrast ? AppColors.surfaceContainerLowest : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: highContrast
                      ? AppColors.onSurface
                      : const Color(0xFFDCEADD),
                  width: highContrast ? 2.5 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  'assets/images/sprout_companion.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.small(
          onPressed: onOpenHelp,
          backgroundColor: AppColors.error,
          foregroundColor: AppColors.onError,
          heroTag: 'patient_help_fab',
          child: const Icon(Icons.help_rounded, size: 20),
        ),
      ],
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
    final profile = context.watch<PatientSessionProvider>().profile;
    final current = reminderProvider.currentReminder;
    final routineDigest = profile == null
        ? null
        : context.watch<PatientRecordsService>().buildRoutineDigest(
            patientId: profile.patientId,
            activeReminder: current,
          );
    final recentLogs = List<ReminderLog>.from(
      routineDigest?['recentLogs'] ?? const <ReminderLog>[],
    );
    final completedCount = routineDigest?['completed'] as int? ?? 0;
    final remindLaterCount = routineDigest?['remindLater'] as int? ?? 0;
    final ignoredCount = routineDigest?['ignored'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ROUTINE SUPPORT',
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              TextButton(
                onPressed: current == null
                    ? () => reminderProvider.triggerMockReminder()
                    : () =>
                        Navigator.pushNamed(context, '/patient/event_history'),
                child: Text(
                  current == null ? 'Show Reminder' : 'View Activity',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: current != null
                  ? _colorForType(current.type).withValues(alpha: 0.22)
                  : AppColors.outlineVariant.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (current != null
                              ? _colorForType(current.type)
                              : AppColors.primary)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      current != null
                          ? _iconForType(current.type)
                          : Icons.schedule_rounded,
                      color: current != null
                          ? _colorForType(current.type)
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routineDigest?['headline'] as String? ??
                              'Today\'s routine',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          routineDigest?['guidance'] as String? ??
                              'One gentle step at a time.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (current != null) ...[
                _RoutineFocusCard(
                  title: current.title,
                  description: current.description,
                  timeLabel: DateFormat('h:mm a').format(current.scheduledTime),
                  accent: _colorForType(current.type),
                  onDone: () =>
                      reminderProvider.handleResponse(ReminderAction.done),
                  onLater: () =>
                      reminderProvider.handleResponse(ReminderAction.remindLater),
                  onNeedHelp: () => reminderProvider.triggerMockConfusion(),
                ),
              ] else ...[
                _RoutineFocusCard(
                  title: 'No active reminder right now',
                  description:
                      'Your next medicine, water, or daily task will appear here when it is time.',
                  timeLabel: 'Routine ready',
                  accent: AppColors.primary,
                  primaryLabel: 'Show practice reminder',
                  secondaryLabel: 'Open My Day',
                  tertiaryLabel: 'Need support',
                  onDone: reminderProvider.triggerMockReminder,
                  onLater: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MyDayMainPage(),
                    ),
                  ),
                  onNeedHelp: () => reminderProvider.triggerMockConfusion(),
                ),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _RoutineCountChip(
                    icon: Icons.check_circle_rounded,
                    label: '$completedCount done',
                    color: const Color(0xFF2E7D32),
                  ),
                  _RoutineCountChip(
                    icon: Icons.schedule_rounded,
                    label: '$remindLaterCount later',
                    color: const Color(0xFFE67E22),
                  ),
                  _RoutineCountChip(
                    icon: Icons.notifications_off_rounded,
                    label: '$ignoredCount skipped',
                    color: AppColors.error,
                  ),
                ],
              ),
              if (recentLogs.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Recent routine activity',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ...recentLogs.map(
                  (log) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RoutineHistoryTile(
                      icon: _iconForType(log.reminderType),
                      accent: _colorForType(log.reminderType),
                      title: _routineActionLabel(log),
                      subtitle: DateFormat('h:mm a').format(log.timestamp),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, AppRoutes.patientObservationHistory),
                borderRadius: BorderRadius.circular(16),
                child: _TaskCard(
                  title: 'Review observations',
                  subtitle: 'Look over recent moments and item sightings.',
                  icon: Icons.history_rounded,
                  iconColor: AppColors.secondary,
                  textTheme: textTheme,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TaskCard(
                title: 'Take a short walk',
                subtitle: 'A little movement can help you feel fresh.',
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
                subtitle: 'A familiar voice can be calming and reassuring.',
                icon: Icons.call_rounded,
                iconColor: AppColors.tertiary,
                textTheme: textTheme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, AppRoutes.patientFindItem),
                borderRadius: BorderRadius.circular(16),
                child: _TaskCard(
                  title: 'Find an item',
                  subtitle: 'Search for glasses, diary, medicine, or keys.',
                  icon: Icons.search_rounded,
                  iconColor: AppColors.primary,
                  textTheme: textTheme,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _routineActionLabel(ReminderLog log) {
    final action = switch (log.actionTaken) {
      ReminderAction.done => 'Completed',
      ReminderAction.remindLater => 'Remind later',
      ReminderAction.ignore => 'Skipped',
      ReminderAction.shown => 'Shown',
    };
    final type = switch (log.reminderType) {
      ReminderType.medicine => 'medicine reminder',
      ReminderType.water => 'water reminder',
      ReminderType.task => 'daily task',
      ReminderType.appointment => 'appointment reminder',
    };
    return '$action • $type';
  }
}

class _TaskCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final TextTheme textTheme;

  const _TaskCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 32),
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
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoutineFocusCard extends StatelessWidget {
  final String title;
  final String description;
  final String timeLabel;
  final Color accent;
  final String primaryLabel;
  final String secondaryLabel;
  final String tertiaryLabel;
  final VoidCallback onDone;
  final VoidCallback onLater;
  final VoidCallback onNeedHelp;

  const _RoutineFocusCard({
    required this.title,
    required this.description,
    required this.timeLabel,
    required this.accent,
    required this.onDone,
    required this.onLater,
    required this.onNeedHelp,
    this.primaryLabel = 'Done now',
    this.secondaryLabel = 'Later',
    this.tertiaryLabel = 'Need help',
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              timeLabel,
              style: textTheme.labelLarge?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onDone,
                  style: FilledButton.styleFrom(backgroundColor: accent),
                  child: Text(primaryLabel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onLater,
                  child: Text(secondaryLabel),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onNeedHelp,
            icon: const Icon(Icons.self_improvement_rounded),
            label: Text(tertiaryLabel),
          ),
        ],
      ),
    );
  }
}

class _RoutineCountChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _RoutineCountChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineHistoryTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;

  const _RoutineHistoryTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
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

class _RoutineSupportPromptDialog extends StatelessWidget {
  final String headline;
  final String guidance;
  final String actionLabel;
  final VoidCallback onPrimaryAction;
  final VoidCallback onDismiss;

  const _RoutineSupportPromptDialog({
    required this.headline,
    required this.guidance,
    required this.actionLabel,
    required this.onPrimaryAction,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Gentle support',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              headline,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              guidance,
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Take one small step. You do not need to do everything at once.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPrimaryAction,
                child: Text(actionLabel),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onDismiss,
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
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
    final visualDigest = context
        .watch<PatientRecordsService>()
        .buildVisualBehaviorDigest();
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
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  (visualDigest['possibleWandering'] as bool? ?? false)
                      ? Icons.route_rounded
                      : Icons.visibility_rounded,
                  color: color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    visualDigest['statusLabel'] as String? ??
                        'Recent visual patterns look steady.',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if ((visualDigest['possibleFallCount'] as int? ?? 0) > 0 ||
              (visualDigest['riskySceneCount'] as int? ?? 0) > 0 ||
              (visualDigest['shortIntervalSwitches'] as int? ?? 0) > 0 ||
              (visualDigest['repeatedLoopCount'] as int? ?? 0) > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if ((visualDigest['shortIntervalSwitches'] as int? ?? 0) > 0)
                  _InsightFlagChip(
                    icon: Icons.directions_walk_rounded,
                    label:
                        '${visualDigest['shortIntervalSwitches']} quick move${(visualDigest['shortIntervalSwitches'] as int? ?? 0) == 1 ? '' : 's'}',
                    color: const Color(0xFF6D4C41),
                  ),
                if ((visualDigest['repeatedLoopCount'] as int? ?? 0) > 0)
                  _InsightFlagChip(
                    icon: Icons.sync_alt_rounded,
                    label:
                        '${visualDigest['repeatedLoopCount']} repeated loop${(visualDigest['repeatedLoopCount'] as int? ?? 0) == 1 ? '' : 's'}',
                    color: const Color(0xFF8D6E63),
                  ),
                if ((visualDigest['possibleFallCount'] as int? ?? 0) > 0)
                  _InsightFlagChip(
                    icon: Icons.personal_injury_rounded,
                    label:
                        '${visualDigest['possibleFallCount']} possible fall signal${(visualDigest['possibleFallCount'] as int? ?? 0) == 1 ? '' : 's'}',
                    color: AppColors.error,
                  ),
                if ((visualDigest['riskySceneCount'] as int? ?? 0) > 0)
                  _InsightFlagChip(
                    icon: Icons.report_problem_rounded,
                    label:
                        '${visualDigest['riskySceneCount']} risky scene${(visualDigest['riskySceneCount'] as int? ?? 0) == 1 ? '' : 's'}',
                    color: const Color(0xFFE67E22),
                  ),
              ],
            ),
          ],
          if ((visualDigest['wanderingHeadline'] as String?)?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SupportLine(
                icon: Icons.route_rounded,
                text: visualDigest['wanderingHeadline'] as String,
              ),
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
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.patientObservationHistory,
            ),
            icon: const Icon(Icons.history_rounded),
            label: const Text('Review Observation Patterns'),
          ),
        ],
      ),
    );
  }
}

class _InsightFlagChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InsightFlagChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailySummarySnapshotCard extends StatelessWidget {
  const _DailySummarySnapshotCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final profile = context.watch<PatientSessionProvider>().profile;
    final reminderProvider = context.watch<ReminderProvider>();
    final recognitionProvider = context.watch<RecognitionProvider>();
    if (profile == null) return const SizedBox.shrink();

    final digest = context.watch<PatientRecordsService>().buildDailyDigest(
      patientId: profile.patientId,
      confusionState: reminderProvider.currentConfusionState,
      activeReminder: reminderProvider.currentReminder,
    );
    final observationDigest = context
        .watch<PatientRecordsService>()
        .buildObservationDigest();
    final stableItemSightings =
        (observationDigest['stableItemSightings'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();

    final quickStats = <_SummaryStat>[
      _SummaryStat(
        label: 'Mood',
        value: '${digest['todayMood']}',
        icon: Icons.sentiment_satisfied_alt_rounded,
      ),
      _SummaryStat(
        label: 'Reminders',
        value: '${digest['completedReminders']} done',
        icon: Icons.checklist_rounded,
      ),
      _SummaryStat(
        label: 'Observations',
        value: '${digest['capturedObservations']} saved',
        icon: Icons.visibility_rounded,
      ),
      _SummaryStat(
        label: 'Tasks',
        value: '${recognitionProvider.todayTasks.length} ready',
        icon: Icons.extension_rounded,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Today at a glance',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (digest['reflectionDone'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Reflection done',
                    style: textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF2E7D32),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            digest['activeReminder'] != null
                ? 'Next gentle focus: ${digest['activeReminder']}'
                : 'Your patient day summary updates here as you move through reminders, memories, and support.',
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.75,
            ),
            itemCount: quickStats.length,
            itemBuilder: (context, index) {
              final stat = quickStats[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(stat.icon, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            stat.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelMedium?.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stat.value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (stableItemSightings.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Recently seen important items',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.patientFindItem,
                  ),
                  child: const Text('Find Item'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: stableItemSightings
                  .take(3)
                  .map(
                    (item) => _RecentItemSightingChip(
                      objectName: item['object'] as String? ?? 'item',
                      location: item['location'] as String? ?? 'unknown',
                      timestamp: item['timestamp'] as DateTime?,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryStat {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryStat({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _RecentItemSightingChip extends StatelessWidget {
  final String objectName;
  final String location;
  final DateTime? timestamp;

  const _RecentItemSightingChip({
    required this.objectName,
    required this.location,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final seenAt = timestamp != null
        ? DateFormat('h:mm a').format(timestamp!)
        : null;

    return Container(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.visibility_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _titleCase(objectName),
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            location == 'unknown'
                ? 'Seen recently in a saved observation'
                : 'Last seen near $location',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          if (seenAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'At $seenAt',
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.length > 1 ? part.substring(1) : ''}',
        )
        .join(' ');
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
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Safety Monitor',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
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
