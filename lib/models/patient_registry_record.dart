import 'patient/patient_profile.dart';

class PatientRegistryRecord {
  final String patientId;
  final String accessCode;
  final String doctorInviteCode;
  final String patientName;
  final int patientAge;
  final String condition;
  final String homeLocation;
  final String? emergencyPhone;
  final String caregiverUid;
  final String caregiverName;
  final String caregiverEmail;
  final List<String> doctorUids;
  final DateTime createdAt;

  const PatientRegistryRecord({
    required this.patientId,
    required this.accessCode,
    required this.doctorInviteCode,
    required this.patientName,
    required this.patientAge,
    required this.condition,
    required this.homeLocation,
    required this.emergencyPhone,
    required this.caregiverUid,
    required this.caregiverName,
    required this.caregiverEmail,
    required this.doctorUids,
    required this.createdAt,
  });

  factory PatientRegistryRecord.fromMap(Map<String, dynamic> map) {
    return PatientRegistryRecord(
      patientId: map['patientId']?.toString() ?? '',
      accessCode: map['accessCode']?.toString() ?? '',
      doctorInviteCode: map['doctorInviteCode']?.toString() ?? '',
      patientName: map['patientName']?.toString() ?? 'Patient',
      patientAge: (map['patientAge'] as num?)?.toInt() ?? 78,
      condition: map['condition']?.toString() ?? 'Care plan pending',
      homeLocation: map['homeLocation']?.toString() ?? 'Home',
      emergencyPhone: map['emergencyPhone']?.toString(),
      caregiverUid: map['caregiverUid']?.toString() ?? '',
      caregiverName: map['caregiverName']?.toString() ?? 'Caregiver',
      caregiverEmail: map['caregiverEmail']?.toString() ?? '',
      doctorUids: List<String>.from(map['doctorUids'] ?? const []),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'accessCode': accessCode,
      'doctorInviteCode': doctorInviteCode,
      'patientName': patientName,
      'patientAge': patientAge,
      'condition': condition,
      'homeLocation': homeLocation,
      'emergencyPhone': emergencyPhone,
      'caregiverUid': caregiverUid,
      'caregiverName': caregiverName,
      'caregiverEmail': caregiverEmail,
      'doctorUids': doctorUids,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  PatientProfile toPatientProfile() {
    return PatientProfile.initial(
      patientId: patientId,
      accessCode: accessCode,
      displayName: patientName,
      age: patientAge,
    ).copyWith(
      homeLabel: homeLocation,
      caregiverName: caregiverName,
      caregiverRelationship: 'caregiver',
      lastKnownContextSummary: 'You are safe at $homeLocation.',
      currentActivity: 'Connected to CareOS',
    );
  }
}
