import 'dart:math' as math;

import '../models/patient_location_ping.dart';
import '../models/safe_zone.dart';

class CaregiverGeofenceEvaluation {
  final bool insideAnySafeZone;
  final String summary;
  final SafeZone? matchingZone;

  const CaregiverGeofenceEvaluation({
    required this.insideAnySafeZone,
    required this.summary,
    this.matchingZone,
  });
}

class CaregiverGeofenceService {
  CaregiverGeofenceEvaluation evaluate({
    required PatientLocationPing? latestPing,
    required List<SafeZone> safeZones,
  }) {
    if (latestPing == null) {
      return const CaregiverGeofenceEvaluation(
        insideAnySafeZone: false,
        summary: 'No tracked patient location has been received yet.',
      );
    }

    final activeZones = safeZones.where((zone) => zone.isActive).toList();
    if (activeZones.isEmpty) {
      return const CaregiverGeofenceEvaluation(
        insideAnySafeZone: false,
        summary: 'No active safe zones configured.',
      );
    }

    for (final zone in activeZones) {
      final distance = _distanceMeters(
        latestPing.latitude,
        latestPing.longitude,
        zone.latitude,
        zone.longitude,
      );
      if (distance <= zone.radiusMeters) {
        return CaregiverGeofenceEvaluation(
          insideAnySafeZone: true,
          matchingZone: zone,
          summary:
              'Inside ${zone.name} safe zone (${distance.toStringAsFixed(0)}m from center).',
        );
      }
    }

    return CaregiverGeofenceEvaluation(
      insideAnySafeZone: false,
      summary:
          'Tracked location "${latestPing.label}" is outside all active safe zones.',
    );
  }

  double _distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        math.pow(math.sin(dLat / 2), 2).toDouble() +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.pow(math.sin(dLon / 2), 2).toDouble();
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * 0.017453292519943295;
}
