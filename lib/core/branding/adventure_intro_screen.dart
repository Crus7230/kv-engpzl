import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'garden_brand_mark.dart';
import 'intro_motion_timeline.dart';

/// A separate cold-start scene, drawn without requiring a downloaded image
/// pack. Real save, media and update preparation runs behind this screen.
class AdventureIntroScreen extends StatefulWidget {
  const AdventureIntroScreen({required this.status, super.key});

  final String status;

  @override
  State<AdventureIntroScreen> createState() => _AdventureIntroScreenState();
}

class _AdventureIntroScreenState extends State<AdventureIntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: IntroMotionTimeline.duration,
  );
  bool _started = false;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (_reduceMotion) {
      _entrance.stop();
      _entrance.value = 1;
    } else if (!_started) {
      _entrance.forward();
    }
    _started = true;
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Widget _reveal(
    String part,
    double opacity,
    Widget child, {
    double brightness = 1,
  }) => Opacity(
    key: ValueKey('intro-$part-reveal'),
    opacity: _reduceMotion
        ? 1
        : Curves.easeOutCubic.transform(opacity) * brightness,
    child: child,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF173F43),
    body: Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(
          child: CustomPaint(painter: _IntroLandscapePainter()),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 340;
              return AnimatedBuilder(
                animation: _entrance,
                builder: (context, child) {
                  final time =
                      _entrance.value *
                      IntroMotionTimeline.duration.inMilliseconds;
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _reveal(
                              'logo',
                              IntroMotionTimeline.logo(time),
                              GardenBrandMark(size: compact ? 70 : 96),
                            ),
                            SizedBox(height: compact ? 8 : 12),
                            _reveal(
                              'title',
                              IntroMotionTimeline.title(time),
                              const Text(
                                'KV 수학탐험대',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFFFF6DA),
                                  fontSize: 27,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            _reveal(
                              'tagline',
                              IntroMotionTimeline.tagline(time),
                              const Text(
                                '수식의 길을 따라, 일곱 지역으로',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFE0EDD6),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            SizedBox(height: compact ? 14 : 22),
                            Semantics(
                              liveRegion: true,
                              label: widget.status,
                              child: ExcludeSemantics(
                                child: _reveal(
                                  'status',
                                  IntroMotionTimeline.status(time),
                                  Text(
                                    widget.status,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFE0EDD6),
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                  brightness:
                                      IntroMotionTimeline.promptBrightness(
                                        time,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _IntroLandscapePainter extends CustomPainter {
  const _IntroLandscapePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF173F43), Color(0xFF376B60)],
      ).createShader(bounds);
    canvas.drawRect(bounds, paint);
    paint.shader = null;
    canvas.drawCircle(
      Offset(size.width * .79, size.height * .18),
      math.min(size.width, size.height) * .11,
      paint..color = const Color(0xFFCFDAA0).withValues(alpha: .16),
    );
    for (final (index, color) in const [
      Color(0xFF294F49),
      Color(0xFF203D3D),
    ].indexed) {
      final base = .72 + index * .12;
      final hill = Path()
        ..moveTo(0, size.height * base)
        ..cubicTo(
          size.width * .25,
          size.height * (base - .22),
          size.width * .62,
          size.height * (base + .12),
          size.width,
          size.height * (base - .13),
        )
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(hill, paint..color = color);
    }
    final path = Path()
      ..moveTo(size.width * .15, size.height)
      ..cubicTo(
        size.width * .32,
        size.height * .70,
        size.width * .68,
        size.height * .91,
        size.width * .81,
        size.height * .66,
      );
    canvas.drawPath(
      path,
      paint
        ..color = const Color(0xFFD7BE81).withValues(alpha: .38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.min(size.height * .014, 6)
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_IntroLandscapePainter oldDelegate) => false;
}
