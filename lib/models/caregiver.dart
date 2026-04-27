class Caregiver {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String relationToPatient;

  const Caregiver({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.relationToPatient,
  });

  factory Caregiver.fromJson(Map<String, dynamic> json) {
    return Caregiver(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String,
      relationToPatient: json['relationToPatient'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phoneNumber': phoneNumber,
        'relationToPatient': relationToPatient,
      };
}
