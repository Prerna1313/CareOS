import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class CognitiveActivitiesScreen extends StatefulWidget {
  const CognitiveActivitiesScreen({super.key});

  @override
  State<CognitiveActivitiesScreen> createState() =>
      _CognitiveActivitiesScreenState();
}

class _CognitiveActivitiesScreenState extends State<CognitiveActivitiesScreen> {
  int _nameMatchScore = 0;
  int _numberScore = 0;
  int _blankScore = 0;
  bool _nameMatchDone = false;
  bool _numberDone = false;
  bool _blankDone = false;

  final List<_NameMatchPrompt> _namePrompts = const [
    _NameMatchPrompt(
      person: 'Rahul',
      options: ['Son', 'Doctor', 'Neighbor'],
      correctAnswer: 'Son',
    ),
    _NameMatchPrompt(
      person: 'Anita',
      options: ['Friend', 'Daughter', 'Nurse'],
      correctAnswer: 'Daughter',
    ),
  ];

  final List<_NumberPrompt> _numberPrompts = const [
    _NumberPrompt(
      sequence: '2, 4, 6, ?',
      options: ['7', '8', '9'],
      answer: '8',
    ),
    _NumberPrompt(
      sequence: '10, 8, 6, ?',
      options: ['4', '5', '7'],
      answer: '4',
    ),
  ];

  final List<_BlankPrompt> _blankPrompts = const [
    _BlankPrompt(
      sentence: 'Take your ____ with water.',
      options: ['medicine', 'shoes', 'blanket'],
      answer: 'medicine',
    ),
    _BlankPrompt(
      sentence: 'You are safe at ____.',
      options: ['home', 'school', 'market'],
      answer: 'home',
    ),
  ];

  double get _completionProgress {
    final completed = [
      _nameMatchDone,
      _numberDone,
      _blankDone,
    ].where((value) => value).length;
    return completed / 3;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBright,
        title: Text(
          'Cognitive Activities',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gentle activities for focus and recall',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Take your time. You can do one activity or finish all three.',
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _completionProgress,
                minHeight: 10,
                backgroundColor: AppColors.surfaceContainerHigh,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 28),
            _ActivityCard(
              title: 'Name Matching',
              subtitle: 'Match familiar people to their relationship.',
              scoreLabel: '$_nameMatchScore / ${_namePrompts.length}',
              child: Column(
                children: _namePrompts
                    .map(
                      (prompt) => _ChoicePromptCard(
                        prompt: prompt.person,
                        options: prompt.options,
                        onSelected: (value) {
                          final correct = value == prompt.correctAnswer;
                          if (correct) {
                            _nameMatchScore++;
                          }
                          if (mounted) {
                            setState(() {
                              _nameMatchDone = true;
                            });
                          }
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
            _ActivityCard(
              title: 'Number Game',
              subtitle: 'Pick the next number in the sequence.',
              scoreLabel: '$_numberScore / ${_numberPrompts.length}',
              child: Column(
                children: _numberPrompts
                    .map(
                      (prompt) => _ChoicePromptCard(
                        prompt: prompt.sequence,
                        options: prompt.options,
                        onSelected: (value) {
                          final correct = value == prompt.answer;
                          if (correct) {
                            _numberScore++;
                          }
                          if (mounted) {
                            setState(() {
                              _numberDone = true;
                            });
                          }
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
            _ActivityCard(
              title: 'Fill in the Blank',
              subtitle: 'Choose the word that completes the sentence.',
              scoreLabel: '$_blankScore / ${_blankPrompts.length}',
              child: Column(
                children: _blankPrompts
                    .map(
                      (prompt) => _ChoicePromptCard(
                        prompt: prompt.sentence,
                        options: prompt.options,
                        onSelected: (value) {
                          final correct = value == prompt.answer;
                          if (correct) {
                            _blankScore++;
                          }
                          if (mounted) {
                            setState(() {
                              _blankDone = true;
                            });
                          }
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String scoreLabel;
  final Widget child;

  const _ActivityCard({
    required this.title,
    required this.subtitle,
    required this.scoreLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                scoreLabel,
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ChoicePromptCard extends StatefulWidget {
  final String prompt;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const _ChoicePromptCard({
    required this.prompt,
    required this.options,
    required this.onSelected,
  });

  @override
  State<_ChoicePromptCard> createState() => _ChoicePromptCardState();
}

class _ChoicePromptCardState extends State<_ChoicePromptCard> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.prompt,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.options.map((option) {
              final isSelected = option == _selected;
              return ChoiceChip(
                label: Text(option),
                selected: isSelected,
                onSelected: _selected == null
                    ? (_) {
                        setState(() {
                          _selected = option;
                        });
                        widget.onSelected(option);
                      }
                    : null,
                selectedColor: AppColors.primaryContainer,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _NameMatchPrompt {
  final String person;
  final List<String> options;
  final String correctAnswer;

  const _NameMatchPrompt({
    required this.person,
    required this.options,
    required this.correctAnswer,
  });
}

class _NumberPrompt {
  final String sequence;
  final List<String> options;
  final String answer;

  const _NumberPrompt({
    required this.sequence,
    required this.options,
    required this.answer,
  });
}

class _BlankPrompt {
  final String sentence;
  final List<String> options;
  final String answer;

  const _BlankPrompt({
    required this.sentence,
    required this.options,
    required this.answer,
  });
}
