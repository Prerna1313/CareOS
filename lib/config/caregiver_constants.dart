class CaregiverConstants {
  // Inactivity Thresholds (in minutes)
  static const int inactivityMediumThreshold = 120; // 2 hours
  static const int inactivityHighThreshold = 240; // 4 hours
  static const int inactivityCriticalThreshold = 480; // 8 hours (sleep exception logic should apply later)

  // Confusion Detection Feature Weights
  static const double weightInactivity = 0.20;
  static const double weightMissedReminder = 0.15;
  static const double weightRepeatedAction = 0.15;
  static const double weightTextCoherence = 0.15;
  static const double weightLocationAnomaly = 0.15;
  static const double weightRoutineDeviation = 0.10;
  static const double weightVoicePause = 0.10;

  // Confusion Risk Thresholds (Score out of 100)
  static const double confusionStableMax = 20.0;
  static const double confusionMildMax = 45.0;
  static const double confusionModerateMax = 75.0;
  // Above 75 is high

  // Safe Zone Constants
  static const double defaultSafeZoneRadiusMeters = 50.0;
  static const double maxSafeZoneRadiusMeters = 5000.0;
}
