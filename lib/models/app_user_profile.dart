enum AppUserRole { caregiver, doctor }

class AppUserProfile {
  final String uid;
  final String email;
  final String displayName;
  final AppUserRole role;
  final List<String> linkedPatientIds;
  final String? activePatientId;
  final DateTime createdAt;

  const AppUserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.linkedPatientIds,
    required this.activePatientId,
    required this.createdAt,
  });

  factory AppUserProfile.fromMap(Map<String, dynamic> map, String uid) {
    return AppUserProfile(
      uid: uid,
      email: map['email']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      role: AppUserRole.values.byName(
        map['role']?.toString() ?? AppUserRole.caregiver.name,
      ),
      linkedPatientIds: List<String>.from(map['linkedPatientIds'] ?? const []),
      activePatientId: map['activePatientId']?.toString(),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role.name,
      'linkedPatientIds': linkedPatientIds,
      'activePatientId': activePatientId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  AppUserProfile copyWith({
    String? displayName,
    List<String>? linkedPatientIds,
    String? activePatientId,
  }) {
    return AppUserProfile(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      role: role,
      linkedPatientIds: linkedPatientIds ?? this.linkedPatientIds,
      activePatientId: activePatientId ?? this.activePatientId,
      createdAt: createdAt,
    );
  }
}
