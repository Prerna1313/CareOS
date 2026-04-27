import 'package:flutter/material.dart';
import '../../models/caregiver_session.dart';
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
      child: Scaffold(
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
    );
  }
}
