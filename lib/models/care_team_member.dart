enum CareTeamRole { primaryCaregiver, secondaryCaregiver, doctor, emergencyContact }

extension CareTeamRoleExtension on CareTeamRole {
  String get displayName {
    switch (this) {
      case CareTeamRole.primaryCaregiver: return 'Primary Caregiver';
      case CareTeamRole.secondaryCaregiver: return 'Secondary Caregiver';
      case CareTeamRole.doctor: return 'Doctor / Specialist';
      case CareTeamRole.emergencyContact: return 'Emergency Contact';
    }
  }
}

class CareTeamMember {
  final String id;
  final String patientId;
  final String name;
  final CareTeamRole role;
  final String? phone;
  final String? email;
  final String? notes;
  final DateTime createdAt;

  const CareTeamMember({
    required this.id,
    required this.patientId,
    required this.name,
    required this.role,
    this.phone,
    this.email,
    this.notes,
    required this.createdAt,
  });

  factory CareTeamMember.fromJson(Map<String, dynamic> json) {
    return CareTeamMember(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      name: json['name'] as String,
      role: CareTeamRole.values.byName(json['role'] as String),
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(
        json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'name': name,
        'role': role.name,
        'phone': phone,
        'email': email,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };
}
