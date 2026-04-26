import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class CognitiveActivitiesScreen extends StatefulWidget {
  const CognitiveActivitiesScreen({super.key});

  @override
  State<CognitiveActivitiesScreen> createState() =>
      _CognitiveActivitiesScreenState();
}

class _CognitiveActivitiesScreenState extends State<CognitiveActivitiesScreen> {
  int _selectedCategoryIndex = 0;
  final Map<_ActivityCategoryType, int> _currentQuestionIndex = {
    _ActivityCategoryType.nameMatch: 0,
    _ActivityCategoryType.numberGame: 0,
    _ActivityCategoryType.fillBlank: 0,
  };
  final Map<_ActivityCategoryType, int> _scores = {
    _ActivityCategoryType.nameMatch: 0,
    _ActivityCategoryType.numberGame: 0,
    _ActivityCategoryType.fillBlank: 0,
  };
  final Set<String> _answeredPromptIds = <String>{};
  String? _selectedOption;
  bool? _lastAnswerCorrect;

  late final List<_ActivityCategory> _categories = [
    _ActivityCategory(
      type: _ActivityCategoryType.nameMatch,
      title: 'Name Match',
      subtitle: 'Connect familiar people with their role.',
      accent: const Color(0xFF4CAF50),
      icon: Icons.family_restroom_rounded,
      prompts: const [
        _ActivityPrompt(
          id: 'name_1',
          prompt: 'Rahul',
          helper: 'Who is Rahul to you?',
          options: ['Son', 'Doctor', 'Neighbor'],
          answer: 'Son',
        ),
        _ActivityPrompt(
          id: 'name_2',
          prompt: 'Anita',
          helper: 'Choose the right relationship.',
          options: ['Friend', 'Daughter', 'Nurse'],
          answer: 'Daughter',
        ),
        _ActivityPrompt(
          id: 'name_3',
          prompt: 'Meera',
          helper: 'Who is Meera?',
          options: ['Sister', 'Doctor', 'Driver'],
          answer: 'Sister',
        ),
      ],
    ),
    _ActivityCategory(
      type: _ActivityCategoryType.numberGame,
      title: 'Number Flow',
      subtitle: 'Continue a calm number pattern.',
      accent: const Color(0xFFFB8C00),
      icon: Icons.pin_rounded,
      prompts: const [
        _ActivityPrompt(
          id: 'number_1',
          prompt: '2, 4, 6, ?',
          helper: 'Tap the next number.',
          options: ['7', '8', '9'],
          answer: '8',
        ),
        _ActivityPrompt(
          id: 'number_2',
          prompt: '10, 8, 6, ?',
          helper: 'The pattern is going down by 2.',
          options: ['4', '5', '7'],
          answer: '4',
        ),
        _ActivityPrompt(
          id: 'number_3',
          prompt: '5, 10, 15, ?',
          helper: 'Look for a simple pattern.',
          options: ['18', '20', '25'],
          answer: '20',
        ),
      ],
    ),
    _ActivityCategory(
      type: _ActivityCategoryType.fillBlank,
      title: 'Finish the Thought',
      subtitle: 'Choose the word that fits best.',
      accent: const Color(0xFF5C6BC0),
      icon: Icons.auto_stories_rounded,
      prompts: const [
        _ActivityPrompt(
          id: 'blank_1',
          prompt: 'Take your ____ with water.',
          helper: 'Pick the helpful word.',
          options: ['medicine', 'shoes', 'blanket'],
          answer: 'medicine',
        ),
        _ActivityPrompt(
          id: 'blank_2',
          prompt: 'You are safe at ____.',
          helper: 'Choose where you are grounded.',
          options: ['home', 'school', 'market'],
          answer: 'home',
        ),
        _ActivityPrompt(
          id: 'blank_3',
          prompt: 'A short ____ can help you feel fresh.',
          helper: 'Pick a gentle activity.',
          options: ['walk', 'storm', 'alarm'],
          answer: 'walk',
        ),
      ],
    ),
  ];

  _ActivityCategory get _selectedCategory => _categories[_selectedCategoryIndex];

  _ActivityPrompt get _currentPrompt {
    final index = _currentQuestionIndex[_selectedCategory.type] ?? 0;
    final prompts = _selectedCategory.prompts;
    return prompts[index.clamp(0, prompts.length - 1)];
  }

  int get _completedCategoryCount {
    return _categories.where((category) => _isCategoryCompleted(category)).length;
  }

  double get _completionProgress => _completedCategoryCount / _categories.length;

  bool _isCategoryCompleted(_ActivityCategory category) {
    return (_currentQuestionIndex[category.type] ?? 0) >= category.prompts.length;
  }

  int _scoreFor(_ActivityCategoryType type) => _scores[type] ?? 0;

  void _selectCategory(int index) {
    setState(() {
      _selectedCategoryIndex = index;
      _selectedOption = null;
      _lastAnswerCorrect = null;
    });
  }

  void _submitAnswer(String option) {
    final prompt = _currentPrompt;
    final type = _selectedCategory.type;
    if (_answeredPromptIds.contains(prompt.id)) return;

    final isCorrect = option == prompt.answer;

    setState(() {
      _selectedOption = option;
      _lastAnswerCorrect = isCorrect;
      _answeredPromptIds.add(prompt.id);
      if (isCorrect) {
        _scores[type] = (_scores[type] ?? 0) + 1;
      }
    });
  }

  void _goToNextPrompt() {
    final type = _selectedCategory.type;
    final nextIndex = (_currentQuestionIndex[type] ?? 0) + 1;

    setState(() {
      _currentQuestionIndex[type] = nextIndex;
      _selectedOption = null;
      _lastAnswerCorrect = null;
    });

    if (_isCategoryCompleted(_selectedCategory)) {
      final nextOpenIndex = _categories.indexWhere(
        (category) => !_isCategoryCompleted(category),
      );
      if (nextOpenIndex != -1) {
        _selectCategory(nextOpenIndex);
      }
    }
  }

  void _resetCategory(_ActivityCategory category) {
    setState(() {
      _currentQuestionIndex[category.type] = 0;
      _scores[category.type] = 0;
      _answeredPromptIds.removeWhere(
        (id) => category.prompts.any((prompt) => prompt.id == id),
      );
      if (_selectedCategory.type == category.type) {
        _selectedOption = null;
        _lastAnswerCorrect = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final completed = _completedCategoryCount;
    final currentCategory = _selectedCategory;
    final currentPrompt = _currentPrompt;
    final currentIndex = _currentQuestionIndex[currentCategory.type] ?? 0;
    final promptNumber = (currentIndex + 1).clamp(1, currentCategory.prompts.length);
    final categoryFinished = _isCategoryCompleted(currentCategory);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Mini Activities',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActivitiesHeroCard(
                progress: _completionProgress,
                completedCount: completed,
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth > 520
                      ? 188.0
                      : constraints.maxWidth > 390
                          ? 176.0
                          : 162.0;
                  return SizedBox(
                    height: 148,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, unusedIndex) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = index == _selectedCategoryIndex;
                        return _CategoryCard(
                          width: cardWidth,
                          category: category,
                          isSelected: isSelected,
                          scoreLabel:
                              '${_scoreFor(category.type)} / ${category.prompts.length}',
                          isCompleted: _isCategoryCompleted(category),
                          onTap: () => _selectCategory(index),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),
              if (!categoryFinished)
                _PromptPanel(
                  category: currentCategory,
                  prompt: currentPrompt,
                  promptNumber: promptNumber,
                  totalPrompts: currentCategory.prompts.length,
                  selectedOption: _selectedOption,
                  lastAnswerCorrect: _lastAnswerCorrect,
                  onSelect: _selectedOption == null ? _submitAnswer : null,
                  onContinue: _selectedOption != null ? _goToNextPrompt : null,
                )
              else
                _CompletedPanel(
                  category: currentCategory,
                  score: _scoreFor(currentCategory.type),
                  total: currentCategory.prompts.length,
                  onRestart: () => _resetCategory(currentCategory),
                ),
              const SizedBox(height: 22),
              _ActivitySummaryCard(
                categories: _categories,
                scores: _scores,
                completedCount: completed,
                onRestartCategory: _resetCategory,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivitiesHeroCard extends StatelessWidget {
  final double progress;
  final int completedCount;

  const _ActivitiesHeroCard({
    required this.progress,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.psychology_alt_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Let\'s do one calm activity at a time.',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'These short activities help with recall, attention, and familiar daily patterns.',
            style: textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF2E7D32),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.white.withValues(alpha: 0.55),
              color: const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$completedCount of 3 activity groups completed today',
            style: textTheme.labelLarge?.copyWith(
              color: const Color(0xFF2E7D32),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final double width;
  final _ActivityCategory category;
  final bool isSelected;
  final bool isCompleted;
  final String scoreLabel;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.width,
    required this.category,
    required this.isSelected,
    required this.isCompleted,
    required this.scoreLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: width,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? category.accent.withValues(alpha: 0.16)
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? category.accent
                : AppColors.outlineVariant.withValues(alpha: 0.28),
            width: isSelected ? 2 : 1,
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
                    color: category.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(category.icon, color: category.accent),
                ),
                const Spacer(),
                if (isCompleted)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF43A047),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              category.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              scoreLabel,
              style: textTheme.labelLarge?.copyWith(
                color: category.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptPanel extends StatelessWidget {
  final _ActivityCategory category;
  final _ActivityPrompt prompt;
  final int promptNumber;
  final int totalPrompts;
  final String? selectedOption;
  final bool? lastAnswerCorrect;
  final ValueChanged<String>? onSelect;
  final VoidCallback? onContinue;

  const _PromptPanel({
    required this.category,
    required this.prompt,
    required this.promptNumber,
    required this.totalPrompts,
    required this.selectedOption,
    required this.lastAnswerCorrect,
    required this.onSelect,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: category.accent.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: category.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${category.title} • $promptNumber/$totalPrompts',
                  style: textTheme.labelLarge?.copyWith(
                    color: category.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            prompt.prompt,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            prompt.helper,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          ...prompt.options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OptionTile(
                label: option,
                accent: category.accent,
                isSelected: selectedOption == option,
                isCorrectAnswer: selectedOption != null && option == prompt.answer,
                isWrongSelection:
                    selectedOption == option && option != prompt.answer,
                onTap: onSelect == null ? null : () => onSelect!(option),
              ),
            ),
          ),
          if (selectedOption != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (lastAnswerCorrect == true
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFF3E0))
                    .withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    lastAnswerCorrect == true
                        ? Icons.check_circle_rounded
                        : Icons.lightbulb_rounded,
                    color: lastAnswerCorrect == true
                        ? const Color(0xFF43A047)
                        : const Color(0xFFEF6C00),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lastAnswerCorrect == true
                          ? 'Nice work. That answer is correct.'
                          : 'Good try. The helpful answer is "${prompt.answer}".',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Continue'),
                style: FilledButton.styleFrom(
                  backgroundColor: category.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final Color accent;
  final bool isSelected;
  final bool isCorrectAnswer;
  final bool isWrongSelection;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.label,
    required this.accent,
    required this.isSelected,
    required this.isCorrectAnswer,
    required this.isWrongSelection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor = AppColors.surfaceContainerLow;
    Color borderColor = AppColors.outlineVariant.withValues(alpha: 0.28);
    IconData icon = Icons.circle_outlined;

    if (isCorrectAnswer && isSelected) {
      backgroundColor = const Color(0xFFE8F5E9);
      borderColor = const Color(0xFF43A047);
      icon = Icons.check_circle_rounded;
    } else if (isWrongSelection) {
      backgroundColor = const Color(0xFFFFF3E0);
      borderColor = const Color(0xFFEF6C00);
      icon = Icons.cancel_rounded;
    } else if (isSelected) {
      backgroundColor = accent.withValues(alpha: 0.12);
      borderColor = accent;
      icon = Icons.radio_button_checked_rounded;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.6),
          ),
          child: Row(
            children: [
              Icon(icon, color: borderColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletedPanel extends StatelessWidget {
  final _ActivityCategory category;
  final int score;
  final int total;
  final VoidCallback onRestart;

  const _CompletedPanel({
    required this.category,
    required this.score,
    required this.total,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: category.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.celebration_rounded, color: category.accent),
              const SizedBox(width: 10),
              Text(
                '${category.title} complete',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'You finished this activity with a score of $score out of $total.',
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onRestart,
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Play Again'),
          ),
        ],
      ),
    );
  }
}

class _ActivitySummaryCard extends StatelessWidget {
  final List<_ActivityCategory> categories;
  final Map<_ActivityCategoryType, int> scores;
  final int completedCount;
  final ValueChanged<_ActivityCategory> onRestartCategory;

  const _ActivitySummaryCard({
    required this.categories,
    required this.scores,
    required this.completedCount,
    required this.onRestartCategory,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s activity summary',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Completed groups: $completedCount of ${categories.length}',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          ...categories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(category.icon, color: category.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      category.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${scores[category.type] ?? 0}/${category.prompts.length}',
                    style: textTheme.labelLarge?.copyWith(
                      color: category.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => onRestartCategory(category),
                    child: const Text('Restart'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ActivityCategoryType { nameMatch, numberGame, fillBlank }

class _ActivityCategory {
  final _ActivityCategoryType type;
  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final List<_ActivityPrompt> prompts;

  const _ActivityCategory({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.prompts,
  });
}

class _ActivityPrompt {
  final String id;
  final String prompt;
  final String helper;
  final List<String> options;
  final String answer;

  const _ActivityPrompt({
    required this.id,
    required this.prompt,
    required this.helper,
    required this.options,
    required this.answer,
  });
}
