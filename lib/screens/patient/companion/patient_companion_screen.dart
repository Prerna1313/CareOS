import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../models/memory_item.dart';
import '../../../models/patient/patient_profile.dart';
import '../../../models/reminder.dart';
import '../../../models/interaction_signal.dart';
import '../../../models/speech_signal.dart';
import '../../../providers/memory_provider.dart';
import '../../../providers/my_day_provider.dart';
import '../../../providers/patient_session_provider.dart';
import '../../../providers/recognition_provider.dart';
import '../../../providers/reminder_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../services/interaction_signal_service.dart';
import '../../../services/patient_records_service.dart';
import '../../../services/speech_signal_service.dart';
import '../../../services/voice_orientation_service.dart';
import '../sos/sos_emergency_screen.dart';
import '../../../theme/app_colors.dart';

class PatientCompanionScreen extends StatefulWidget {
  const PatientCompanionScreen({super.key});

  @override
  State<PatientCompanionScreen> createState() => _PatientCompanionScreenState();
}

class _PatientCompanionScreenState extends State<PatientCompanionScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final VoiceOrientationService _voiceService = VoiceOrientationService();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final List<_CompanionMessage> _messages = [];
  bool _speechAvailable = false;
  bool _isListening = false;
  DateTime? _listeningStartedAt;
  int _maxDraftLength = 0;
  int _draftRevisionCount = 0;
  String _lastDraftValue = '';

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleDraftChanged);
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _seedWelcomeMessage();
    });
  }

  @override
  void dispose() {
    final profile = context.read<PatientSessionProvider>().profile;
    final draft = _textController.text.trim();
    if (profile != null && draft.isNotEmpty) {
      context.read<InteractionSignalService>().logSignal(
        InteractionSignal(
          id: 'companion_abandoned_${DateTime.now().microsecondsSinceEpoch}',
          patientId: profile.patientId,
          timestamp: DateTime.now(),
          type: InteractionSignalType.actionAbandoned,
          screenName: 'sprout_companion',
          summary: 'A Sprout question was started but not submitted.',
          metadata: {
            'draftLength': draft.length,
            'revisionCount': _draftRevisionCount,
          },
        ),
      );
      context.read<InteractionSignalService>().logSignal(
        InteractionSignal(
          id: 'companion_incomplete_${DateTime.now().microsecondsSinceEpoch}',
          patientId: profile.patientId,
          timestamp: DateTime.now(),
          type: InteractionSignalType.incompleteAction,
          screenName: 'sprout_companion',
          summary: 'A guided companion help action was left incomplete.',
          metadata: {'draftLength': draft.length},
        ),
      );
    }
    _textController.removeListener(_handleDraftChanged);
    _textController.dispose();
    _scrollController.dispose();
    _voiceService.stop();
    super.dispose();
  }

  void _handleDraftChanged() {
    final current = _textController.text;
    if (current.length > _maxDraftLength) {
      _maxDraftLength = current.length;
    }
    if (_lastDraftValue.isNotEmpty &&
        current.length + 1 < _lastDraftValue.length) {
      _draftRevisionCount++;
    }
    _lastDraftValue = current;
  }

  void _seedWelcomeMessage() {
    final profile = context.read<PatientSessionProvider>().profile;
    final name = profile?.displayName ?? 'Friend';
    final caregiver = profile?.caregiverName ?? 'your caregiver';
    final location = profile?.homeLabel ?? 'home';

    final welcome =
        'Hi $name. I am Sprout, your CareOS companion. You are safe at $location, and $caregiver is part of your support circle. You can ask me for help, memories, or finding an important item.';

    _addAssistantMessage(
      welcome,
      action: const _CompanionAction(
        label: 'Show Orientation Support',
        type: _CompanionActionType.orientation,
      ),
    );
  }

  Future<void> _initSpeech() async {
    final available = await _speechToText.initialize(
      onStatus: (status) {
        if (!mounted) return;
        setState(() {
          _isListening = status == 'listening';
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice input is unavailable right now: ${error.errorMsg}'),
          ),
        );
      },
    );
    if (!mounted) return;
    setState(() {
      _speechAvailable = available;
    });
  }

  Future<void> _handleQuickPrompt(String prompt) async {
    _textController.text = prompt;
    await _handleSubmit();
  }

  Future<void> _handleSubmit() async {
    final input = _textController.text.trim();
    if (input.isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.add(_CompanionMessage.user(input));
    });
    _scrollToBottom();

    final sessionProvider = context.read<PatientSessionProvider>();
    final interactionSignalService = context.read<InteractionSignalService>();
    await sessionProvider.touchActivity(
      'Talking with Sprout companion',
      contextSummary: 'The patient is using the companion for guided help.',
    );
    final profile = sessionProvider.profile;
    if (profile != null) {
      await interactionSignalService.logSignal(
        InteractionSignal(
          id: 'companion_query_${DateTime.now().microsecondsSinceEpoch}',
          patientId: profile.patientId,
          timestamp: DateTime.now(),
          type: InteractionSignalType.actionCompleted,
          screenName: 'sprout_companion',
          summary: 'The patient sent a guided companion question.',
          metadata: {'queryLength': input.length},
        ),
      );
      if (_draftRevisionCount >= 2 || _looksLikeTypingDifficulty(input)) {
        await interactionSignalService.logSignal(
          InteractionSignal(
            id: 'typing_difficulty_${DateTime.now().microsecondsSinceEpoch}',
            patientId: profile.patientId,
            timestamp: DateTime.now(),
            type: InteractionSignalType.typingDifficulty,
            screenName: 'sprout_companion',
            summary:
                'The patient showed typing corrections or hesitation before sending a question.',
            metadata: {
              'revisionCount': _draftRevisionCount,
              'queryLength': input.length,
            },
          ),
        );
      }
    }
    _resetDraftTracking();

    final reply = _buildReply(input);
    _addAssistantMessage(reply.text, action: reply.action);
  }

  _CompanionReply _buildReply(String input) {
    final normalized = input.toLowerCase();
    final profile = context.read<PatientSessionProvider>().profile;
    final records = context.read<PatientRecordsService>();
    final memoryProvider = context.read<MemoryProvider>();
    final recognitionProvider = context.read<RecognitionProvider>();
    final reminderProvider = context.read<ReminderProvider>();
    final myDayProvider = context.read<MyDayProvider>();

    final orientationTime = DateFormat('EEEE, h:mm a').format(DateTime.now());
    final homeLabel = profile?.homeLabel ?? 'home';
    final caregiverName = profile?.caregiverName ?? 'Rahul';
    final caregiverRelationship = profile?.caregiverRelationship ?? 'son';

    if (_containsAny(normalized, const [
      'where am i',
      'am i at home',
      'where are we',
      'orientation',
    ])) {
      return _CompanionReply(
        text:
            'You are at $homeLabel. It is $orientationTime, and you are safe. $caregiverName is your $caregiverRelationship.',
        action: const _CompanionAction(
          label: 'Open Orientation Support',
          type: _CompanionActionType.orientation,
        ),
      );
    }

    if (_containsAny(normalized, const [
      'caregiver',
      'daughter',
      'son',
      'who is',
      'family',
    ])) {
      return _CompanionReply(
        text:
            '$caregiverName is your $caregiverRelationship. If you want, I can also help you look at familiar memories.',
        action: const _CompanionAction(
          label: 'Open Memories',
          type: _CompanionActionType.memories,
        ),
      );
    }

    final itemQuery = _extractImportantItem(normalized, profile);
    if (itemQuery != null ||
        _containsAny(normalized, const [
          'where is my',
          'find my',
          'find',
          'where did i keep',
        ])) {
      final query = itemQuery ?? normalized;
      final sighting = records.findLatestObjectSighting(query);
      if (sighting != null) {
        final when = DateFormat('h:mm a').format(
          sighting.analysisTimestamp ?? sighting.timestamp,
        );
        final location = sighting.locationHint.isNotEmpty
            ? sighting.locationHint
            : 'a familiar place nearby';
        final itemLabel = itemQuery ?? query;
        return _CompanionReply(
          text:
              'I last noticed your $itemLabel around $location at $when. I can help you open the full item-finding view too.',
          action: const _CompanionAction(
            label: 'Find My Item',
            type: _CompanionActionType.findItem,
          ),
        );
      }
      return const _CompanionReply(
        text:
            'I do not have a recent sighting yet, but I can help you search your saved observations.',
        action: _CompanionAction(
          label: 'Search Observations',
          type: _CompanionActionType.findItem,
        ),
      );
    }

    if (_containsAny(normalized, const [
      'memory',
      'show a memory',
      'remember',
      'who visited',
      'place',
      'photo',
    ])) {
      final MemoryItem? featuredMemory = memoryProvider.memories.isNotEmpty
          ? memoryProvider.memories.first
          : null;
      if (featuredMemory != null) {
        final memoryType = switch (featuredMemory.type) {
          MemoryType.person => 'a familiar person',
          MemoryType.place => 'a familiar place',
          MemoryType.event => 'a past moment',
        };
        return _CompanionReply(
          text:
              'Let\'s revisit $memoryType: ${featuredMemory.name}. I can take you to your memories so we can look together.',
          action: const _CompanionAction(
            label: 'Open Memories',
            type: _CompanionActionType.memories,
          ),
        );
      }
      return const _CompanionReply(
        text:
            'Your memory space is still getting started. We can save a familiar face, place, or event first.',
        action: _CompanionAction(
          label: 'Open Memories',
          type: _CompanionActionType.memories,
        ),
      );
    }

    if (_containsAny(normalized, const [
      'what should i do',
      'what next',
      'task',
      'routine',
      'today',
    ])) {
      final Reminder? activeReminder = reminderProvider.currentReminder;
      if (activeReminder != null) {
        return _CompanionReply(
          text:
              'Your next helpful step is: ${activeReminder.title}. We can focus on that one thing first.',
        );
      }

      if (!myDayProvider.isChatCompleted) {
        return const _CompanionReply(
          text:
              'A gentle next step is to complete your My Day reflection. It helps keep today clear and calm.',
          action: _CompanionAction(
            label: 'Open My Day',
            type: _CompanionActionType.myDay,
          ),
        );
      }

      if (recognitionProvider.todayTasks.isNotEmpty) {
        return const _CompanionReply(
          text:
              'You have a memory task ready. Practicing one familiar face or place could be a nice next step.',
          action: _CompanionAction(
            label: 'Open Tasks',
            type: _CompanionActionType.tasks,
          ),
        );
      }

      return const _CompanionReply(
        text:
            'You are doing well. A calm next step could be taking a short walk, calling a loved one, or checking today\'s memories.',
        action: _CompanionAction(
          label: 'Open Tasks',
          type: _CompanionActionType.tasks,
        ),
      );
    }

    if (_containsAny(normalized, const [
      'calm',
      'anxious',
      'scared',
      'nervous',
      'help me',
      'confused',
    ])) {
      return _CompanionReply(
        text:
            'It is okay. Take one slow breath. You are at $homeLabel, and $caregiverName is your $caregiverRelationship. I can open a calm support screen for you now.',
        action: const _CompanionAction(
          label: 'Open Calm Support',
          type: _CompanionActionType.orientation,
        ),
      );
    }

    if (_containsAny(normalized, const [
      'call for help',
      'emergency',
      'sos',
      'urgent',
    ])) {
      return const _CompanionReply(
        text:
            'I can take you straight to your SOS screen so support is close and simple.',
        action: _CompanionAction(
          label: 'Open SOS',
          type: _CompanionActionType.sos,
        ),
      );
    }

    return const _CompanionReply(
      text:
          'I can help with orientation, finding an item, looking at memories, choosing the next task, or opening support. Try asking one small question.',
    );
  }

  bool _containsAny(String text, List<String> patterns) {
    return patterns.any(text.contains);
  }

  String? _extractImportantItem(String normalized, PatientProfile? profile) {
    final items = <String>[
      ...?profile?.importantItems,
      'glasses',
      'specs',
      'diary',
      'medicine',
      'keys',
    ];

    for (final item in items) {
      if (normalized.contains(item.toLowerCase())) {
        return item;
      }
    }
    return null;
  }

  Future<void> _runAction(_CompanionAction action) async {
    final profile = context.read<PatientSessionProvider>().profile;
    if (profile != null) {
      await context.read<InteractionSignalService>().logSignal(
        InteractionSignal(
          id: 'companion_action_${DateTime.now().microsecondsSinceEpoch}',
          patientId: profile.patientId,
          timestamp: DateTime.now(),
          type: InteractionSignalType.actionCompleted,
          screenName: 'sprout_companion',
          summary: 'The patient completed a Sprout suggested action.',
          metadata: {'actionType': action.type.name},
        ),
      );
    }
    if (!mounted) return;
    switch (action.type) {
      case _CompanionActionType.orientation:
        Navigator.pushNamed(context, AppRoutes.patientOrientationSupport);
        break;
      case _CompanionActionType.findItem:
        Navigator.pushNamed(context, AppRoutes.patientFindItem);
        break;
      case _CompanionActionType.memories:
        Navigator.pop(context, 'memories');
        break;
      case _CompanionActionType.myDay:
        Navigator.pop(context, 'my_day');
        break;
      case _CompanionActionType.tasks:
        Navigator.pop(context, 'tasks');
        break;
      case _CompanionActionType.sos:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const SosEmergencyScreen(),
            fullscreenDialog: true,
          ),
        );
        break;
    }
  }

  bool _looksLikeTypingDifficulty(String input) {
    final normalized = input.toLowerCase();
    if (normalized.contains('..') || normalized.contains('??')) {
      return true;
    }
    const uncertainTokens = ['wher', 'hwat', 'plase', 'sory', 'umm', 'uhh'];
    return uncertainTokens.any(normalized.contains);
  }

  void _resetDraftTracking() {
    _maxDraftLength = 0;
    _draftRevisionCount = 0;
    _lastDraftValue = '';
  }

  Future<void> _toggleVoicePrompts(bool enabled) async {
    final session = context.read<PatientSessionProvider>();
    final profile = session.profile;
    if (profile == null) return;
    await session.updateProfileSettings(
      displayName: profile.displayName,
      homeLabel: profile.homeLabel,
      city: profile.city,
      caregiverName: profile.caregiverName,
      caregiverRelationship: profile.caregiverRelationship,
      importantItems: profile.importantItems,
      autoOrientationEnabled: profile.autoOrientationEnabled,
      voicePromptsEnabled: enabled,
      textScaleFactor: profile.textScaleFactor,
      highContrastEnabled: profile.highContrastEnabled,
      reducedMotionEnabled: profile.reducedMotionEnabled,
      simpleLayoutEnabled: profile.simpleLayoutEnabled,
    );
    if (!enabled) {
      _voiceService.stop();
    } else {
      final latestAssistant = _messages.lastWhere(
        (message) => !message.isUser,
        orElse: () => _CompanionMessage.assistant(
          'Sprout voice is on again. I am here with you.',
        ),
      );
      _voiceService.speak(latestAssistant.text);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled ? 'Sprout voice turned on.' : 'Sprout voice turned off.',
        ),
      ),
    );
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice input is not available on this device yet.'),
        ),
      );
      return;
    }

    if (_isListening) {
      await _speechToText.stop();
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _listeningStartedAt = null;
      });
      return;
    }

    final sessionProvider = context.read<PatientSessionProvider>();
    final interactionSignalService = context.read<InteractionSignalService>();
    final speechSignalService = context.read<SpeechSignalService>();
    final profile = sessionProvider.profile;
    await sessionProvider.touchActivity(
      'Speaking with Sprout companion',
      contextSummary: 'The patient is using voice input with Sprout.',
    );
    if (profile != null) {
      await interactionSignalService.logSignal(
        InteractionSignal(
          id: 'voice_started_${DateTime.now().microsecondsSinceEpoch}',
          patientId: profile.patientId,
          timestamp: DateTime.now(),
          type: InteractionSignalType.actionStarted,
          screenName: 'sprout_companion',
          summary: 'The patient started voice input with Sprout.',
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _isListening = true;
      _listeningStartedAt = DateTime.now();
    });
    await _speechToText.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _textController.text = result.recognizedWords;
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
          if (result.finalResult) {
            _isListening = false;
          }
        });
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          final startedAt = _listeningStartedAt;
          _listeningStartedAt = null;
          if (profile != null) {
            final durationSeconds = startedAt == null
                ? 0
                : DateTime.now().difference(startedAt).inSeconds;
            speechSignalService.logSpeechSignal(
              patientId: profile.patientId,
              source: SpeechSignalSource.companionVoice,
              transcript: result.recognizedWords,
              durationSeconds: durationSeconds,
            );
          }
          _handleSubmit();
        }
      },
      localeId: null,
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        partialResults: true,
        cancelOnError: true,
      ),
    );

    if (profile?.voicePromptsEnabled == true) {
      _voiceService.stop();
    }
  }

  void _addAssistantMessage(
    String text, {
    _CompanionAction? action,
  }) {
    setState(() {
      _messages.add(_CompanionMessage.assistant(text, action: action));
    });
    _scrollToBottom();

    final profile = context.read<PatientSessionProvider>().profile;
    if (profile?.voicePromptsEnabled == true) {
      _voiceService.speak(text);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PatientSessionProvider>().profile;
    final textTheme = Theme.of(context).textTheme;
    final reminderProvider = context.watch<ReminderProvider>();
    final recordsService = context.watch<PatientRecordsService>();
    final voiceEnabled = profile?.voicePromptsEnabled ?? true;
    final suggestion = profile == null
        ? const {
            'headline': 'You are safe and supported.',
            'guidance': 'Ask Sprout one small question at a time.',
            'actionType': 'companion',
          }
        : recordsService.buildContextSupportSuggestion(
            profile: profile,
            confusionState: reminderProvider.currentConfusionState,
            activeReminder: reminderProvider.currentReminder,
          );
    final quickPrompts = _buildSuggestionPrompts(
      profile: profile,
      suggestion: suggestion,
    );

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(profile?.textScaleFactor ?? 1.0),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAF9),
        body: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/sprout_companion.png',
                        height: 78,
                        width: 78,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sprout Companion',
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2D2D2D),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Here to help ${profile?.displayName ?? 'you'} feel calm and supported',
                              style: textTheme.bodyLarge?.copyWith(
                                color: const Color(0xFF5E675E),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: voiceEnabled
                            ? 'Turn Sprout voice off'
                            : 'Turn Sprout voice on',
                        onPressed: () => _toggleVoicePrompts(!voiceEnabled),
                        icon: Icon(
                          voiceEnabled
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Repeat last Sprout message',
                        onPressed: voiceEnabled
                            ? () {
                                _CompanionMessage? latestAssistant;
                                for (final message in _messages.reversed) {
                                  if (!message.isUser) {
                                    latestAssistant = message;
                                    break;
                                  }
                                }
                                if (latestAssistant != null) {
                                  _voiceService.speak(latestAssistant.text);
                                }
                              }
                            : null,
                        icon: const Icon(Icons.record_voice_over_rounded),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE0E5E0)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: _CompanionStatusCard(
                    headline: suggestion['headline'] as String? ??
                        'You are safe and supported.',
                    guidance: suggestion['guidance'] as String? ??
                        'Ask Sprout one small question at a time.',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: _QuickPromptTray(
                    prompts: quickPrompts,
                    onTap: _handleQuickPrompt,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      if (message.isUser) {
                        return _UserCompanionBubble(
                          text: message.text,
                          textTheme: textTheme,
                        );
                      }
                      return _SproutCompanionBubble(
                        text: message.text,
                        textTheme: textTheme,
                        action: message.action,
                        onActionTap: message.action == null
                            ? null
                            : () => _runAction(message.action!),
                      );
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    18,
                    24,
                    MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isListening)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF7EA),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFDCEADD)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.mic_rounded,
                                color: Color(0xFF5F8F2D),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Sprout is listening. Speak one short question.',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF47633D),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              style: textTheme.bodyLarge,
                              decoration: InputDecoration(
                                hintText: _isListening
                                    ? 'Listening...'
                                    : 'Ask Sprout for help...',
                                filled: true,
                                fillColor: const Color(0xFFF0F4F0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                              onSubmitted: (_) => _handleSubmit(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _toggleListening,
                            child: Container(
                              height: 56,
                              width: 56,
                              decoration: BoxDecoration(
                                color: _isListening
                                    ? const Color(0xFFE67E22)
                                    : const Color(0xFFE8F2E0),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isListening
                                    ? Icons.stop_rounded
                                    : Icons.mic_rounded,
                                color: _isListening
                                    ? Colors.white
                                    : const Color(0xFF5F8F2D),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _handleSubmit,
                            child: Container(
                              height: 56,
                              width: 56,
                              decoration: const BoxDecoration(
                                color: Color(0xFF7CB342),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> _buildSuggestionPrompts({
    required PatientProfile? profile,
    required Map<String, dynamic> suggestion,
  }) {
    final prompts = <String>[
      'Where am I?',
      'What should I do now?',
      'Help me feel calm',
    ];

    final firstItem = profile?.importantItems.isNotEmpty == true
        ? profile!.importantItems.first
        : 'diary';
    prompts.add('Find my $firstItem');

    final actionType = suggestion['actionType'] as String? ?? '';
    if (actionType == 'orientation') {
      prompts.insert(0, 'Am I at home?');
    } else if (actionType == 'find_item') {
      prompts.insert(0, 'Find my item');
    } else {
      prompts.add('Show a memory');
    }

    return prompts.take(5).toList();
  }
}

class _CompanionStatusCard extends StatelessWidget {
  final String headline;
  final String guidance;

  const _CompanionStatusCard({
    required this.headline,
    required this.guidance,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF7EA),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCEADD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF305124),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            guidance,
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF47633D),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickPromptChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEBF5EB),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFDCEADD)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFF3C5D2B),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _QuickPromptTray extends StatelessWidget {
  final List<String> prompts;
  final ValueChanged<String> onTap;

  const _QuickPromptTray({
    required this.prompts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE1E9E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Try asking Sprout',
            style: textTheme.labelLarge?.copyWith(
              color: const Color(0xFF47633D),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) => _QuickPromptChip(
                label: prompts[index],
                onTap: () => onTap(prompts[index]),
              ),
              separatorBuilder: (context, index) =>
                  const SizedBox(width: 10),
              itemCount: prompts.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _SproutCompanionBubble extends StatelessWidget {
  final String text;
  final TextTheme textTheme;
  final _CompanionAction? action;
  final VoidCallback? onActionTap;

  const _SproutCompanionBubble({
    required this.text,
    required this.textTheme,
    this.action,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 64),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEBF5EB), Color(0xFFF7FBF7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                      bottomLeft: Radius.circular(4),
                    ),
                    border: Border.all(
                      color: const Color(0xFFDCEADD),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF2D2D2D),
                          height: 1.45,
                          fontSize: 18,
                        ),
                      ),
                      if (action != null) ...[
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: onActionTap,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: Text(action!.label),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7CB342),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  left: -7,
                  bottom: 0,
                  child: CustomPaint(
                    size: const Size(14, 14),
                    painter: _TailPainter(const Color(0xFFDCEADD)),
                  ),
                ),
                Positioned(
                  left: -5,
                  bottom: 1.5,
                  child: CustomPaint(
                    size: const Size(12, 12),
                    painter: _TailPainter(const Color(0xFFEBF5EB)),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: -8,
            bottom: -10,
            child: Container(
              height: 84,
              width: 84,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE8F2E8), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                'assets/images/sprout_companion.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCompanionBubble extends StatelessWidget {
  final String text;
  final TextTheme textTheme;

  const _UserCompanionBubble({required this.text, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 72),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            text,
            style: textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF2E7D32),
              fontSize: 17,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanionMessage {
  final String text;
  final bool isUser;
  final _CompanionAction? action;

  const _CompanionMessage._({
    required this.text,
    required this.isUser,
    this.action,
  });

  factory _CompanionMessage.user(String text) =>
      _CompanionMessage._(text: text, isUser: true);

  factory _CompanionMessage.assistant(
    String text, {
    _CompanionAction? action,
  }) => _CompanionMessage._(text: text, isUser: false, action: action);
}

class _CompanionReply {
  final String text;
  final _CompanionAction? action;

  const _CompanionReply({required this.text, this.action});
}

class _CompanionAction {
  final String label;
  final _CompanionActionType type;

  const _CompanionAction({required this.label, required this.type});
}

enum _CompanionActionType { orientation, findItem, memories, myDay, tasks, sos }

class _TailPainter extends CustomPainter {
  final Color color;

  _TailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(size.width, 0);
    path.quadraticBezierTo(size.width * 0.1, size.height * 0.1, 0, size.height);
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
