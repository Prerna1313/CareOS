import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/my_day_provider.dart';

class MyDayChatOverlay extends StatefulWidget {
  const MyDayChatOverlay({super.key});

  @override
  State<MyDayChatOverlay> createState() => _MyDayChatOverlayState();
}

class _MyDayChatOverlayState extends State<MyDayChatOverlay>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _handleSubmit(MyDayProvider provider) {
    if (_textController.text.trim().isNotEmpty) {
      provider.answerQuestion(_textController.text.trim());
      _textController.clear();
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MyDayProvider>();
    final textTheme = Theme.of(context).textTheme;

    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: const Color(
            0xFFF9FAF9,
          ), // Exact off-white background from image
          child: SafeArea(
            child: Column(
              children: [
                // EXACT HEADER FROM IMAGE
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderCompanion(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "My Day Guide",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2D2D2D),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Helping you remember",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF555555),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => provider.dismissOverlay(),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.grey,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                  child: Column(
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Text(
                            provider.isChatCompleted
                                ? "Today's reflection complete"
                                : 'Question ${provider.currentQuestionIndex + 1} of ${provider.totalQuestionCount}',
                            style: textTheme.labelLarge?.copyWith(
                              color: const Color(0xFF6B756B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (!provider.isChatCompleted)
                            Text(
                              '${provider.currentQuestionIndex + 1}/${provider.totalQuestionCount}',
                              style: textTheme.labelLarge?.copyWith(
                                color: const Color(0xFF7CB342),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: provider.isChatCompleted
                              ? 1
                              : (provider.currentQuestionIndex + 1) /
                                    provider.totalQuestionCount,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFE5ECE5),
                          color: const Color(0xFF7CB342),
                        ),
                      ),
                    ],
                  ),
                ),

                // Subtle divider from image
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 0),
                  child: Divider(height: 1, color: Color(0xFFE0E5E0)),
                ),

                // MESSAGES AREA
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    children: [
                      ..._buildChatHistory(provider, textTheme),

                      if (!provider.isChatCompleted)
                        _CompanionMessageBubble(
                          text:
                              provider.questions[provider.currentQuestionIndex],
                          textTheme: textTheme,
                        )
                      else
                        _buildCompletionState(provider, textTheme),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),

                // INPUT AREA
                if (!provider.isChatCompleted)
                  _buildInputSection(provider, textTheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCompanion() {
    return Image.asset(
      'assets/images/sprout_companion.png',
      height: 64,
      width: 64,
      fit: BoxFit.contain,
    );
  }

  List<Widget> _buildChatHistory(MyDayProvider provider, TextTheme textTheme) {
    List<Widget> history = [];
    for (int i = 0; i < provider.currentQuestionIndex; i++) {
      history.add(
        _CompanionMessageBubble(
          text: provider.questions[i],
          textTheme: textTheme,
        ),
      );
      if (provider.chatResponses.containsKey(i)) {
        history.add(
          _UserMessageBubble(
            text: provider.chatResponses[i]!,
            textTheme: textTheme,
          ),
        );
      }
    }
    return history;
  }

  Widget _buildInputSection(MyDayProvider provider, TextTheme textTheme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  style: textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: "Type your answer...",
                    filled: true,
                    fillColor: const Color(0xFFF0F4F0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  onSubmitted: (_) => _handleSubmit(provider),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _handleSubmit(provider),
                child: Container(
                  height: 56,
                  width: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFF7CB342), // Matching the green theme
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => provider.skipQuestion(),
            child: Text(
              "Skip this one",
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionState(MyDayProvider provider, TextTheme textTheme) {
    return Column(
      children: [
        const SizedBox(height: 20),
        _CompanionMessageBubble(
          text:
              "That was wonderful! I've saved everything for you. You can always add more notes or a voice memory later.",
          textTheme: textTheme,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => provider.dismissOverlay(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7CB342),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: const Text(
            "Done for today",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _CompanionMessageBubble extends StatelessWidget {
  final String text;
  final TextTheme textTheme;

  const _CompanionMessageBubble({required this.text, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // THE BUBBLE (Placed first so avatar can overlap it)
          Padding(
            padding: const EdgeInsets.only(
              left: 65,
            ), // Leave room for avatar overlap
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ORGANIC BUBBLE CONTAINER
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEBF5EB), Color(0xFFF7FBF7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                          bottomLeft: Radius.circular(4),
                        ),
                        border: Border.all(
                          color: const Color(0xFFDCEADD),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text,
                            style: textTheme.headlineSmall?.copyWith(
                              fontSize: 21,
                              height: 1.45,
                              color: const Color(0xFF2D2D2D),
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 14),
                          // REFINED TYPING DOTS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildDot(),
                              const SizedBox(width: 5),
                              _buildDot(),
                              const SizedBox(width: 5),
                              _buildDot(),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // TAIL POSITIONED RELATIVE TO BUBBLE
                    Positioned(
                      left: -7,
                      bottom: 0,
                      child: CustomPaint(
                        size: const Size(14, 14),
                        painter: _TailPainter(
                          const Color(0xFFDCEADD),
                        ), // Match border color
                      ),
                    ),
                    Positioned(
                      left: -5,
                      bottom: 1.5,
                      child: CustomPaint(
                        size: const Size(12, 12),
                        painter: _TailPainter(
                          const Color(0xFFEBF5EB),
                        ), // Match fill color
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // COMPANION AVATAR (Positioned on top of the bubble's leading edge)
          Positioned(
            left: -8,
            bottom: -10,
            child: Container(
              height: 84,
              width: 84,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE8F2E8), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                'assets/images/sprout_companion.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot() {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: Color(0xFFC8D5C8),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _UserMessageBubble extends StatelessWidget {
  final String text;
  final TextTheme textTheme;

  const _UserMessageBubble({required this.text, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, left: 80),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF7CB342).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            text,
            style: textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF2E7D32),
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  final Color color;
  _TailPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(size.width, 0);
    path.quadraticBezierTo(size.width * 0.1, size.height * 0.1, 0, size.height);
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
