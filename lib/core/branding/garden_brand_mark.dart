import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The garden's sprout and equation tile, drawn without a media-pack dependency.
class GardenBrandMark extends StatelessWidget {
  const GardenBrandMark({super.key, this.size = 96}) : assert(size > 0);

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'KV 수학탐험대 로고, 수식 타일에서 자라는 새싹',
    child: ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: _GardenMarkPainter()),
      ),
    ),
  );
}

class _GardenMarkPainter extends CustomPainter {
  const _GardenMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 108, size.height / 108);
    final paint = Paint()..isAntiAlias = true;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 6, 96, 96),
        const Radius.circular(27),
      ),
      paint..color = AppColors.primary,
    );
    canvas.drawPath(
      Path()
        ..moveTo(6, 75)
        ..quadraticBezierTo(43, 105, 102, 55)
        ..lineTo(102, 75)
        ..quadraticBezierTo(102, 102, 75, 102)
        ..lineTo(33, 102)
        ..quadraticBezierTo(6, 102, 6, 75),
      paint..color = AppColors.primaryDark.withValues(alpha: 0.32),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(27, 43, 54, 39),
        const Radius.circular(11),
      ),
      paint..color = AppColors.primaryDark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(27, 40, 54, 39),
        const Radius.circular(11),
      ),
      paint..color = const Color(0xFFFFFCF2),
    );

    // A geometric 2 remains recognizable at launcher-icon sizes.
    canvas.drawPath(
      Path()
        ..moveTo(38, 55)
        ..cubicTo(38, 48, 51, 48, 51, 55)
        ..cubicTo(51, 59, 45, 62, 39, 67)
        ..lineTo(51, 67),
      paint
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawLine(const Offset(60, 55), const Offset(70, 55), paint);
    canvas.drawLine(const Offset(60, 64), const Offset(70, 64), paint);
    paint.style = PaintingStyle.fill;

    canvas.drawPath(
      Path()
        ..moveTo(53, 45)
        ..cubicTo(53, 36, 56, 31, 59, 28),
      paint
        ..color = AppColors.success
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    paint.style = PaintingStyle.fill;
    canvas.drawPath(
      Path()
        ..moveTo(54, 37)
        ..cubicTo(42, 37, 36, 31, 37, 23)
        ..cubicTo(49, 23, 55, 28, 54, 37)
        ..close(),
      paint..color = const Color(0xFF7BCD96),
    );
    canvas.drawPath(
      Path()
        ..moveTo(56, 32)
        ..cubicTo(54, 22, 61, 17, 69, 19)
        ..cubicTo(69, 28, 63, 33, 56, 32)
        ..close(),
      paint..color = AppColors.success,
    );
    canvas.drawPath(
      Path()
        ..moveTo(77, 27)
        ..lineTo(77, 35)
        ..moveTo(73, 31)
        ..lineTo(81, 31),
      paint
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(33, 84), 2.5, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GardenMarkPainter oldDelegate) => false;
}
