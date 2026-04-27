import 'package:flutter/widgets.dart';

class CaregiverSession {
  final String caregiverId;
  final String caregiverName;
  final String patientId;
  final String patientName;
  final String condition;
  final String location;
  final String? emergencyPhone;

  const CaregiverSession({
    required this.caregiverId,
    required this.caregiverName,
    required this.patientId,
    required this.patientName,
    required this.condition,
    required this.location,
    this.emergencyPhone,
  });

  factory CaregiverSession.fromRouteArguments(Object? args) {
    if (args is Map) {
      final caregiverName = _coerceText(
        args['caregiverName']?.toString(),
        fallback: 'Primary Caregiver',
      );
      final patientName = _coerceText(
        args['patientName']?.toString(),
        fallback: 'Loved One',
      );
      return CaregiverSession(
        caregiverId: _coerceId(
          args['caregiverId']?.toString(),
          fallbackSource: caregiverName,
          prefix: 'cg',
        ),
        caregiverName: caregiverName,
        patientId: _coerceId(
          args['patientId']?.toString(),
          fallbackSource: patientName,
          prefix: 'pt',
        ),
        patientName: patientName,
        condition: _coerceText(
          args['condition']?.toString(),
          fallback: 'Alzheimer\'s Support Plan',
        ),
        location: _coerceText(
          args['location']?.toString(),
          fallback: 'Home base pending setup',
        ),
        emergencyPhone: args['emergencyPhone']?.toString(),
      );
    }

    return CaregiverSession.fallback();
  }

  factory CaregiverSession.fallback() {
    return const CaregiverSession(
      caregiverId: 'cg_demo',
      caregiverName: 'Primary Caregiver',
      patientId: 'pat_123',
      patientName: 'Eleanor Smith',
      condition: 'Alzheimer\'s Stage 2',
      location: 'Living Room',
      emergencyPhone: null,
    );
  }

  static String _coerceText(String? value, {required String fallback}) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? fallback : trimmed;
  }

  static String _coerceId(
    String? value, {
    required String fallbackSource,
    required String prefix,
  }) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }

    final slug = fallbackSource
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '${prefix}_${slug.isEmpty ? 'demo' : slug}';
  }
}

class CaregiverSessionScope extends InheritedWidget {
  final CaregiverSession session;

  const CaregiverSessionScope({
    super.key,
    required this.session,
    required super.child,
  });

  static CaregiverSession of(BuildContext context) {
    return maybeOf(context)?.session ?? CaregiverSession.fallback();
  }

  static CaregiverSessionScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<CaregiverSessionScope>();
  }

  @override
  bool updateShouldNotify(CaregiverSessionScope oldWidget) {
    return oldWidget.session != session;
  }
}
