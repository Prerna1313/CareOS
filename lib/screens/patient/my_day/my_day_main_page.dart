import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_colors.dart';
import '../../../../models/my_day/daily_checkin_entry.dart';
import '../../../../providers/my_day_provider.dart';
import '../../../../providers/patient_session_provider.dart';
import 'daily_history_detail_screen.dart';

const _myDayBackground = Color(0xFFF3F8F1);
const _myDaySurface = Color(0xFFFFFDF8);
const _myDayAccent = Color(0xFF5E8B6F);
const _myDayAccentSoft = Color(0xFFDCEBDE);
const _myDayTextSoft = Color(0xFF5F6F61);

class MyDayMainPage extends StatelessWidget {
  const MyDayMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final provider = context.watch<MyDayProvider>();
    final patientProfile = context.watch<PatientSessionProvider>().profile;
    final displayName = patientProfile?.displayName ?? 'Friend';
    final greeting = _greetingForTime();

    return Scaffold(
      backgroundColor: _myDayBackground,
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 28.0,
              vertical: 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 64),
                Text(
                  greeting,
                  style: textTheme.displaySmall?.copyWith(
                    color: _myDayTextSoft,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  displayName,
                  style: textTheme.displayMedium?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.2,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Your memories are safe with me.\nLet's record your highlights.",
                  style: textTheme.titleLarge?.copyWith(
                    color: _myDayTextSoft,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 32),
                _TodayStatusCard(provider: provider),
                if (provider.yesterdayEntry != null) ...[
                  const SizedBox(height: 20),
                  _RecallPromptCard(entry: provider.yesterdayEntry!),
                ],
                const SizedBox(height: 24),
                _MoodSelector(provider: provider),
                const SizedBox(height: 24),
                _ReflectionActionCard(provider: provider),
                const SizedBox(height: 32),

                if (provider.todayEntry != null &&
                    provider.todayEntry!.summary.isNotEmpty) ...[
                  _TodaySummaryCard(summary: provider.todayEntry!.summary),
                  const SizedBox(height: 32),
                ],

                // Diary Sections
                _DiarySection(
                  title: "Anything else about your day?",
                  hint: provider.todayEntry?.textField1.isNotEmpty == true
                      ? provider.todayEntry!.textField1
                      : "Write down your thoughts...",
                  icon: Icons.edit_note_rounded,
                  onTap: () => _showDiaryInput(
                    context,
                    "Anything else about your day?",
                    provider.todayEntry?.textField1 ?? "",
                    (val) {
                      provider.updateTextField1(val);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                _DiarySection(
                  title: "Something important to add?",
                  hint: provider.todayEntry?.textField2.isNotEmpty == true
                      ? provider.todayEntry!.textField2
                      : "A note for later...",
                  icon: Icons.priority_high_rounded,
                  onTap: () => _showDiaryInput(
                    context,
                    "Something important to add?",
                    provider.todayEntry?.textField2 ?? "",
                    (val) {
                      provider.updateTextField2(val);
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // Voice Diary Section
                _VoiceDiarySection(textTheme: textTheme, provider: provider),
                const SizedBox(height: 32),

                // History Section
                Text(
                  "Past Entries",
                  style: textTheme.titleLarge?.copyWith(
                    color: AppColors.onBackground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                const _HistoryList(),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _greetingForTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  void _showDiaryInput(
    BuildContext context,
    String title,
    String initialValue,
    Function(String) onSave,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _DiaryInputOverlay(
          title: title,
          initialValue: initialValue,
          onSave: onSave,
        );
      },
    );
  }
}

class _TodayStatusCard extends StatelessWidget {
  final MyDayProvider provider;

  const _TodayStatusCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final answered = provider.answeredQuestionCount;
    final total = provider.totalQuestionCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _myDaySurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _myDayAccentSoft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _myDayAccentSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.self_improvement_rounded,
                  color: _myDayAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Check-In',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      provider.completionLabel,
                      style: textTheme.bodyMedium?.copyWith(
                        color: _myDayTextSoft,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$answered/$total',
                style: textTheme.titleMedium?.copyWith(
                  color: _myDayAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: provider.completionProgress,
              minHeight: 10,
              backgroundColor: _myDayAccentSoft,
              color: _myDayAccent,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            provider.isChatCompleted
                ? 'Your guided reflection is complete for today.'
                : provider.hasDraftContent
                ? 'You have started saving thoughts for today. You can continue anytime.'
                : 'Start a gentle guided reflection for today.',
            style: textTheme.bodyMedium?.copyWith(
              color: _myDayTextSoft,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecallPromptCard extends StatelessWidget {
  final DailyCheckinEntry entry;

  const _RecallPromptCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5EB),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recall Prompt',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'What did you do yesterday?',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            entry.summary.isNotEmpty
                ? entry.summary
                : 'You made a memory yesterday. Try to remember one special part of it.',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodSelector extends StatelessWidget {
  final MyDayProvider provider;

  const _MoodSelector({required this.provider});

  static const moods = <({String label, IconData icon})>[
    (label: 'Positive', icon: Icons.sentiment_satisfied_alt_rounded),
    (label: 'Neutral', icon: Icons.sentiment_neutral_rounded),
    (label: 'Low', icon: Icons.sentiment_dissatisfied_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selectedMood = provider.todayEntry?.mood ?? 'Neutral';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How do you feel today?',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: moods.map((mood) {
            final isSelected = selectedMood == mood.label;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: mood.label == moods.last.label ? 0 : 12,
                ),
                child: InkWell(
                  onTap: () => provider.updateMood(mood.label),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _myDayAccentSoft
                          : _myDaySurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? _myDayAccent
                            : const Color(0xFFC8D7C8),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          mood.icon,
                          color: isSelected
                              ? _myDayAccent
                              : AppColors.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          mood.label,
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? _myDayAccent
                                : _myDayTextSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ReflectionActionCard extends StatelessWidget {
  final MyDayProvider provider;

  const _ReflectionActionCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final buttonLabel = provider.isChatCompleted
        ? 'Reflect Again'
        : provider.hasDraftContent
        ? 'Continue Reflection'
        : 'Start Reflection';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFDDEBDF),
            const Color(0xFFF8FBF6),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Guided Reflection',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Answer simple questions to capture today in a calm, easy way.',
            style: textTheme.bodyMedium?.copyWith(
              color: _myDayTextSoft,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    if (provider.isChatCompleted) {
                      provider.restartTodayReflection();
                    }
                    provider.resumeOrStartChat();
                  },
                  icon: const Icon(Icons.chat_bubble_rounded),
                  label: Text(buttonLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiarySection extends StatelessWidget {
  final String title;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;

  const _DiarySection({
    required this.title,
    required this.hint,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _myDaySurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _myDayAccentSoft),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _myDayAccentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _myDayAccent, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _myDayTextSoft,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaryInputOverlay extends StatefulWidget {
  final String title;
  final String initialValue;
  final Function(String) onSave;

  const _DiaryInputOverlay({
    required this.title,
    required this.initialValue,
    required this.onSave,
  });

  @override
  State<_DiaryInputOverlay> createState() => _DiaryInputOverlayState();
}

class _DiaryInputOverlayState extends State<_DiaryInputOverlay> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _myDayBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: AppColors.onBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.check_rounded,
              color: _myDayAccent,
              size: 32,
            ),
            onPressed: () {
              widget.onSave(_controller.text);
              context.read<MyDayProvider>().saveTodayEntry();
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("Entry saved")));
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.onBackground,
              size: 28,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: TextField(
          controller: _controller,
          maxLines: null,
          autofocus: true,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 20),
          decoration: const InputDecoration(
            hintText: "Start writing here...",
            border: InputBorder.none,
          ),
          onChanged: (val) => widget.onSave(val),
        ),
      ),
    );
  }
}

class _VoiceDiarySection extends StatelessWidget {
  final TextTheme textTheme;
  final MyDayProvider provider;
  const _VoiceDiarySection({required this.textTheme, required this.provider});

  @override
  Widget build(BuildContext context) {
    final hasVoiceNote = provider.todayEntry?.voiceNote != null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFDCEBDD),
            const Color(0xFFF8FBF7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            provider.isRecording
                ? Icons.settings_voice_rounded
                : Icons.mic_rounded,
            size: 48,
            color: provider.isRecording ? AppColors.error : _myDayAccent,
          ),
          const SizedBox(height: 16),
          Text(
            "Voice Diary",
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            provider.isRecording
                ? "Recording your voice... Tap stop when done."
                : hasVoiceNote
                ? "You have recorded a voice note for today."
                : "Record a voice note about your day",
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (hasVoiceNote && !provider.isRecording) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.play_circle_fill_rounded,
                    color: _myDayAccent,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Recording (${provider.todayEntry!.voiceNote!.durationSeconds}s)",
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                    onPressed: () => provider.deleteVoiceNote(),
                  ),
                ],
              ),
            ),
            if (provider.todayEntry?.voiceNote?.transcription != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryContainer.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.text_fields_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Transcription",
                          style: textTheme.labelLarge?.copyWith(
                            color: _myDayAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.todayEntry!.voiceNote!.transcription!,
                      style: textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            ElevatedButton.icon(
              onPressed: () => provider.isRecording
                  ? provider.stopRecording()
                  : provider.startRecording(),
              icon: Icon(
                provider.isRecording
                    ? Icons.stop_rounded
                    : Icons.fiber_manual_record_rounded,
                color: Colors.red,
              ),
              label: Text(
                provider.isRecording ? "Stop Recording" : "Start Recording",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.onSurface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList();

  @override
  Widget build(BuildContext context) {
    final history = context.watch<MyDayProvider>().history;

    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        decoration: BoxDecoration(
          color: _myDaySurface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.history_rounded,
              size: 48,
              color: AppColors.outline,
            ),
            const SizedBox(height: 16),
            Text(
              "No entries yet",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: _myDayTextSoft),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: history.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = history[index];
        return ListTile(
          tileColor: _myDaySurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: const Icon(
            Icons.calendar_month_rounded,
            color: _myDayAccent,
          ),
          title: Text(DateFormat('EEEE, MMM d').format(entry.date)),
          subtitle: Text(
            entry.summary.isNotEmpty ? entry.summary : "No summary available",
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DailyHistoryDetailScreen(entry: entry),
              ),
            );
          },
        );
      },
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  final String summary;

  const _TodaySummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9), // Light green background
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFC5E1A5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF558B2F),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                "Today's Reflection",
                style: textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF558B2F),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            summary,
            style: textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF2D2D2D),
              height: 1.6,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}
