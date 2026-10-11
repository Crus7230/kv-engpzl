import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../domain/garden_models.dart';

abstract final class GardenColors {
  static const ink = Color(0xFF243D33);
  static const muted = Color(0xFF627469);
  static const cream = Color(0xFFF5F2E7);
  static const paper = Color(0xFFFFFCF2);
  static const green = Color(0xFF376E52);
  static const moss = Color(0xFF8FA769);
  static const gold = Color(0xFFE7B957);
  static const border = Color(0xFFD8DECE);
}

/// The legacy background remains intact; restoration is a composited layer.
class GardenScene extends StatelessWidget {
  const GardenScene({
    required this.restored,
    this.decorationId = 'wildflowers',
    this.showCharacters = true,
    this.restoredNodeIds = const {},
    this.completedStageCount = 0,
    this.project,
    this.decorationChoices = const {},
    this.unlockedCharacterIds = const {'CHAR_D', 'CHAR_J'},
    super.key,
  });

  final bool restored;
  final String decorationId;
  final bool showCharacters;
  final Set<String> restoredNodeIds;
  final int completedStageCount;
  final GardenProjectScene? project;
  final Map<String, String> decorationChoices;
  final Set<String> unlockedCharacterIds;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final projectNodes = project == null
        ? restoredNodeIds
        : restoredNodeIds
              .where((id) => id.startsWith('${project!.chapterId}-garden-'))
              .toSet();
    final projectDecoration =
        projectNodes
            .map((id) => decorationChoices[id])
            .whereType<String>()
            .lastOrNull ??
        decorationId;
    return Semantics(
      image: true,
      label: restored
          ? '계산의 평원. ${project?.title ?? '화단'}. ${gardenDecorationLabel(projectDecoration)}를 복원했습니다.'
          : '계산의 평원. ${project?.title ?? '화단'}이 복원을 기다립니다.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _LegacyAsset(
              path: 'assets/legacy/plains.png',
              fit: BoxFit.cover,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF193F2B).withValues(alpha: .04),
                    const Color(0xFF1D3C25).withValues(alpha: .3),
                  ],
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: restored ? 1 : .34,
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 350),
              child: CustomPaint(
                painter: _MeadowPainter(
                  restored: restored,
                  decorationId: projectDecoration,
                ),
              ),
            ),
            if (project != null)
              CustomPaint(
                painter: _ProjectEnvironmentPainter(
                  project!.environmentLayerId,
                  projectNodes.length,
                ),
              ),
            if (completedStageCount > 0 || restoredNodeIds.isNotEmpty)
              CustomPaint(
                painter: _RegionalGrowthPainter(
                  restoredNodeIds,
                  completedStageCount,
                  project?.chapterId,
                  decorationChoices,
                ),
              ),
            if (showCharacters) ...[
              if (unlockedCharacterIds.contains('CHAR_D'))
                const Positioned(
                  left: 14,
                  bottom: 8,
                  child: GardenCharacter(
                    assetPath: 'assets/legacy/char-d.png',
                    name: 'Delta',
                    height: 76,
                  ),
                ),
              if (unlockedCharacterIds.contains('CHAR_J'))
                const Positioned(
                  right: 12,
                  bottom: 8,
                  child: GardenCharacter(
                    assetPath: 'assets/legacy/char-j.png',
                    name: 'Juliett',
                    height: 70,
                  ),
                ),
              if (unlockedCharacterIds.contains('CHAR_L'))
                const Align(
                  alignment: Alignment(-.35, 1),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: GardenCharacter(
                      assetPath: 'assets/legacy/char-l.png',
                      name: 'Lima',
                      height: 60,
                    ),
                  ),
                ),
              if (unlockedCharacterIds.contains('CHAR_U'))
                const Align(
                  alignment: Alignment(.35, 1),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: GardenCharacter(
                      assetPath: 'assets/legacy/char-u.png',
                      name: 'Uniform',
                      height: 62,
                    ),
                  ),
                ),
            ],
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: GardenColors.paper.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    (project == null ? '' : '${project!.title}\n') +
                        (completedStageCount > 0
                            ? '탐험 $completedStageCount곳 · 복원 ${restoredNodeIds.length}곳'
                            : restored
                            ? '첫 정원이 깨어났어요'
                            : '들꽃이 돌아올 자리를 찾아요'),
                    style: const TextStyle(
                      color: GardenColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small first-clear changes and milestone structures are separate layers.
class _RegionalGrowthPainter extends CustomPainter {
  _RegionalGrowthPainter(
    this.nodes,
    this.completed,
    this.chapterId,
    this.decorations,
  );
  final Set<String> nodes;
  final int completed;
  final String? chapterId;
  final Map<String, String> decorations;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < math.min(completed, 60); i++) {
      final x = size.width * (.17 + (i % 15) * .047);
      final y = size.height * (.83 + (i ~/ 15) * .02);
      canvas.drawLine(
        Offset(x, y),
        Offset(x, y - 9),
        Paint()
          ..color = const Color(0xFF45744F)
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        Offset(x, y - 11),
        3.5,
        Paint()
          ..color = i.isEven
              ? const Color(0xFFFFDF7E)
              : const Color(0xFFF0B4CF),
      );
    }
    final ordered =
        nodes
            .where(
              (id) =>
                  id.startsWith('r01-c') &&
                  (chapterId == null || id.startsWith('$chapterId-garden-')),
            )
            .toList()
          ..sort();
    for (final nodeId in ordered) {
      final match = RegExp(r'^r01-c(\d+)-garden-(\d+)$').firstMatch(nodeId);
      if (match == null) continue;
      final chapter = int.parse(match.group(1)!);
      final milestone = const [2, 4, 7, 10].indexOf(int.parse(match.group(2)!));
      if (chapter < 1 || chapter > 6 || milestone < 0) continue;
      // Stable slots keep an existing structure in place when a review branch
      // restores an earlier node after a later chapter's node.
      final i = (chapter - 1) * 4 + milestone;
      final point = Offset(
        size.width *
            (chapterId == null ? .17 + (i % 6) * .132 : .2 + milestone * .2),
        size.height * (chapterId == null ? .7 + (i ~/ 6) * .05 : .74),
      );
      final radius = size.height * .027;
      final accent = switch (decorations[nodeId]) {
        'herbs' => const Color(0xFF689661),
        'stone-path' => const Color(0xFFE4DABB),
        _ => const Color(0xFFF0B4CF),
      };
      canvas.drawCircle(
        point.translate(0, radius * 1.5),
        radius * .6,
        Paint()..color = accent,
      );
      if (i % 3 == 0) {
        canvas.drawOval(
          Rect.fromCenter(
            center: point,
            width: radius * 3.4,
            height: radius * 1.4,
          ),
          Paint()..color = const Color(0xFFA2C7CE),
        );
        canvas.drawLine(
          point,
          point.translate(0, -radius * 2),
          Paint()
            ..color = const Color(0xFFE2E7C9)
            ..strokeWidth = 4,
        );
        canvas.drawCircle(
          point.translate(0, -radius * 2),
          radius * .65,
          Paint()..color = const Color(0xFFE2E7C9),
        );
      } else if (i % 3 == 1) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: point, width: radius * 3, height: radius),
            const Radius.circular(3),
          ),
          Paint()..color = const Color(0xFFB79062),
        );
        for (final offset in [-1, 1])
          canvas.drawLine(
            point.translate(offset * radius, 0),
            point.translate(offset * radius, radius),
            Paint()
              ..color = const Color(0xFF614E37)
              ..strokeWidth = 3,
          );
      } else {
        final arch = Path()
          ..moveTo(point.dx - radius, point.dy + radius)
          ..lineTo(point.dx - radius, point.dy - radius)
          ..quadraticBezierTo(
            point.dx,
            point.dy - radius * 2.8,
            point.dx + radius,
            point.dy - radius,
          )
          ..lineTo(point.dx + radius, point.dy + radius);
        canvas.drawPath(
          arch,
          Paint()
            ..color = const Color(0xFFE4DABB)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
        canvas.drawCircle(
          point.translate(-radius, -radius),
          radius * .5,
          Paint()..color = const Color(0xFF689661),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RegionalGrowthPainter oldDelegate) =>
      oldDelegate.completed != completed ||
      oldDelegate.chapterId != chapterId ||
      !mapEquals(oldDelegate.decorations, decorations) ||
      !setEquals(oldDelegate.nodes, nodes);
}

/// Six chapter projects reuse the plains bitmap and add lightweight layers.
class _ProjectEnvironmentPainter extends CustomPainter {
  const _ProjectEnvironmentPainter(this.layer, this.restoredCount);
  final String layer;
  final int restoredCount;

  @override
  void paint(Canvas canvas, Size size) {
    if (restoredCount == 0) return;
    final unit = size.height * .045;
    final ground = size.height * .73;
    final timber = Paint()..color = const Color(0xFF806449);
    final foliage = Paint()..color = const Color(0xFF548559);
    switch (layer) {
      case 'orchard':
        for (var i = 0; i < math.min(restoredCount, 3); i++) {
          final x = size.width * (.3 + i * .2);
          canvas.drawRect(
            Rect.fromLTWH(x - unit * .2, ground - unit, unit * .4, unit * 2),
            timber,
          );
          canvas.drawCircle(
            Offset(x, ground - unit * 1.4),
            unit * 1.4,
            foliage,
          );
          canvas.drawCircle(
            Offset(x - unit * .4, ground - unit * 1.7),
            unit * .3,
            Paint()..color = const Color(0xFFE7B957),
          );
        }
      case 'pond':
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(size.width * .5, ground),
            width: size.width * .38,
            height: unit * 2.5,
          ),
          Paint()..color = const Color(0xFF8FCDDA),
        );
        for (var i = 0; i < restoredCount; i++) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(size.width * (.36 + i * .08), ground),
              width: unit,
              height: unit * .6,
            ),
            foliage,
          );
        }
      case 'memory-path':
        for (var i = 0; i < restoredCount * 2; i++) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(
                size.width * (.28 + i * .055),
                ground + math.sin(i) * unit,
              ),
              width: unit * 1.1,
              height: unit * .6,
            ),
            Paint()..color = const Color(0xFFE4DABB),
          );
        }
      case 'workshop':
        final center = Offset(size.width * .5, ground - unit);
        canvas.drawRect(
          Rect.fromCenter(center: center, width: unit * 4, height: unit * 2.8),
          timber,
        );
        final roof = Path()
          ..moveTo(center.dx - unit * 2.5, center.dy - unit)
          ..lineTo(center.dx, center.dy - unit * 3)
          ..lineTo(center.dx + unit * 2.5, center.dy - unit)
          ..close();
        canvas.drawPath(roof, foliage);
        canvas.drawRect(
          Rect.fromCenter(
            center: center.translate(0, unit * .6),
            width: unit,
            height: unit * 1.6,
          ),
          Paint()..color = const Color(0xFFE4DABB),
        );
      case 'lookout':
        final x = size.width * .5;
        canvas.drawRect(
          Rect.fromLTWH(x - unit * 2, ground - unit * 3, unit * .5, unit * 4),
          timber,
        );
        canvas.drawRect(
          Rect.fromLTWH(x + unit * 1.5, ground - unit * 3, unit * .5, unit * 4),
          timber,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            x - unit * 2.5,
            ground - unit * 3.4,
            unit * 5,
            unit * .5,
          ),
          Paint()..color = const Color(0xFFE4DABB),
        );
        if (restoredCount == 4)
          canvas.drawCircle(
            Offset(x, ground - unit * 3.6),
            unit * .7,
            Paint()..color = GardenColors.gold,
          );
      case 'flowerbeds':
        for (var i = 0; i < restoredCount; i++) {
          canvas.drawCircle(
            Offset(size.width * (.32 + i * .12), ground - unit),
            unit * .4,
            Paint()..color = const Color(0xFFF0B4CF),
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant _ProjectEnvironmentPainter oldDelegate) =>
      oldDelegate.layer != layer || oldDelegate.restoredCount != restoredCount;
}

class GardenCharacter extends StatelessWidget {
  const GardenCharacter({
    required this.assetPath,
    required this.name,
    this.height = 72,
    super.key,
  });

  final String assetPath;
  final String name;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: '탐험대 캐릭터 $name',
    child: SizedBox(
      height: height,
      width: height,
      child: Image.asset(
        assetPath,
        cacheHeight: (height * MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(1, 1500),
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => const DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: GardenColors.paper,
          ),
          child: Icon(Icons.face_rounded, color: GardenColors.green, size: 36),
        ),
      ),
    ),
  );
}

class _LegacyAsset extends StatelessWidget {
  const _LegacyAsset({required this.path, required this.fit});

  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Image.asset(
      path,
      cacheWidth:
          (math.max(constraints.maxWidth, constraints.maxHeight * 2816 / 1536) *
                  MediaQuery.devicePixelRatioOf(context))
              .ceil()
              .clamp(1, 2816),
      fit: fit,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDFEDD5), Color(0xFF769B61)],
          ),
        ),
      ),
    ),
  );
}

class _MeadowPainter extends CustomPainter {
  const _MeadowPainter({required this.restored, required this.decorationId});

  final bool restored;
  final String decorationId;

  @override
  void paint(Canvas canvas, Size size) {
    final bed = Rect.fromLTWH(
      size.width * .29,
      size.height * .67,
      size.width * .4,
      size.height * .24,
    );
    canvas.drawOval(bed, Paint()..color = const Color(0xFF745E3C));
    canvas.drawOval(
      bed.deflate(size.height * .025),
      Paint()
        ..color = restored ? const Color(0xFF88A45D) : const Color(0xFF8B7C5E),
    );
    if (!restored) {
      final stonePaint = Paint()..color = const Color(0xFFB7B49A);
      for (var index = 0; index < 6; index += 1) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(
              bed.left + bed.width * (index + 1) / 7,
              bed.center.dy + math.sin(index * 1.7) * bed.height * .2,
            ),
            width: size.height * .07,
            height: size.height * .045,
          ),
          stonePaint,
        );
      }
      return;
    }
    if (decorationId == 'stone-path') {
      for (var index = 0; index < 7; index += 1) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(
                bed.left + bed.width * (index + 1) / 8,
                bed.center.dy + math.sin(index) * bed.height * .13,
              ),
              width: bed.width * .095,
              height: bed.height * .34,
            ),
            const Radius.circular(5),
          ),
          Paint()..color = const Color(0xFFE6DFBE),
        );
      }
    }
    for (var index = 0; index < 22; index += 1) {
      final x = bed.left + bed.width * (.08 + (index % 11) * .079);
      final y = bed.top + bed.height * (.3 + (index ~/ 11) * .4);
      final radius = size.height * .014;
      canvas.drawLine(
        Offset(x, y),
        Offset(x, y - radius * 3),
        Paint()
          ..color = const Color(0xFF326545)
          ..strokeWidth = 2,
      );
      if (decorationId == 'herbs') {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x - radius, y - radius * 2),
            width: radius * 3,
            height: radius * 1.7,
          ),
          Paint()..color = const Color(0xFF2B6D4E),
        );
      } else {
        final flowerPaint = Paint()
          ..color = index.isEven
              ? const Color(0xFFF4DF83)
              : const Color(0xFFF1B8C1);
        for (var petal = 0; petal < 5; petal += 1) {
          final angle = petal * math.pi * 2 / 5;
          canvas.drawCircle(
            Offset(
              x + math.cos(angle) * radius,
              y - radius * 3 + math.sin(angle) * radius,
            ),
            radius * .7,
            flowerPaint,
          );
        }
        canvas.drawCircle(
          Offset(x, y - radius * 3),
          radius * .42,
          Paint()..color = const Color(0xFFB58736),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MeadowPainter oldDelegate) =>
      oldDelegate.restored != restored ||
      oldDelegate.decorationId != decorationId;
}
