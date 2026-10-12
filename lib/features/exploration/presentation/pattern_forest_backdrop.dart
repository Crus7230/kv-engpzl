import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Resolution-independent forest artwork. No extra download, generated bitmap,
/// animation ticker or retained-asset-pack change is required for R2.
class PatternForestBackdrop extends StatelessWidget {
  const PatternForestBackdrop({this.chapter, super.key});
  final int? chapter;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _ForestPainter(chapter),
      child: const SizedBox.expand(),
    ),
  );
}

class _ForestPainter extends CustomPainter {
  const _ForestPainter(this.chapter);
  final int? chapter;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFACD1BD), Color(0xFFE1E8BC), Color(0xFF678C66)],
        ).createShader(rect),
    );
    canvas.drawCircle(
      Offset(size.width * .67, size.height * .19),
      size.height * .19,
      Paint()..color = const Color(0x66FFF8C8),
    );
    for (var layer = 0; layer < 3; layer++) {
      final path = Path()..moveTo(0, size.height);
      for (var i = 0; i <= 24; i++) {
        final x = size.width * i / 24;
        final y =
            size.height *
            (.28 + layer * .16 + .045 * math.sin(i * .65 + layer));
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = const [
            Color(0xFF85AA85),
            Color(0xFF6A956F),
            Color(0xFF47785C),
          ][layer],
      );
    }
    // A winding path leaves the central play markers unobstructed.
    final trail = Path()
      ..moveTo(size.width * .08, size.height * .83)
      ..cubicTo(
        size.width * .32,
        size.height * .55,
        size.width * .56,
        size.height * .98,
        size.width * .72,
        size.height * .48,
      )
      ..quadraticBezierTo(
        size.width * .86,
        size.height * .26,
        size.width * .96,
        size.height * .33,
      );
    canvas.drawPath(
      trail,
      Paint()
        ..color = const Color(0xFFB4B184)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * .12
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      trail,
      Paint()
        ..color = const Color(0xFFD5D1A1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * .07,
    );
    for (var i = 0; i < 14; i++) {
      final x = size.width * (i / 13);
      final y = size.height * (i.isEven ? .40 : .51);
      final height = size.height * (.30 + (i % 3) * .055);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x - height * .05,
            y - height * .22,
            height * .10,
            height * .75,
          ),
          Radius.circular(height * .04),
        ),
        Paint()..color = const Color(0xFF675B3D),
      );
      for (var crown = 0; crown < 3; crown++) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(
              x + (crown - 1) * height * .17,
              y - height * .35 - (crown == 1 ? height * .10 : 0),
            ),
            width: height * .60,
            height: height * .52,
          ),
          Paint()
            ..color = crown == 1
                ? const Color(0xFF3F7655)
                : const Color(0xFF508760),
        );
      }
    }
    if (chapter == 3 || chapter == 6) {
      final trunk = Rect.fromLTWH(
        size.width * .76,
        size.height * .30,
        size.width * .09,
        size.height * .42,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(trunk, const Radius.circular(16)),
        Paint()..color = const Color(0xFF5B6041),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * .805, size.height * .28),
          width: size.width * .27,
          height: size.height * .42,
        ),
        Paint()..color = const Color(0xFF2F6449),
      );
    }
    for (var i = 0; i < 12; i++) {
      canvas.drawCircle(
        Offset(
          size.width * (.07 + i * .079),
          size.height * (.78 + .09 * math.sin(i * 1.7)),
        ),
        2.5,
        Paint()..color = const Color(0xFFFFE2A0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ForestPainter oldDelegate) =>
      oldDelegate.chapter != chapter;
}
