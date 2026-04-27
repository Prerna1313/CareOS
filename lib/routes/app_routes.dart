import 'package:flutter/material.dart';
import '../screens/landing/landing_screen.dart';
import '../screens/caregiver/caregiver_login_screen.dart';
import '../screens/caregiver/caregiver_shell.dart';
import '../screens/caregiver/onboarding/caregiver_onboarding_flow.dart';
import '../screens/patient/patient_access_screen.dart';
import '../screens/patient/advanced_vision_report_screen.dart';
import '../screens/patient/dashboard/patient_dashboard_screen.dart';
import '../screens/patient/event_history_screen.dart';
import '../screens/patient/find_item_screen.dart';
import '../screens/patient/observation_history_screen.dart';
import '../screens/patient/orientation_support_screen.dart';
import '../screens/patient/patient_settings_screen.dart';
import '../screens/patient/activities/cognitive_activities_screen.dart';
import '../screens/patient/companion/patient_companion_screen.dart';
import '../screens/doctor/doctor_login_screen.dart';
import '../screens/doctor/dashboard/doctor_dashboard_screen.dart';

/// Centralized route definitions for CareOS.
class AppRoutes {
  AppRoutes._();

  // ── Route names ──
  static const String landing = '/';
  static const String caregiverLogin = '/caregiver/login';
  static const String caregiverOnboarding = '/caregiver/onboarding';
  static const String caregiverDashboard = '/caregiver/dashboard';
  static const String patientAccess = '/patient/access';
  static const String patientDashboard = '/patient/dashboard';
  static const String patientAdvancedVisionReport =
      '/patient/advanced_vision_report';
  static const String patientEventHistory = '/patient/event_history';
  static const String patientFindItem = '/patient/find_item';
  static const String patientOrientationSupport =
      '/patient/orientation_support';
  static const String patientObservationHistory =
      '/patient/observation_history';
  static const String patientSettings = '/patient/settings';
  static const String patientActivities = '/patient/activities';
  static const String patientCompanion = '/patient/companion';
  static const String doctorLogin = '/doctor/login';
  static const String doctorDashboard = '/doctor/dashboard';

  // ── Route map ──
  static Map<String, WidgetBuilder> get routes => {
    landing: (context) => const LandingScreen(),
    caregiverLogin: (context) => const CaregiverLoginScreen(),
    caregiverOnboarding: (context) => const CaregiverOnboardingFlow(),
    caregiverDashboard: (context) => const CaregiverShell(),
    patientAccess: (context) => const PatientAccessScreen(),
    patientDashboard: (context) => const PatientDashboardScreen(),
    patientAdvancedVisionReport: (context) =>
        const AdvancedVisionReportScreen(),
    patientEventHistory: (context) => const PatientEventHistoryScreen(),
    patientFindItem: (context) => const FindItemScreen(),
    patientOrientationSupport: (context) => const OrientationSupportScreen(),
    patientObservationHistory: (context) => const ObservationHistoryScreen(),
    patientSettings: (context) => const PatientSettingsScreen(),
    patientActivities: (context) => const CognitiveActivitiesScreen(),
    patientCompanion: (context) => const PatientCompanionScreen(),
    doctorLogin: (context) => const DoctorLoginScreen(),
    doctorDashboard: (context) => const DoctorDashboardScreen(),
  };
}
