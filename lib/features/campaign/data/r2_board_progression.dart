import '../domain/board_mechanic_models.dart';
import '../domain/campaign_models.dart';
import 'r1_board_progression.dart';

/// Reuses the implemented rule vocabulary, never the blueprint's planned locks.
/// Mathematical introductions keep a light, unchanged board. Physical increases
/// happen only in source-linked retrieval/workshop stages with familiar math.
class R2BoardProgression {
  static R1BoardProgression forStage(StageDefinition stage) {
    final chapter = int.parse(stage.chapterId.substring(5));
    final s = stage.number;
    if (chapter <= 3) {
      return const R1BoardProgression(
        level: 4,
        powers: true,
        burst: true,
        color: true,
        blockers: 1,
      );
    }
    if (chapter == 4 && s == 1) {
      return const R1BoardProgression(
        level: 5,
        layers: 2,
        sourceStageId: 'r02-c01-s06',
      );
    }
    if (chapter == 4) {
      return R1BoardProgression(
        level: s < 6 ? 5 : 6,
        layers: 2,
        powers: true,
        burst: s >= 6,
        color: s >= 6,
        combinations: s >= 6,
        lesson: s == 6 ? BoardPowerLesson.combination : null,
        sourceStageId: s == 6 ? 'r02-c02-s01' : null,
        prerequisiteStageIds: s < 6
            ? const {'r02-c04-s01'}
            : s == 6
            ? const {'r02-c04-s01'}
            : const {'r02-c04-s06'},
      );
    }
    return R1BoardProgression(
      level: chapter == 5 ? (s < 6 ? 7 : 8) : 9,
      powers: true,
      burst: true,
      color: true,
      combinations: true,
      layers: 2,
      blockers: chapter == 5 ? 2 : 3,
      blockerDurability: chapter == 5 && s < 6 ? 1 : 2,
      sourceStageId: s == 1 || chapter == 5 && s == 6
          ? stage.recurrencePlan?.sourceStageId
          : null,
    );
  }
}
