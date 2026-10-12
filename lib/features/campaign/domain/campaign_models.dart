import '../../discovery/domain/discovery_models.dart';
import 'board_mechanic_models.dart';
import 'learning_models.dart';
import 'sentence_math_plan.dart';
import 'stage_attempt_metrics.dart';
import 'stage_recurrence_models.dart';

export 'stage_attempt_metrics.dart';

enum StageContentStatus {
  /// The campaign slot exists, but its puzzle has not been authored.
  planned,

  /// The puzzle and token plan exist, but verified board fixtures do not.
  puzzleReady,

  /// The puzzle, token plan, and board fixtures are verified for play.
  playable,
}

enum MathDifficultyTier { m0, m1, m2, m3, m4 }

enum MatchDifficultyTier { b0, b1, b2, b3, b4 }

enum CompositionTier { c0, c1, c2, c3 }

enum ReadingTier { r0, r1, r2 }

enum MatchSpecialRule { none, fourMatchPower }

enum StageTutorialMode { forced, contextual, optional, none }

class MathDifficulty {
  const MathDifficulty({
    required this.tier,
    required this.compositionTier,
    required this.readingTier,
    required this.reasoningSteps,
    required this.operatorKindCount,
    required this.usesOrderOfOperations,
    required this.requiresParentheses,
  }) : assert(reasoningSteps >= 1),
       assert(operatorKindCount >= 1 && operatorKindCount <= 4);

  final MathDifficultyTier tier;
  final CompositionTier compositionTier;
  final ReadingTier readingTier;

  /// Number of binary calculations required by the intended expression.
  final int reasoningSteps;
  final int operatorKindCount;
  final bool usesOrderOfOperations;
  final bool requiresParentheses;
}

class MatchDifficulty {
  const MatchDifficulty({
    required this.tier,
    required this.gemKindCount,
    required this.requiredSealCount,
    required this.decoySealCount,
    required this.maxSealLayers,
    required this.obstacleCount,
    required this.specialRule,
    required this.planningDepth,
    this.hasScriptedOpening = false,
  }) : assert(gemKindCount >= 3),
       assert(requiredSealCount >= 1),
       assert(decoySealCount >= 0),
       assert(maxSealLayers >= 1),
       assert(obstacleCount >= 0),
       assert(planningDepth >= 1 && planningDepth <= 5);

  final MatchDifficultyTier tier;
  final int gemKindCount;
  final int requiredSealCount;
  final int decoySealCount;
  final int maxSealLayers;
  final int obstacleCount;
  final MatchSpecialRule specialRule;

  /// Relative look-ahead expected from the player, from 1 (local) to 5.
  final int planningDepth;
  final bool hasScriptedOpening;
}

class BoardLayoutVariant {
  const BoardLayoutVariant({
    required this.config,
    required this.fixtureId,
    required this.seed,
    required this.isVerified,
  }) : assert(fixtureId != '');

  final DiscoveryBoardConfig config;
  final String fixtureId;

  /// Board seed is independent for each physical layout variant.
  final int seed;
  final bool isVerified;
}

/// Physical board layouts that implement the same logical stage.
///
/// Layout variants are deliberately outside [MatchDifficulty]. Compact and
/// expanded fixtures keep the same token plan and W/P/L move budget.
class BoardLayoutVariants {
  BoardLayoutVariants({required Iterable<BoardLayoutVariant> variants})
    : variants = List.unmodifiable(variants);

  final List<BoardLayoutVariant> variants;

  bool supports(DiscoveryBoardConfig candidate) => variants.any(
    (variant) =>
        variant.config.rows == candidate.rows &&
        variant.config.columns == candidate.columns,
  );

  BoardLayoutVariant variantFor(DiscoveryBoardConfig candidate) =>
      variants.singleWhere(
        (variant) =>
            variant.config.rows == candidate.rows &&
            variant.config.columns == candidate.columns,
      );
}

/// W/P/L: verified reference path, exploration-star par, and fail limit.
class StageMoveBudget {
  const StageMoveBudget({
    required this.referenceMoves,
    required this.parMoves,
    required this.moveLimit,
  }) : assert(referenceMoves >= 1),
       assert(parMoves >= referenceMoves),
       assert(moveLimit >= parMoves);

  final int referenceMoves;
  final int parMoves;
  final int moveLimit;

  int get completionSlack => moveLimit - referenceMoves;
  int get explorationSlack => parMoves - referenceMoves;
}

class StageAssistRules {
  const StageAssistRules({
    required this.tutorialMode,
    required this.freeHintCount,
    required this.showsSuggestedSwap,
    required this.allowsFreeRestart,
  }) : assert(freeHintCount >= 0);

  final StageTutorialMode tutorialMode;
  final int freeHintCount;
  final bool showsSuggestedSwap;
  final bool allowsFreeRestart;
}

class StageStarResult {
  const StageStarResult({
    required this.completion,
    required this.mathMastery,
    required this.exploration,
  });

  final bool completion;
  final bool mathMastery;
  final bool exploration;

  int get total =>
      (completion ? 1 : 0) + (mathMastery ? 1 : 0) + (exploration ? 1 : 0);
}

class StageStarRules {
  const StageStarRules({
    this.maxMathHintTierForMathStar = 1,
    this.requiresFirstMeaningfulSubmission = true,
    this.requiresNoDirectPathHint = true,
  }) : assert(maxMathHintTierForMathStar >= 0);

  final int maxMathHintTierForMathStar;
  final bool requiresFirstMeaningfulSubmission;
  final bool requiresNoDirectPathHint;

  StageStarResult evaluate(
    StageAttemptMetrics metrics,
    StageMoveBudget moveBudget,
  ) {
    final completed = metrics.completed;
    final submissionRequirement =
        !requiresFirstMeaningfulSubmission ||
        (metrics.meaningfulSubmissionCount > 0 &&
            metrics.firstMeaningfulSubmissionCorrect);
    final mathMastery =
        completed &&
        submissionRequirement &&
        metrics.highestMathHintTierUsed <= maxMathHintTierForMathStar;
    final pathHintRequirement =
        !requiresNoDirectPathHint || !metrics.usedDirectPathHint;
    final exploration =
        completed &&
        metrics.movesUsed <= moveBudget.parMoves &&
        pathHintRequirement;
    return StageStarResult(
      completion: completed,
      mathMastery: mathMastery,
      exploration: exploration,
    );
  }
}

/// Responsive selection area on the world map.
///
/// All values are normalized to the uncropped source map rather than a device
/// size. The presentation layer is responsible for applying the same crop or
/// letterbox transform to both the map and this hotspot.
class NormalizedMapHotspot {
  const NormalizedMapHotspot({
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
  });

  final double centerX;
  final double centerY;
  final double width;
  final double height;

  double get left => centerX - width / 2;
  double get top => centerY - height / 2;
  double get right => centerX + width / 2;
  double get bottom => centerY + height / 2;

  bool contains({required double x, required double y}) =>
      x >= left && x <= right && y >= top && y <= bottom;

  bool get hasNormalizedValues =>
      centerX >= 0 &&
      centerX <= 1 &&
      centerY >= 0 &&
      centerY <= 1 &&
      width > 0 &&
      width <= 1 &&
      height > 0 &&
      height <= 1;
}

/// Logical keys resolved by the presentation asset registry.
///
/// Keeping logical keys here avoids coupling campaign data to a particular
/// Flutter asset path or resolution variant.
class RegionVisualAssetKeys {
  const RegionVisualAssetKeys({
    required this.worldOverlay,
    required this.regionBackground,
    required this.mapMarker,
    required this.completionBadge,
  });

  final String worldOverlay;
  final String regionBackground;
  final String mapMarker;
  final String completionBadge;

  Iterable<String> get values sync* {
    yield worldOverlay;
    yield regionBackground;
    yield mapMarker;
    yield completionBadge;
  }
}

/// Stable world-map metadata that can be authored before chapter content.
class RegionMetadata {
  RegionMetadata({
    required this.id,
    required this.legacyId,
    required this.number,
    required this.title,
    required this.description,
    required this.prerequisiteRegionId,
    String? accessGateStageId,
    required this.finalStageId,
    required Iterable<String> featuredCharacterIds,
    required this.visualAssets,
    required this.hotspot,
  }) : accessGateStageId = accessGateStageId ?? finalStageId,
       featuredCharacterIds = List.unmodifiable(featuredCharacterIds);

  final String id;

  /// Original Android territory ID, retained for progress migration.
  final String legacyId;
  final int number;
  final String title;
  final String description;

  /// A region unlocks from completion of the preceding region's access gate.
  final String? prerequisiteRegionId;

  /// Core-path milestone that opens the next region without requiring the
  /// optional mastery chapters to be cleared first.
  final String accessGateStageId;

  /// Completion of the full regional mastery path.
  final String finalStageId;
  final List<String> featuredCharacterIds;
  final RegionVisualAssetKeys visualAssets;
  final NormalizedMapHotspot hotspot;

  RegionDefinition bindChapters(Iterable<ChapterDefinition> chapters) =>
      RegionDefinition(metadata: this, chapters: chapters);
}

class StageDefinition {
  StageDefinition({
    required this.id,
    required this.chapterId,
    required this.skillId,
    required this.number,
    required this.title,
    required this.conceptLabel,
    required this.answerExpression,
    required this.puzzleId,
    required this.contentStatus,
    required this.mathDifficulty,
    required this.matchDifficulty,
    required this.boardMechanicPlan,
    required this.boardVariants,
    required this.moveBudget,
    required this.starRules,
    required this.assistRules,
    required this.learningPlan,
    required this.variantProfile,
    this.recurrencePlan,
    this.sentenceMathPlan,
    required this.seed,
    Iterable<String> startingTokenIds = const [],
    Iterable<String> buriedTokenIds = const [],
    Iterable<String> decoyTokenIds = const [],
  }) : assert(id != ''),
       assert(chapterId != ''),
       assert(skillId != ''),
       assert(number >= 1),
       assert(title != ''),
       assert(conceptLabel != ''),
       assert(puzzleId != ''),
       startingTokenIds = Set.unmodifiable(startingTokenIds),
       buriedTokenIds = Set.unmodifiable(buriedTokenIds),
       decoyTokenIds = Set.unmodifiable(decoyTokenIds);

  final String id;
  final String chapterId;

  /// Stable curriculum key, independent from localized titles and puzzle IDs.
  final String skillId;
  final int number;
  final String title;
  final String conceptLabel;

  /// Intended answer expression used for difficulty metadata and authoring.
  final String answerExpression;
  final String puzzleId;
  final StageContentStatus contentStatus;
  final MathDifficulty mathDifficulty;
  final MatchDifficulty matchDifficulty;
  final BoardMechanicPlan boardMechanicPlan;
  final BoardLayoutVariants boardVariants;
  final StageMoveBudget moveBudget;
  final StageStarRules starRules;
  final StageAssistRules assistRules;
  final StageLearningPlan learningPlan;
  final LearningVariantProfile variantProfile;
  final StageRecurrencePlan? recurrencePlan;
  final SentenceMathPlan? sentenceMathPlan;

  /// Deterministic problem seed. Board seeds live on layout fixtures.
  final int seed;

  /// Tokens available before the match-3 portion starts.
  final Set<String> startingTokenIds;

  /// Required tokens uncovered on this stage's single logical board.
  final Set<String> buriedTokenIds;

  /// Optional discovered distractors that do not belong in the answer.
  final Set<String> decoyTokenIds;

  String get stageLabel => '$chapterId-$number';
  bool get hasAuthoredPuzzle => contentStatus != StageContentStatus.planned;
  bool get isPlayable => contentStatus == StageContentStatus.playable;
  int get moveLimit => moveBudget.moveLimit;
}

class ChapterDefinition {
  ChapterDefinition({
    required this.id,
    required this.number,
    required this.title,
    required this.description,
    required this.prerequisiteChapterId,
    required Iterable<StageDefinition> stages,
  }) : assert(id != ''),
       assert(number >= 1),
       assert(title != ''),
       assert(description != ''),
       stages = List.unmodifiable(stages);

  final String id;
  final int number;
  final String title;
  final String description;

  /// A chapter unlocks from prior completion, never from total star count.
  final String? prerequisiteChapterId;
  final List<StageDefinition> stages;

  int get availableStarCount => stages.length * 3;
}

class RegionDefinition {
  RegionDefinition({
    required this.metadata,
    required Iterable<ChapterDefinition> chapters,
  }) : chapters = List.unmodifiable(chapters);

  final RegionMetadata metadata;
  final List<ChapterDefinition> chapters;

  String get id => metadata.id;
  String get legacyId => metadata.legacyId;
  int get number => metadata.number;
  String get title => metadata.title;
  String get description => metadata.description;
  String? get prerequisiteRegionId => metadata.prerequisiteRegionId;
  String get accessGateStageId => metadata.accessGateStageId;
  String get finalStageId => metadata.finalStageId;
  List<String> get featuredCharacterIds => metadata.featuredCharacterIds;
  RegionVisualAssetKeys get visualAssets => metadata.visualAssets;
  NormalizedMapHotspot get hotspot => metadata.hotspot;

  Iterable<StageDefinition> get stages sync* {
    for (final chapter in chapters) {
      yield* chapter.stages;
    }
  }

  int get availableStarCount =>
      chapters.fold(0, (sum, chapter) => sum + chapter.availableStarCount);

  bool isFinalStage(String stageId) => finalStageId == stageId;
  bool isAccessGateStage(String stageId) => accessGateStageId == stageId;

  StageDefinition? stageById(String stageId) {
    for (final stage in stages) {
      if (stage.id == stageId) {
        return stage;
      }
    }
    return null;
  }
}

class CampaignDefinition {
  CampaignDefinition({
    required this.id,
    required this.version,
    required Iterable<ChapterDefinition> chapters,
  }) : assert(id != ''),
       assert(version >= 1),
       regions = List.unmodifiable([
         _compatibilityRegion(id: id, chapters: chapters),
       ]);

  CampaignDefinition.regional({
    required this.id,
    required this.version,
    required Iterable<RegionDefinition> regions,
  }) : assert(id != ''),
       assert(version >= 1),
       regions = List.unmodifiable(regions);

  final String id;
  final int version;
  final List<RegionDefinition> regions;

  /// Flattened compatibility view for code written before regions existed.
  List<ChapterDefinition> get chapters =>
      List.unmodifiable([for (final region in regions) ...region.chapters]);

  Iterable<StageDefinition> get stages sync* {
    for (final chapter in chapters) {
      yield* chapter.stages;
    }
  }

  RegionDefinition? regionById(String id) {
    for (final region in regions) {
      if (region.id == id || region.legacyId == id) {
        return region;
      }
    }
    return null;
  }

  StageDefinition? stageById(String id) {
    for (final stage in stages) {
      if (stage.id == id) {
        return stage;
      }
    }
    return null;
  }

  StageDefinition? nextStageAfter(String id) {
    final current = stageById(id);
    final nextStageId = current?.learningPlan.nextStageId;
    return nextStageId == null ? null : stageById(nextStageId);
  }
}

RegionDefinition _compatibilityRegion({
  required String id,
  required Iterable<ChapterDefinition> chapters,
}) {
  final chapterList = List<ChapterDefinition>.unmodifiable(chapters);
  assert(chapterList.isNotEmpty);
  assert(chapterList.every((chapter) => chapter.stages.isNotEmpty));
  final finalStageId = chapterList.last.stages.last.id;
  return RegionDefinition(
    metadata: RegionMetadata(
      id: '$id-compatibility-region',
      legacyId: 'UNMIGRATED',
      number: 1,
      title: 'Compatibility region',
      description: 'Temporary wrapper for a pre-region campaign.',
      prerequisiteRegionId: null,
      finalStageId: finalStageId,
      featuredCharacterIds: const ['CHAR_A'],
      visualAssets: const RegionVisualAssetKeys(
        worldOverlay: 'compatibility.world-overlay',
        regionBackground: 'compatibility.region-background',
        mapMarker: 'compatibility.map-marker',
        completionBadge: 'compatibility.completion-badge',
      ),
      hotspot: const NormalizedMapHotspot(
        centerX: 0.5,
        centerY: 0.5,
        width: 0.2,
        height: 0.2,
      ),
    ),
    chapters: chapterList,
  );
}
