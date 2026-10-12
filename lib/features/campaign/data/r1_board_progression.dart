import '../domain/board_mechanic_models.dart';
import '../domain/campaign_models.dart';

/// One new physical rule at a time, on an earlier practiced math relationship.
/// Source IDs are evidence links, not free mastery/review credit.
class R1BoardProgression {
  const R1BoardProgression({
    required this.level,
    this.powers = false,
    this.burst = false,
    this.color = false,
    this.combinations = false,
    this.layers = 1,
    this.blockers = 0,
    this.blockerDurability = 1,
    this.lesson,
    this.sourceStageId,
    this.introducingMechanic,
    this.prerequisiteStageIds = const {},
  });
  final int level;
  final bool powers, burst, color, combinations;
  final int layers, blockers, blockerDurability;
  final BoardPowerLesson? lesson;
  final String? sourceStageId;
  final BoardMechanicId? introducingMechanic;
  final Set<String> prerequisiteStageIds;

  static R1BoardProgression forStage(StageDefinition stage) {
    final chapter = int.parse(stage.chapterId.substring(5));
    final s = stage.number;
    if (chapter == 1 && s < 4) return const R1BoardProgression(level: 0);
    if (chapter == 1 || chapter == 2 && s == 1) {
      return R1BoardProgression(
        level: 1,
        powers: true,
        lesson: chapter == 1 && s == 4 ? BoardPowerLesson.line : null,
        introducingMechanic: chapter == 1 && s == 4
            ? BoardMechanicId.linePower
            : null,
        sourceStageId: chapter == 1 && s == 4 ? 'r01-c01-s02' : null,
      );
    }
    if (chapter == 2 && s == 2) {
      return const R1BoardProgression(
        level: 2,
        blockers: 1,
        introducingMechanic: BoardMechanicId.adjacentHitBlocker,
        sourceStageId: 'r01-c02-s01',
      );
    }
    if (chapter == 2 && s < 9)
      return const R1BoardProgression(level: 2, powers: true, blockers: 1);
    if (chapter == 2 && s == 9)
      return const R1BoardProgression(
        level: 3,
        powers: true,
        burst: true,
        lesson: BoardPowerLesson.burst,
        sourceStageId: 'r01-c02-s06',
      );
    if (chapter == 2)
      return const R1BoardProgression(
        level: 4,
        powers: true,
        burst: true,
        color: true,
        lesson: BoardPowerLesson.color,
        sourceStageId: 'r01-c02-s05',
      );
    if (chapter == 3)
      return const R1BoardProgression(
        level: 4,
        powers: true,
        burst: true,
        color: true,
        blockers: 1,
      );
    if (chapter == 4 && s == 1)
      return const R1BoardProgression(
        level: 5,
        layers: 2,
        introducingMechanic: BoardMechanicId.layeredSeal,
        sourceStageId: 'r01-c01-s06',
      );
    if (chapter == 4)
      return R1BoardProgression(
        level: s < 6 ? 5 : 6,
        powers: true,
        burst: s >= 6,
        color: s >= 6,
        layers: 2,
        combinations: s >= 6,
        lesson: s == 6 ? BoardPowerLesson.combination : null,
        sourceStageId: s == 6 ? 'r01-c02-s01' : null,
        prerequisiteStageIds: s < 6
            ? const {'r01-c01-s04', 'r01-c04-s01'}
            : s == 6
            ? const {'r01-c02-s09', 'r01-c02-s10', 'r01-c04-s01'}
            : const {'r01-c04-s06'},
      );
    return R1BoardProgression(
      level: chapter == 5 ? 7 : 8,
      powers: true,
      burst: true,
      color: true,
      combinations: true,
      layers: 2,
      blockers: chapter == 5 ? 2 : 3,
      // Density increases only at a chapter entry with familiar/easier math.
      sourceStageId: s == 1 ? stage.recurrencePlan?.sourceStageId : null,
    );
  }

  MatchDifficulty match(int seals) => MatchDifficulty(
    tier: powers
        ? MatchDifficultyTier.b4
        : layers == 2 || blockers > 0
        ? MatchDifficultyTier.b3
        : MatchDifficultyTier.b1,
    gemKindCount: 5,
    requiredSealCount: seals,
    decoySealCount: 0,
    maxSealLayers: layers,
    obstacleCount: blockers,
    specialRule: powers
        ? MatchSpecialRule.fourMatchPower
        : MatchSpecialRule.none,
    planningDepth: powers
        ? 5
        : layers == 2 || blockers > 0
        ? 4
        : 2,
  );

  BoardMechanicPlan plan(StageDefinition stage, int seals) {
    final advanced =
        (powers ? 1 : 0) + (layers == 2 ? 1 : 0) + (blockers > 0 ? 1 : 0);
    BoardMechanicBinding bind(BoardMechanicRule rule) => BoardMechanicBinding(
      rule: rule,
      skin: BoardMechanicSkin(
        key: '${stage.id.substring(0, 3)}.expedition.${rule.mechanicId.name}',
        mechanicId: rule.mechanicId,
      ),
    );
    return BoardMechanicPlan(
      id: stage.boardMechanicPlan.id,
      challengeLevel: level,
      learningSourceStageId: sourceStageId,
      prerequisiteStageIds: prerequisiteStageIds,
      role: introducingMechanic != null
          ? BoardMechanicRole.introduce
          : advanced == 0
          ? BoardMechanicRole.baseline
          : advanced > 1
          ? BoardMechanicRole.mixed
          : BoardMechanicRole.review,
      bindings: [
        bind(SingleLayerSealRule(sealCount: seals)),
        if (powers)
          bind(
            LinePowerRule(
              requiredActivations: lesson == null ? 0 : 1,
              enableBurst: burst,
              enableColor: color,
              enableCombinations: combinations,
              lesson: lesson,
            ),
          ),
        if (layers == 2)
          bind(LayeredSealRule(sealCount: seals, layers: layers)),
        if (blockers > 0)
          bind(
            AdjacentHitBlockerRule(
              blockerCount: blockers,
              durability: blockerDurability,
            ),
          ),
      ],
    );
  }
}
