import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/caregiver_session.dart';
import '../../routes/app_routes.dart';
import '../../services/app_auth_service.dart';
import '../../services/caregiver_session_service.dart';
import '../../theme/app_colors.dart';
import 'dashboard/caregiver_dashboard_screen.dart';
import 'alerts/alerts_screen.dart';
import 'monitoring/live_monitoring_screen.dart';
import 'memory/memory_cue_management_screen.dart';
import 'reports/caregiver_reports_screen.dart';

class CaregiverShell extends StatefulWidget {
  const CaregiverShell({super.key});

  @override
  State<CaregiverShell> createState() => _CaregiverShellState();
}

class _CaregiverShellState extends State<CaregiverShell> {
  int _currentIndex = 0;
  final _sessionService = CaregiverSessionService();

  Future<void> _logout() async {
    try {
      await context.read<AppAuthService>().signOut();
      await _sessionService.clearSession();
    } catch (_) {
      await _sessionService.clearSession();
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.landing,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = CaregiverSession.fromRouteArguments(
      ModalRoute.of(context)?.settings.arguments,
    );
    final screens = const <Widget>[
      CaregiverDashboardScreen(),
      AlertsScreen(),
      LiveMonitoringScreen(),
      MemoryCueManagementScreen(),
      CaregiverReportsScreen(),
    ];

    return CaregiverSessionScope(
      session: session,
      child: Stack(
        children: [
          Scaffold(
            body: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundColor: AppColors.surfaceColor,
              indicatorColor: AppColors.primaryColor.withValues(alpha: 0.2),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Badge(child: Icon(Icons.notifications_none)),
                  selectedIcon: Badge(child: Icon(Icons.notifications)),
                  label: 'Alerts',
                ),
                NavigationDestination(
                  icon: Icon(Icons.monitor_heart_outlined),
                  selectedIcon: Icon(Icons.monitor_heart),
                  label: 'Monitor',
                ),
                NavigationDestination(
                  icon: Icon(Icons.photo_library_outlined),
                  selectedIcon: Icon(Icons.photo_library),
                  label: 'Memory',
                ),
                NavigationDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(Icons.analytics),
                  label: 'Reports',
                ),
              ],
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                elevation: 2,
                child: IconButton(
                  tooltip: 'Log out',
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
