import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../models/caregiver_report.dart';
import '../../../models/confusion_detection_result.dart';
import '../../../models/doctor_note.dart';
import '../../../services/doctor_note_service.dart';

class DoctorPatientDetailsScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final List<ConfusionDetectionResult> confusionAssessments;
  final List<CaregiverReport> reports;
  final List<DoctorNote> initialDoctorNotes;

  const DoctorPatientDetailsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.confusionAssessments,
    required this.reports,
    this.initialDoctorNotes = const [],
  });

  @override
  State<DoctorPatientDetailsScreen> createState() =>
      _DoctorPatientDetailsScreenState();
}

class _DoctorPatientDetailsScreenState extends State<DoctorPatientDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _doctorNoteService = DoctorNoteService();
  final _uuid = const Uuid();
  List<DoctorNote> _doctorNotes = [];

  static const _teal = Color(0xFF2D6E6E);
  static const _darkText = Color(0xFF1A3636);
  static const _bgColor = Color(0xFFF7F8F5);
  static const _tealBgLight = Color(0xFFE0F0F0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _doctorNotes = [...widget.initialDoctorNotes];
    _doctorNoteService.init().then((_) {
      if (!mounted) return;
      _doctorNoteService.getByPatientId(widget.patientId).then((notes) {
        if (!mounted) return;
        setState(() {
          _doctorNotes = notes;
        });
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPatientHeader(),
                    _buildTabBar(),
                    _buildTabContent(),
                  ],
                ),
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
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _darkText,
                size: 18,
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'Patient Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _darkText,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.more_vert_rounded,
              color: _darkText,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientHeader() {
    final latest = widget.confusionAssessments.isNotEmpty
        ? widget.confusionAssessments.first
        : null;

    return Container(
      margin: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  color: _tealBgLight,
                  child: const Icon(Icons.person, size: 100, color: _teal),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: latest == null
                        ? _teal
                        : _riskColor(latest.riskLevel.name.toLowerCase()),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    latest == null
                        ? 'Stable'
                        : latest.riskLevel.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.patientName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  latest == null
                      ? 'Doctor-linked active profile'
                      : 'Latest score ${latest.score.round()} / 100',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: _teal,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: _teal,
        unselectedLabelColor: Colors.grey[500],
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'History'),
          Tab(text: 'Reports'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tabController.index) {
      case 1:
        return _buildHistoryTab();
      case 2:
        return _buildReportsTab();
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildOverviewTab() {
    final latest = widget.confusionAssessments.isNotEmpty
        ? widget.confusionAssessments.first
        : null;
    final progress = latest == null
        ? 0.35
        : (100 - latest.score).clamp(0, 100) / 100;
    final highRiskCount = widget.confusionAssessments
        .where((result) => result.riskLevel.name.toLowerCase() == 'high')
        .length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Treatment Progress',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _darkText,
                  ),
                ),
                Text(
                  'Live CareOS doctor summary',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 24),
                Center(
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: CustomPaint(
                      painter: _CircleProgressPainter(progress),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${(progress * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: _darkText,
                              ),
                            ),
                            Text(
                              latest == null
                                  ? 'Limited data'
                                  : latest.riskLevel.name.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: _teal,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _statRow(
                  Icons.psychology_outlined,
                  _teal,
                  'Latest confusion',
                  latest == null
                      ? 'No record'
                      : '${latest.score.round()} / 100',
                ),
                const Divider(height: 24),
                _statRow(
                  Icons.report_outlined,
                  const Color(0xFF3D8C5A),
                  'Doctor-visible reports',
                  '${widget.reports.length}',
                ),
                const Divider(height: 24),
                _statRow(
                  Icons.edit_note_rounded,
                  _teal,
                  'Doctor notes',
                  '${_doctorNotes.length}',
                ),
                const Divider(height: 24),
                _statRow(
                  Icons.warning_amber_rounded,
                  const Color(0xFFD4910A),
                  'High-risk assessments',
                  '$highRiskCount',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _darkText,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    final items = widget.confusionAssessments.isEmpty
        ? <Map<String, dynamic>>[
            {
              'date': 'Now',
              'event': 'No live assessment yet',
              'detail':
                  'Confusion assessments will appear here once shared to doctor view.',
              'color': const Color(0xFF2D6E6E),
            },
          ]
        : widget.confusionAssessments
              .take(6)
              .map(
                (assessment) => {
                  'date':
                      '${assessment.timestamp.day}/${assessment.timestamp.month}/${assessment.timestamp.year}',
                  'event':
                      '${assessment.riskLevel.name.toUpperCase()} confusion (${assessment.score.round()}/100)',
                  'detail': assessment.explanation,
                  'color': _riskColor(assessment.riskLevel.name.toLowerCase()),
                },
              )
              .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isLast = index == items.length - 1;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: item['color'] as Color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 72,
                      color: (item['color'] as Color).withValues(alpha: 0.2),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['date'] as String,
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['event'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: item['color'] as Color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['detail'] as String,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildReportsTab() {
    final items = widget.reports.isEmpty
        ? <Map<String, dynamic>>[
            {
              'title': 'No doctor-visible reports',
              'date': 'Now',
              'color': _teal,
              'note': 'Shared caregiver reports will appear here.',
            },
          ]
        : widget.reports
              .take(6)
              .map(
                (report) => {
                  'title': report.category.displayName,
                  'date':
                      '${report.timestamp.day}/${report.timestamp.month}/${report.timestamp.year}',
                  'color': _teal,
                  'note': report.note,
                },
              )
              .toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...items.map((item) {
            final color = item['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.description_outlined,
                        color: color,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _darkText,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item['date'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item['note'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          _buildDoctorNotesSection(),
        ],
      ),
    );
  }

  Widget _buildDoctorNotesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Doctor Notes & Feedback',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _darkText,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _showAddDoctorNoteDialog,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Add note'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_doctorNotes.isEmpty)
            Text(
              'No doctor notes saved yet for this patient.',
              style: TextStyle(color: Colors.grey[600]),
            )
          else
            ..._doctorNotes.take(4).map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _tealBgLight.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.authorName,
                        style: const TextStyle(
                          color: _teal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(note.note),
                      if (note.recommendation.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Recommendation: ${note.recommendation}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddDoctorNoteDialog() async {
    final noteController = TextEditingController();
    final recommendationController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Doctor Note',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Clinical observation',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: recommendationController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Recommendation',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (noteController.text.trim().isEmpty) {
                      return;
                    }
                    final note = DoctorNote(
                      id: _uuid.v4(),
                      patientId: widget.patientId,
                      authorName: 'Assigned Doctor',
                      note: noteController.text.trim(),
                      recommendation: recommendationController.text.trim(),
                      createdAt: DateTime.now(),
                    );
                    await _doctorNoteService.save(note);
                    if (!mounted) return;
                    Navigator.of(this.context).pop(true);
                  },
                  child: const Text('Save note'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true && mounted) {
      final notes = await _doctorNoteService.getByPatientId(widget.patientId);
      setState(() {
        _doctorNotes = notes;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Doctor note saved.')),
      );
    }
  }

  Color _riskColor(String risk) {
    switch (risk) {
      case 'high':
        return const Color(0xFFCC4444);
      case 'medium':
        return const Color(0xFFD4910A);
      default:
        return const Color(0xFF3D8C5A);
    }
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

class _CircleProgressPainter extends CustomPainter {
  final double progress;

  const _CircleProgressPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    const strokeWidth = 12.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFFE0F0F0)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF2D6E6E), Color(0xFF5FB8B8)],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
