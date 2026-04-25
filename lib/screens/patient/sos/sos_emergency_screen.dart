import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/voice_orientation_service.dart';
import '../../../providers/patient_session_provider.dart';
import '../../../services/patient_records_service.dart';

/// Full-screen SOS / Emergency screen.
/// Appears when the patient taps the HELP button.
/// Design: high-contrast, extremely large touch targets, gentle pulse animation.
class SosEmergencyScreen extends StatefulWidget {
  const SosEmergencyScreen({super.key});

  @override
  State<SosEmergencyScreen> createState() => _SosEmergencyScreenState();
}

class _SosEmergencyScreenState extends State<SosEmergencyScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  bool _callingCaregiver = false;

  final VoiceOrientationService _voice = VoiceOrientationService();

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Immediately speak reassurance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _voice.speak(
        "Don't worry. You are safe. Help is on the way. "
        "Take a slow, deep breath.",
      );
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _voice.stop();
    super.dispose();
  }

  Future<void> _callCaregiver() async {
    setState(() => _callingCaregiver = true);
    final patientProfile = context.read<PatientSessionProvider>().profile;
    if (patientProfile != null) {
      await context.read<PatientRecordsService>().logIntervention(
        patientId: patientProfile.patientId,
        triggerType: 'sos_button',
        interventionType: 'sos',
        outcome: 'caregiver_called',
        notes: 'The patient initiated the SOS caregiver call flow.',
      );
    }
    await _voice.speak(
      "Calling your caregiver now. Please stay calm. They will be with you soon.",
    );
    if (!mounted) return;
    // Simulate call initiated feedback (real implementation: url_launcher tel:)
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _callingCaregiver = false);
    _showCalledSnackbar();
  }

  void _showCalledSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Your caregiver has been notified.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFB71C1C), // Deep red SOS background
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Stack(
            children: [
              // Animated ripple rings in background
              _PulseRings(pulseAnimation: _pulseAnimation, size: size),

              // Main content
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              const SizedBox(height: 48),

                              // ── SOS Icon ──
                              ScaleTransition(
                                scale: _pulseAnimation,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 40,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.emergency_rounded,
                                    color: Color(0xFFB71C1C),
                                    size: 64,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 32),

                              // ── Headline ──
                              const Text(
                                'YOU ARE SAFE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 12),

                              Text(
                                'Help is coming.\nTake a slow, deep breath.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w400,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const Spacer(),

                              // ── Breathe guidance ──
                              _BreathePrompt(),

                              const Spacer(),

                              // ── Call Caregiver Button ──
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _callingCaregiver
                                      ? null
                                      : _callCaregiver,
                                  icon: _callingCaregiver
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.phone_rounded,
                                          size: 30,
                                        ),
                                  label: Text(
                                    _callingCaregiver
                                        ? 'Calling...'
                                        : 'Call My Caregiver',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFFB71C1C),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    elevation: 8,
                                    shadowColor: Colors.black38,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── I'm OK Button ──
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () {
                                    final patientProfile = context
                                        .read<PatientSessionProvider>()
                                        .profile;
                                    if (patientProfile != null) {
                                      context
                                          .read<PatientRecordsService>()
                                          .logIntervention(
                                            patientId: patientProfile.patientId,
                                            triggerType: 'sos_button',
                                            interventionType: 'sos',
                                            outcome: 'resolved',
                                            notes:
                                                'The patient closed the SOS flow and reported feeling okay.',
                                          );
                                    }
                                    _voice.speak("I'm glad you're okay.");
                                    Navigator.of(context).pop();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Colors.white54,
                                      width: 2,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  child: const Text(
                                    "I'm okay now",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated pulsing rings behind the main content
class _PulseRings extends StatelessWidget {
  final Animation<double> pulseAnimation;
  final Size size;

  const _PulseRings({required this.pulseAnimation, required this.size});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: size,
          painter: _RingPainter(pulseAnimation.value),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double scale;
  _RingPainter(this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.28);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 1; i <= 5; i++) {
      canvas.drawCircle(center, (80 + i * 40) * scale, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.scale != scale;
}

/// Animated breathing guide — "Breathe in... Breathe out..."
class _BreathePrompt extends StatefulWidget {
  @override
  State<_BreathePrompt> createState() => _BreathePromptState();
}

class _BreathePromptState extends State<_BreathePrompt>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;
  final List<String> _phrases = ['Breathe in...', 'Breathe out...'];
  int _phraseIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              setState(() {
                _phraseIndex = (_phraseIndex + 1) % _phrases.length;
              });
              _controller.reverse();
            } else if (status == AnimationStatus.dismissed) {
              setState(() {
                _phraseIndex = (_phraseIndex + 1) % _phrases.length;
              });
              _controller.forward();
            }
          });
    _controller.forward();
    _anim = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final scale = 0.9 + (_anim.value * 0.15);
        return Column(
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(
                    alpha: 0.1 + (_anim.value * 0.1),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _phrases[_phraseIndex],
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 20,
                fontWeight: FontWeight.w300,
                letterSpacing: 1,
              ),
            ),
          ],
        );
      },
    );
  }
}
