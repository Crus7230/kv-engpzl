import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'garden_scene.dart';

/// Small vector scenes: no extra asset download and no persistent game state.
/// Entrances are finite so reading never competes with an endless animation.
class CollectionArtMotion extends StatefulWidget {
  const CollectionArtMotion({
    required this.replayKey,
    required this.painter,
    super.key,
  });
  static const duration = Duration(milliseconds: 1800);
  final Object replayKey;
  final CustomPainter Function(double progress) painter;

  @override
  State<CollectionArtMotion> createState() => _CollectionArtMotionState();
}

class _CollectionArtMotionState extends State<CollectionArtMotion>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: CollectionArtMotion.duration,
  );
  bool _started = false;
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    if (_still) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_started) {
      _controller.forward();
    }
    _started = true;
  }

  @override
  void didUpdateWidget(CollectionArtMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.replayKey != widget.replayKey && !_still) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: widget.painter(_controller.value),
          size: Size.infinite,
        ),
      ),
    ),
  );
}

class SeedGardenArt extends StatelessWidget {
  const SeedGardenArt({
    required this.seedId,
    required this.growth,
    required this.ready,
    super.key,
  });
  final String seedId;
  final int growth;
  final bool ready;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CollectionArtMotion(
      key: const ValueKey('seed-garden-art'),
      replayKey: (seedId, growth, ready),
      painter: (progress) => SeedGardenPainter(growth, ready, progress),
    ),
  );
}

class SeedGardenPainter extends CustomPainter {
  const SeedGardenPainter(this.growth, this.ready, this.progress);
  final int growth;
  final bool ready;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint();
    final bounds = Offset.zero & size;
    final scene = RRect.fromRectAndRadius(bounds, const Radius.circular(16));
    canvas.save();
    canvas.clipRRect(scene);
    paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFDFF0DA), Color(0xFFF5EBC9)],
    ).createShader(bounds);
    canvas.drawRRect(scene, paint);
    paint.shader = null;
    canvas.drawCircle(
      Offset(size.width * .77, size.height * .21),
      size.height * .16,
      paint..color = const Color(0xFFFFF3BC),
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * (.15 + i * .34), size.height * .94),
          width: size.width * .75,
          height: size.height * .42,
        ),
        paint
          ..color = i.isEven
              ? const Color(0xFFB9D09B)
              : const Color(0xFF9ABB84),
      );
    }
    final scale = math.min(size.width / 124, size.height / 92);
    canvas.translate(size.width / 2, size.height * .82);
    canvas.scale(scale);
    canvas.drawOval(
      const Rect.fromLTWH(-27, -2, 54, 10),
      paint..color = const Color(0xFF567653).withValues(alpha: .2),
    );
    final rise = Curves.easeOutBack.transform((progress * 2.2).clamp(0.0, 1.0));
    final sway = math.sin(progress * math.pi * 3) * (1 - progress) * .08;
    canvas.rotate(sway);
    canvas.scale(.88 + .12 * rise, math.max(.05, rise));
    _plant(canvas, Offset.zero, growth, 1, ready);
    canvas.restore();
    if (ready && progress > .15 && progress < 1) {
      final fade = math.sin(progress * math.pi);
      for (var i = 0; i < 5; i++) {
        _sparkle(
          canvas,
          Offset(
            size.width * (.13 + i * .18),
            size.height * (.65 - progress * .33 + (i % 2) * .13),
          ),
          2.0 + i % 3,
          const Color(0xFFF0B755).withValues(alpha: fade),
        );
      }
    }
  }

  @override
  bool shouldRepaint(SeedGardenPainter old) =>
      old.progress != progress || old.growth != growth || old.ready != ready;
}

class SeedSticker extends StatelessWidget {
  const SeedSticker({required this.growth, this.ready = false, super.key});
  final int growth;
  final bool ready;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(painter: _SeedStickerPainter(growth, ready)),
  );
}

class _SeedStickerPainter extends CustomPainter {
  const _SeedStickerPainter(this.growth, this.ready);
  final int growth;
  final bool ready;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 54;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    final paint = Paint()
      ..color = ready ? const Color(0xFFFFE3A0) : const Color(0xFFDFEBD3);
    canvas.drawCircle(Offset.zero, 25, paint);
    canvas.drawCircle(Offset.zero, 22, paint..color = const Color(0xFFFFFCED));
    _plant(canvas, const Offset(0, 18), growth, .57, ready);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SeedStickerPainter old) =>
      old.growth != growth || old.ready != ready;
}

class PetalGarlandArt extends StatelessWidget {
  const PetalGarlandArt({
    required this.petals,
    required this.bouquets,
    super.key,
  });
  final int petals;
  final int bouquets;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CollectionArtMotion(
      key: const ValueKey('petal-garland-art'),
      replayKey: (petals, bouquets),
      painter: (progress) => _GarlandPainter(petals, bouquets, progress),
    ),
  );
}

class _GarlandPainter extends CustomPainter {
  const _GarlandPainter(this.petals, this.bouquets, this.progress);
  final int petals;
  final int bouquets;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final gap = math.min(size.width / 6, 46.0);
    final start = (size.width - gap * 4) / 2;
    final path = Path()..moveTo(start, size.height * .55);
    path.quadraticBezierTo(
      size.width / 2,
      size.height * .9,
      start + gap * 4,
      size.height * .55,
    );
    canvas.drawPath(
      path,
      paint
        ..color = GardenColors.moss.withValues(alpha: .45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    paint.style = PaintingStyle.fill;
    for (var i = 0; i < 5; i++) {
      final filled = i < petals;
      final reveal = Curves.easeOutBack.transform(
        ((progress * 2 - i * .12) / .8).clamp(0.0, 1.0),
      );
      canvas.save();
      canvas.translate(
        start + i * gap,
        size.height * (.44 + (i.isOdd ? .08 : 0)),
      );
      canvas.scale(filled ? .7 + .3 * reveal : .85);
      _flower(
        canvas,
        Offset.zero,
        filled ? const Color(0xFFEAAA74) : const Color(0xFFD9DFCC),
        filled ? GardenColors.gold : const Color(0xFFECEEDD),
        11,
      );
      canvas.restore();
    }
    if (bouquets > 0) {
      _sparkle(canvas, const Offset(9, 10), 4, GardenColors.gold);
    }
  }

  @override
  bool shouldRepaint(_GarlandPainter old) =>
      old.progress != progress ||
      old.petals != petals ||
      old.bouquets != bouquets;
}

Color collectionRegionColor(int region) =>
    region == 2 ? const Color(0xFF4B8073) : const Color(0xFFC48549);

class ChapterStampArt extends StatelessWidget {
  const ChapterStampArt({
    required this.chapter,
    required this.region,
    required this.earned,
    required this.available,
    super.key,
  });
  final int chapter;
  final int region;
  final bool earned;
  final bool available;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      painter: _StampPainter(chapter, region, earned, available),
      child: Center(
        child: Text(
          'C${chapter.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: earned ? collectionRegionColor(region) : GardenColors.muted,
          ),
        ),
      ),
    ),
  );
}

class _StampPainter extends CustomPainter {
  const _StampPainter(this.chapter, this.region, this.earned, this.available);
  final int chapter;
  final int region;
  final bool earned;
  final bool available;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * .43;
    final color = earned ? collectionRegionColor(region) : GardenColors.muted;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = earned
            ? color.withValues(alpha: .1)
            : const Color(0xFFEAEADD),
    );
    final paint = Paint()
      ..color = color.withValues(alpha: earned ? .9 : .4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = earned ? 2.3 : 1.2;
    for (var i = 0; i < 24; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * math.pi / 12,
        math.pi / 17,
        false,
        paint,
      );
    }
    if (earned) {
      canvas.drawCircle(center, radius - 4, paint..strokeWidth = 1);
      _sparkle(canvas, center + Offset(0, -radius * .56), 2.2, color);
    } else if (available) {
      canvas.drawCircle(
        center + Offset(0, radius * .6),
        2,
        Paint()..color = GardenColors.green,
      );
    }
  }

  @override
  bool shouldRepaint(_StampPainter old) =>
      old.chapter != chapter ||
      old.region != region ||
      old.earned != earned ||
      old.available != available;
}

class PassportMapArt extends StatelessWidget {
  const PassportMapArt({
    required this.chapterId,
    required this.region,
    required this.chapter,
    required this.completed,
    required this.total,
    required this.earned,
    required this.discovered,
    required this.recorded,
    super.key,
  });
  final String chapterId;
  final int region;
  final int chapter;
  final int completed;
  final int total;
  final bool earned;
  final List<bool> discovered;
  final List<bool> recorded;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Stack(
      children: [
        Positioned.fill(
          child: CollectionArtMotion(
            key: const ValueKey('passport-map-art'),
            replayKey: (chapterId, completed, earned),
            painter: (progress) => PassportMapPainter(
              region,
              completed,
              total,
              discovered,
              recorded,
              progress,
            ),
          ),
        ),
        if (earned)
          Positioned(
            top: 7,
            right: 8,
            child: TweenAnimationBuilder<double>(
              key: ValueKey('passport-stamp-reveal-$chapterId'),
              tween: Tween(begin: 0, end: 1),
              duration:
                  MediaQuery.disableAnimationsOf(context) ||
                      MediaQuery.accessibleNavigationOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 520),
              curve: Curves.easeOutBack,
              builder: (context, value, child) => Transform.rotate(
                angle: -.15 * value,
                child: Transform.translate(
                  offset: Offset(0, -12 * (1 - value.clamp(0.0, 1.0))),
                  child: Transform.scale(scale: .7 + .3 * value, child: child),
                ),
              ),
              child: SizedBox(
                width: 50,
                height: 50,
                child: ChapterStampArt(
                  chapter: chapter,
                  region: region,
                  earned: true,
                  available: true,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class PassportMapPainter extends CustomPainter {
  const PassportMapPainter(
    this.region,
    this.completed,
    this.total,
    this.discovered,
    this.recorded,
    this.progress,
  );
  final int region;
  final int completed;
  final int total;
  final List<bool> discovered;
  final List<bool> recorded;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint();
    final rect = Offset.zero & size;
    final clip = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    canvas.save();
    canvas.clipRRect(clip);
    paint.shader = const LinearGradient(
      colors: [Color(0xFFE1ECD7), Color(0xFFF3E6BC)],
    ).createShader(rect);
    canvas.drawRRect(clip, paint);
    paint.shader = null;
    for (var i = 0; i < 4; i++) {
      final x = size.width * (.07 + i * .21);
      paint.color = i.isEven
          ? const Color(0xFFB7CEA7)
          : const Color(0xFFCEDDB5);
      if (region == 2) {
        final tree = Path()
          ..moveTo(x, size.height * .17)
          ..lineTo(x - 13, size.height * .44)
          ..lineTo(x + 13, size.height * .44)
          ..close();
        canvas.drawPath(tree, paint);
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, size.height * .13),
            width: size.width * .34,
            height: size.height * .45,
          ),
          paint,
        );
      }
    }
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * .64,
        size.height * .6,
        size.width * .22,
        size.height * .24,
      ),
      paint..color = const Color(0xFFACD4CF),
    );
    final path = Path()
      ..moveTo(size.width * .08, size.height * .8)
      ..cubicTo(
        size.width * .25,
        size.height * .15,
        size.width * .57,
        size.height * 1.2,
        size.width * .85,
        size.height * .36,
      );
    canvas.drawPath(
      path,
      paint
        ..color = const Color(0xFFFFFAE0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    final metric = path.computeMetrics().first;
    final travelled = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
    final reveal = Curves.easeOutCubic.transform(progress);
    for (var distance = 0.0; distance < metric.length; distance += 11) {
      final tangent = metric.getTangentForOffset(distance)!;
      canvas.drawCircle(
        tangent.position,
        1.5,
        Paint()
          ..color = distance / metric.length <= travelled * reveal
              ? collectionRegionColor(region)
              : GardenColors.moss.withValues(alpha: .55),
      );
    }
    paint.style = PaintingStyle.fill;
    final traveler = metric
        .getTangentForOffset(metric.length * travelled * reveal)!
        .position;
    canvas.drawCircle(
      traveler + const Offset(0, 2),
      6,
      Paint()..color = GardenColors.ink.withValues(alpha: .14),
    );
    canvas.drawCircle(traveler, 5, Paint()..color = const Color(0xFFFFFCED));
    canvas.drawCircle(
      traveler,
      3,
      Paint()..color = collectionRegionColor(region),
    );
    for (var i = 0; i < discovered.length; i++) {
      final tangent = metric.getTangentForOffset(
        metric.length * ((i + 1) / (discovered.length + 1)),
      )!;
      final point = tangent.position;
      final reached = discovered[i];
      final saved = i < recorded.length && recorded[i];
      canvas.drawCircle(
        point + const Offset(0, 5),
        6,
        paint..color = const Color(0xFF698565).withValues(alpha: .14),
      );
      canvas.drawLine(
        point,
        point + const Offset(0, -18),
        Paint()
          ..color = reached ? GardenColors.green : const Color(0xFF9CADA0)
          ..strokeWidth = 2,
      );
      final flag = Path()
        ..moveTo(point.dx, point.dy - 18)
        ..lineTo(point.dx + 12, point.dy - 14)
        ..lineTo(point.dx, point.dy - 10)
        ..close();
      canvas.drawPath(
        flag,
        paint
          ..color = saved
              ? GardenColors.gold
              : reached
              ? collectionRegionColor(region)
              : const Color(0xFFB8C4AC),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PassportMapPainter old) =>
      old.region != region ||
      old.completed != completed ||
      old.total != total ||
      old.progress != progress ||
      !_sameFlags(old.discovered, discovered) ||
      !_sameFlags(old.recorded, recorded);
}

bool _sameFlags(List<bool> a, List<bool> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class CollectionPaperPainter extends CustomPainter {
  const CollectionPaperPainter({required this.passport});
  final bool passport;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = passport ? const Color(0xFFE9E1CC) : const Color(0xFFDDE6D1);
    if (passport) {
      for (var x = 18.0; x < size.width; x += 18) {
        canvas.drawLine(
          Offset(x, 5),
          Offset(x + 7, 5),
          paint..strokeWidth = 1.3,
        );
        canvas.drawLine(
          Offset(x, size.height - 5),
          Offset(x + 7, size.height - 5),
          paint,
        );
      }
      for (var y = 14.0; y < size.height; y += 32) {
        canvas.drawCircle(Offset(5, y), 1.8, paint);
      }
    } else {
      for (var i = 0; i < 4; i++) {
        _leaf(
          canvas,
          Offset(size.width - 11 - i * 9, 7 + i * 11),
          10,
          .7 + i * .25,
          paint.color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CollectionPaperPainter old) => old.passport != passport;
}

class CollectionBadgeArt extends StatelessWidget {
  const CollectionBadgeArt({
    required this.icon,
    required this.earned,
    super.key,
  });
  final IconData icon;
  final bool earned;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(child: CustomPaint(painter: _BadgePainter(earned))),
        Icon(
          icon,
          size: 19,
          color: earned ? const Color(0xFF83602E) : GardenColors.muted,
        ),
      ],
    ),
  );
}

class _BadgePainter extends CustomPainter {
  const _BadgePainter(this.earned);
  final bool earned;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero) - const Offset(0, 2);
    final radius = math.min(size.width, size.height) * .37;
    final ribbon = Path()
      ..moveTo(center.dx - 11, center.dy + 5)
      ..lineTo(center.dx - 13, size.height - 1)
      ..lineTo(center.dx, size.height - 7)
      ..lineTo(center.dx + 13, size.height - 1)
      ..lineTo(center.dx + 11, center.dy + 5)
      ..close();
    canvas.drawPath(
      ribbon,
      Paint()
        ..color = earned ? const Color(0xFFCF8D68) : const Color(0xFFD7DCCE),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = earned ? const Color(0xFFF0CF79) : const Color(0xFFE6EADB),
    );
    canvas.drawCircle(
      center,
      radius - 3,
      Paint()
        ..color = earned ? const Color(0xFFC79947) : GardenColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
  }

  @override
  bool shouldRepaint(_BadgePainter old) => old.earned != earned;
}

void _plant(
  Canvas canvas,
  Offset origin,
  int growth,
  double scale,
  bool ready,
) {
  canvas.save();
  canvas.translate(origin.dx, origin.dy);
  canvas.scale(scale);
  final paint = Paint()
    ..color = const Color(0xFF56865A)
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(Offset.zero, const Offset(0, -40), paint);
  _leaf(canvas, const Offset(0, -16), 19, -2.55, const Color(0xFF79A763));
  _leaf(canvas, const Offset(0, -27), 16, -.55, const Color(0xFF96BA72));
  if (growth >= 3) {
    _flower(
      canvas,
      const Offset(0, -46),
      const Color(0xFFE5A77B),
      const Color(0xFFFFDB72),
      15,
    );
  } else if (growth == 2) {
    canvas.drawOval(
      const Rect.fromLTWH(-10, -57, 20, 27),
      paint..color = const Color(0xFFE7AE78),
    );
    canvas.drawOval(
      const Rect.fromLTWH(-5, -55, 7, 19),
      paint..color = const Color(0xFFF5CA91),
    );
  } else {
    _leaf(canvas, const Offset(0, -39), 16, -2.3, const Color(0xFF9EC179));
    _leaf(canvas, const Offset(0, -39), 16, -.8, const Color(0xFF70A465));
  }
  final soil = Path()
    ..moveTo(-19, -1)
    ..lineTo(-14, 12)
    ..quadraticBezierTo(0, 18, 14, 12)
    ..lineTo(19, -1)
    ..close();
  canvas.drawPath(soil, paint..color = const Color(0xFFBC8962));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(-22, -4, 44, 7),
      const Radius.circular(3),
    ),
    paint..color = const Color(0xFFDEA977),
  );
  if (ready) _sparkle(canvas, const Offset(23, -47), 5, GardenColors.gold);
  canvas.restore();
}

void _flower(
  Canvas canvas,
  Offset center,
  Color petals,
  Color core,
  double radius,
) {
  final paint = Paint()..color = petals;
  for (var i = 0; i < 6; i++) {
    final angle = i * math.pi / 3;
    canvas.drawOval(
      Rect.fromCenter(
        center:
            center + Offset(math.cos(angle), math.sin(angle)) * radius * .58,
        width: radius * .9,
        height: radius * .9,
      ),
      paint,
    );
  }
  canvas.drawCircle(center, radius * .4, paint..color = core);
  canvas.drawCircle(
    center - Offset(radius * .12, radius * .12),
    radius * .13,
    paint..color = Colors.white.withValues(alpha: .55),
  );
}

void _leaf(
  Canvas canvas,
  Offset start,
  double length,
  double angle,
  Color color,
) {
  canvas.save();
  canvas.translate(start.dx, start.dy);
  canvas.rotate(angle);
  final path = Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(length * .4, -length * .6, length, 0)
    ..quadraticBezierTo(length * .5, length * .45, 0, 0)
    ..close();
  canvas.drawPath(path, Paint()..color = color);
  canvas.drawLine(
    Offset.zero,
    Offset(length * .76, 0),
    Paint()
      ..color = Colors.white.withValues(alpha: .25)
      ..strokeWidth = 1,
  );
  canvas.restore();
}

void _sparkle(Canvas canvas, Offset center, double radius, Color color) {
  final path = Path()
    ..moveTo(center.dx, center.dy - radius)
    ..quadraticBezierTo(
      center.dx + 1,
      center.dy - 1,
      center.dx + radius,
      center.dy,
    )
    ..quadraticBezierTo(
      center.dx + 1,
      center.dy + 1,
      center.dx,
      center.dy + radius,
    )
    ..quadraticBezierTo(
      center.dx - 1,
      center.dy + 1,
      center.dx - radius,
      center.dy,
    )
    ..quadraticBezierTo(
      center.dx - 1,
      center.dy - 1,
      center.dx,
      center.dy - radius,
    )
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}
