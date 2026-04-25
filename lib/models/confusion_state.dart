enum ConfusionLevel {
  normal,
  mild,
  high,
}

class ConfusionState {
  final ConfusionLevel level;
  final int score;
  final List<String> reasons;

  const ConfusionState({
    this.level = ConfusionLevel.normal,
    this.score = 0,
    this.reasons = const [],
  });
}
