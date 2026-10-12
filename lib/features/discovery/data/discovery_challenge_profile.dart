import '../../campaign/domain/campaign_models.dart';
import '../domain/discovery_models.dart';
import 'discovery_excavation_profile.dart';

/// V5 changes new attempts only. V1/V3/V4 content is never rewritten.
class DiscoveryChallengeProfile {
  static bool isTutorial(StageDefinition stage) =>
      stage.id == 'r01-c01-s01' || stage.id == 'prototype-bundle-add';

  /// New v5 attempts only. Dimensions are the usable landscape viewport after
  /// SafeArea; restoring a session must keep its saved rows and columns.
  static DiscoveryBoardConfig boardFor(
    StageDefinition stage,
    double width,
    double height,
  ) {
    if (isTutorial(stage) || width < 600 || height < 288) {
      return DiscoveryBoardConfig.compactPhone;
    }
    // Density is introduced on the existing familiar-math C04+ lessons, not
    // at the same time as a harder mathematical relationship.
    if (forStage(stage).dense && width >= 720 && height >= 320) {
      return DiscoveryBoardConfig.densePhone;
    }
    return DiscoveryBoardConfig.standardPhone;
  }

  static DiscoveryExcavationProfile forStage(StageDefinition stage) {
    if (isTutorial(stage)) return const DiscoveryExcavationProfile();
    final base = DiscoveryExcavationProfile.forStage(stage);
    final chapter = int.tryParse(stage.chapterId.split('-c').last) ?? 1;
    final blueGoal = chapter >= 5 ? 20 : 18;
    return DiscoveryExcavationProfile(
      ice: base.ice,
      falling: base.falling,
      // Collection goals count gems, not turns. A good cascade saves moves.
      colorGoals: {
        'B': blueGoal,
        for (final entry in base.colorGoals.entries)
          if (entry.key != 'B') entry.key: entry.value,
      },
      dense: base.dense,
    );
  }

  static StageDefinition stageFor(StageDefinition stage) {
    if (isTutorial(stage) || !stage.isPlayable) return stage;
    final later = stage.moveLimit >= 20;
    return StageDefinition(
      id: stage.id,
      chapterId: stage.chapterId,
      skillId: stage.skillId,
      number: stage.number,
      title: stage.title,
      conceptLabel: stage.conceptLabel,
      answerExpression: stage.answerExpression,
      puzzleId: stage.puzzleId,
      contentStatus: stage.contentStatus,
      mathDifficulty: stage.mathDifficulty,
      matchDifficulty: MatchDifficulty(
        tier: stage.matchDifficulty.tier,
        gemKindCount: stage.matchDifficulty.gemKindCount,
        requiredSealCount: stage.matchDifficulty.requiredSealCount,
        decoySealCount: stage.matchDifficulty.decoySealCount,
        maxSealLayers: stage.matchDifficulty.maxSealLayers,
        obstacleCount: stage.matchDifficulty.obstacleCount,
        specialRule: stage.matchDifficulty.specialRule,
        planningDepth: stage.matchDifficulty.tier == MatchDifficultyTier.b1
            ? 2
            : stage.matchDifficulty.planningDepth,
        hasScriptedOpening: false,
      ),
      boardMechanicPlan: stage.boardMechanicPlan,
      boardVariants: stage.boardVariants,
      moveBudget: StageMoveBudget(
        referenceMoves: later ? 16 : 14,
        parMoves: later ? 18 : 16,
        moveLimit: later ? 20 : 18,
      ),
      starRules: stage.starRules,
      assistRules: stage.assistRules,
      learningPlan: stage.learningPlan,
      variantProfile: stage.variantProfile,
      recurrencePlan: stage.recurrencePlan,
      sentenceMathPlan: stage.sentenceMathPlan,
      seed: stage.seed,
      startingTokenIds: stage.startingTokenIds,
      buriedTokenIds: stage.buriedTokenIds,
      decoyTokenIds: stage.decoyTokenIds,
    );
  }

  static BoardLayoutVariant variantFor(
    StageDefinition stage,
    DiscoveryBoardConfig config, {
    int? seed,
  }) {
    final legacy = DiscoveryExcavationProfile.variantFor(stage, config);
    final boardSeed = seed ?? legacy.seed;
    if (boardSeed < 0 || boardSeed > 0xffffffff) {
      throw ArgumentError.value(
        boardSeed,
        'seed',
        'Expected an unsigned 32-bit seed.',
      );
    }
    return BoardLayoutVariant(
      config: config,
      fixtureId:
          '${stage.id}-${config.rows}x${config.columns}-$boardSeed-random5',
      seed: boardSeed,
      // The independent random candidate is validated at construction.
      isVerified: true,
    );
  }
}
