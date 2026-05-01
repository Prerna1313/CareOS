class PatientProfile {
  final String patientId;
  final String accessCode;
  final String displayName;
  final int age;
  final String homeLabel;
  final String city;
  final String caregiverName;
  final String caregiverRelationship;
  final List<String> importantItems;
  final bool autoOrientationEnabled;
  final bool voicePromptsEnabled;
  final bool liveLocationSharingEnabled;
  final double textScaleFactor;
  final bool highContrastEnabled;
  final bool reducedMotionEnabled;
  final bool simpleLayoutEnabled;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final String lastKnownContextSummary;
  final String currentActivity;

  const PatientProfile({
    required this.patientId,
    required this.accessCode,
    required this.displayName,
    required this.age,
    required this.homeLabel,
    required this.city,
    required this.caregiverName,
    required this.caregiverRelationship,
    required this.importantItems,
    required this.autoOrientationEnabled,
    required this.voicePromptsEnabled,
    required this.liveLocationSharingEnabled,
    required this.textScaleFactor,
    required this.highContrastEnabled,
    required this.reducedMotionEnabled,
    required this.simpleLayoutEnabled,
    required this.createdAt,
    required this.lastActiveAt,
    required this.lastKnownContextSummary,
    required this.currentActivity,
  });

  factory PatientProfile.initial({
    required String patientId,
    required String accessCode,
    String? displayName,
    int age = 78,
  }) {
    final now = DateTime.now();
    return PatientProfile(
      patientId: patientId,
      accessCode: accessCode,
      displayName: displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : 'Friend',
      age: age,
      homeLabel: 'Home',
      city: 'your city',
      caregiverName: 'Rahul',
      caregiverRelationship: 'son',
      importantItems: const ['glasses', 'diary', 'medicine'],
      autoOrientationEnabled: true,
      voicePromptsEnabled: true,
      liveLocationSharingEnabled: false,
      textScaleFactor: 1.0,
      highContrastEnabled: false,
      reducedMotionEnabled: false,
      simpleLayoutEnabled: false,
      createdAt: now,
      lastActiveAt: now,
      lastKnownContextSummary: 'You are safe at home.',
      currentActivity: 'Settling in',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'accessCode': accessCode,
      'displayName': displayName,
      'age': age,
      'homeLabel': homeLabel,
      'city': city,
      'caregiverName': caregiverName,
      'caregiverRelationship': caregiverRelationship,
      'importantItems': importantItems,
      'autoOrientationEnabled': autoOrientationEnabled,
      'voicePromptsEnabled': voicePromptsEnabled,
      'liveLocationSharingEnabled': liveLocationSharingEnabled,
      'textScaleFactor': textScaleFactor,
      'highContrastEnabled': highContrastEnabled,
      'reducedMotionEnabled': reducedMotionEnabled,
      'simpleLayoutEnabled': simpleLayoutEnabled,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'lastKnownContextSummary': lastKnownContextSummary,
      'currentActivity': currentActivity,
    };
  }

  factory PatientProfile.fromMap(Map<dynamic, dynamic> map) {
    final now = DateTime.now();
    DateTime parseDate(dynamic value, DateTime fallback) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value) ?? fallback;
      }
      return fallback;
    }

    return PatientProfile(
      patientId: map['patientId']?.toString() ?? '',
      accessCode: map['accessCode']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? 'Friend',
      age: (map['age'] as num?)?.toInt() ?? 78,
      homeLabel: map['homeLabel']?.toString() ?? 'Home',
      city: map['city']?.toString() ?? 'your city',
      caregiverName: map['caregiverName']?.toString() ?? 'Rahul',
      caregiverRelationship: map['caregiverRelationship']?.toString() ?? 'son',
      importantItems: List<String>.from(
        map['importantItems'] ?? const ['glasses', 'diary', 'medicine'],
      ),
      autoOrientationEnabled: map['autoOrientationEnabled'] as bool? ?? true,
      voicePromptsEnabled: map['voicePromptsEnabled'] as bool? ?? true,
      liveLocationSharingEnabled:
          map['liveLocationSharingEnabled'] as bool? ?? false,
      textScaleFactor: (map['textScaleFactor'] as num?)?.toDouble() ?? 1.0,
      highContrastEnabled: map['highContrastEnabled'] as bool? ?? false,
      reducedMotionEnabled: map['reducedMotionEnabled'] as bool? ?? false,
      simpleLayoutEnabled: map['simpleLayoutEnabled'] as bool? ?? false,
      createdAt: parseDate(map['createdAt'], now),
      lastActiveAt: parseDate(map['lastActiveAt'], now),
      lastKnownContextSummary:
          map['lastKnownContextSummary']?.toString() ?? 'You are safe at home.',
      currentActivity: map['currentActivity']?.toString() ?? 'Settling in',
    );
  }

  PatientProfile copyWith({
    String? patientId,
    String? accessCode,
    String? displayName,
    int? age,
    String? homeLabel,
    String? city,
    String? caregiverName,
    String? caregiverRelationship,
    List<String>? importantItems,
    bool? autoOrientationEnabled,
    bool? voicePromptsEnabled,
    bool? liveLocationSharingEnabled,
    double? textScaleFactor,
    bool? highContrastEnabled,
    bool? reducedMotionEnabled,
    bool? simpleLayoutEnabled,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    String? lastKnownContextSummary,
    String? currentActivity,
  }) {
    return PatientProfile(
      patientId: patientId ?? this.patientId,
      accessCode: accessCode ?? this.accessCode,
      displayName: displayName ?? this.displayName,
      age: age ?? this.age,
      homeLabel: homeLabel ?? this.homeLabel,
      city: city ?? this.city,
      caregiverName: caregiverName ?? this.caregiverName,
      caregiverRelationship:
          caregiverRelationship ?? this.caregiverRelationship,
      importantItems: importantItems ?? this.importantItems,
      autoOrientationEnabled:
          autoOrientationEnabled ?? this.autoOrientationEnabled,
      voicePromptsEnabled: voicePromptsEnabled ?? this.voicePromptsEnabled,
      liveLocationSharingEnabled:
          liveLocationSharingEnabled ?? this.liveLocationSharingEnabled,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
      highContrastEnabled: highContrastEnabled ?? this.highContrastEnabled,
      reducedMotionEnabled: reducedMotionEnabled ?? this.reducedMotionEnabled,
      simpleLayoutEnabled: simpleLayoutEnabled ?? this.simpleLayoutEnabled,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      lastKnownContextSummary:
          lastKnownContextSummary ?? this.lastKnownContextSummary,
      currentActivity: currentActivity ?? this.currentActivity,
    );
  }
}
