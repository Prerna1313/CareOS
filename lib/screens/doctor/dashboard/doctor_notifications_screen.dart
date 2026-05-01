import 'package:flutter/material.dart';

import '../../../models/caregiver_report.dart';
import 'doctor_patients_list_screen.dart';

class DoctorNotificationsScreen extends StatefulWidget {
  final List<DoctorPatientListEntry> patientBundles;

  const DoctorNotificationsScreen({
    super.key,
    required this.patientBundles,
  });

  @override
  State<DoctorNotificationsScreen> createState() =>
      _DoctorNotificationsScreenState();
}

class _DoctorNotificationsScreenState extends State<DoctorNotificationsScreen> {
  static const _teal = Color(0xFF2D6E6E);
  static const _darkText = Color(0xFF1A3636);
  static const _bgColor = Color(0xFFF7F8F5);

  late final List<_DoctorNotificationItem> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = _buildNotifications();
  }

  List<_DoctorNotificationItem> _buildNotifications() {
    final items = <_DoctorNotificationItem>[];

    for (final bundle in widget.patientBundles) {
      for (final assessment in bundle.confusionAssessments.take(3)) {
        final risk = assessment.riskLevel.name.toLowerCase();
        items.add(
          _DoctorNotificationItem(
            title:
                '${bundle.patientName} - ${assessment.riskLevel.name.toUpperCase()} confusion',
            detail: assessment.explanation,
            createdAt: assessment.timestamp,
            timeLabel:
                '${assessment.timestamp.day}/${assessment.timestamp.month} ${assessment.timestamp.hour.toString().padLeft(2, '0')}:${assessment.timestamp.minute.toString().padLeft(2, '0')}',
            color: _riskColor(risk),
            read: false,
          ),
        );
      }

      for (final report in bundle.reports.take(3)) {
        items.add(
          _DoctorNotificationItem(
            title: '${bundle.patientName} - ${report.category.displayName}',
            detail: report.note,
            createdAt: report.timestamp,
            timeLabel:
                '${report.timestamp.day}/${report.timestamp.month} ${report.timestamp.hour.toString().padLeft(2, '0')}:${report.timestamp.minute.toString().padLeft(2, '0')}',
            color: const Color(0xFF2D6E6E),
            read: true,
          ),
        );
      }

      for (final note in bundle.doctorNotes.take(2)) {
        items.add(
          _DoctorNotificationItem(
            title: '${bundle.patientName} - Doctor note saved',
            detail: note.recommendation.isNotEmpty
                ? note.recommendation
                : note.note,
            createdAt: note.createdAt,
            timeLabel:
                '${note.createdAt.day}/${note.createdAt.month} ${note.createdAt.hour.toString().padLeft(2, '0')}:${note.createdAt.minute.toString().padLeft(2, '0')}',
            color: const Color(0xFF3D8C5A),
            read: true,
          ),
        );
      }
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (items.isEmpty) {
      items.add(
        _DoctorNotificationItem(
          title: 'No doctor notifications yet',
          detail:
              'Doctor-visible alerts and shared caregiver reports will appear here.',
          createdAt: DateTime.now(),
          timeLabel: 'Now',
          color: const Color(0xFF2D6E6E),
          read: true,
        ),
      );
    }

    return items;
  }

  void _markAllRead() {
    setState(() {
      for (final item in _notifications) {
        item.read = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) =>
                    _buildNotificationCard(_notifications[index], index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _darkText,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _markAllRead,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F0F0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: _teal,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(_DoctorNotificationItem item, int index) {
    return GestureDetector(
      onTap: () => setState(() => item.read = true),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: item.read
              ? null
              : Border.all(color: item.color.withValues(alpha: 0.25), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: item.read ? 0.03 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: item.read
                      ? item.color.withValues(alpha: 0.35)
                      : item.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: item.read
                                ? FontWeight.w500
                                : FontWeight.bold,
                            color: _darkText,
                          ),
                        ),
                      ),
                      if (!item.read)
                        const Icon(Icons.circle, color: _teal, size: 8),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.detail,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.timeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _riskColor(String risk) {
    if (risk == 'high') return const Color(0xFFCC4444);
    if (risk == 'moderate' || risk == 'medium') return const Color(0xFFD4910A);
    return const Color(0xFF3D8C5A);
  }
}

class _DoctorNotificationItem {
  final String title;
  final String detail;
  final DateTime createdAt;
  final String timeLabel;
  final Color color;
  bool read;

  _DoctorNotificationItem({
    required this.title,
    required this.detail,
    required this.createdAt,
    required this.timeLabel,
    required this.color,
    required this.read,
  });
}
