import '../../discovery/domain/discovery_models.dart';
import '../domain/board_mechanic_models.dart';
import '../domain/campaign_models.dart';
import '../domain/learning_models.dart';
import '../domain/stage_recurrence_models.dart';
import 'legacy_region_catalog.dart';
import 'sentence_math_curriculum.dart';

/// Authoritative seven-region curriculum blueprint.
///
/// Every stage remains [StageContentStatus.planned] until its localized prompt,
/// token manifest, and equivalent 5x5/6x6 board fixtures are authored and
/// verified. W/P/L values are design targets, not measured solver results yet.
final CampaignDefinition regionalCampaign = CampaignDefinition.regional(
  id: 'equation-discovery-regional-campaign',
  version: 4,
  regions: _buildRegions(),
);

List<RegionDefinition> _buildRegions() {
  final regions = <RegionDefinition>[];
  final orderedStageIds = <String>[
    for (
      var regionIndex = 0;
      regionIndex < _regionPlans.length;
      regionIndex += 1
    )
      for (
        var chapterIndex = 0;
        chapterIndex < _regionPlans[regionIndex].chapters.length;
        chapterIndex += 1
      )
        for (
          var stageIndex = 0;
          stageIndex <
              _regionPlans[regionIndex].chapters[chapterIndex].stages.length;
          stageIndex += 1
        )
          _stageId(regionIndex + 1, chapterIndex + 1, stageIndex + 1),
  ];
  final nextStageIdById = <String, String?>{
    for (
      var regionIndex = 0;
      regionIndex < _regionPlans.length;
      regionIndex += 1
    )
      for (var index = 0; index < 60; index += 1)
        orderedStageIds[regionIndex * 60 + index]: index < 59
            ? orderedStageIds[regionIndex * 60 + index + 1]
            : null,
  };
  final stageOrdinalById = <String, int>{
    for (var index = 0; index < orderedStageIds.length; index += 1)
      orderedStageIds[index]: index + 1,
  };
  final introducedBoardMechanics = <BoardMechanicId>{};
  var previousRegionSkills = const <String>{};
  for (final metadata in legacyRegionCatalog) {
    final plan = _regionPlans.singleWhere(
      (candidate) => candidate.regionId == metadata.id,
    );
    regions.add(
      metadata.bindChapters(
        _buildChapters(
          regionNumber: metadata.number,
          plan: plan,
          previousRegionSkills: previousRegionSkills,
          nextStageIdById: nextStageIdById,
          introducedBoardMechanics: introducedBoardMechanics,
          stageOrdinalById: stageOrdinalById,
        ),
      ),
    );
    previousRegionSkills = {
      for (final chapter in plan.chapters.take(3))
        for (final stage in chapter.stages) _masterySkillId(stage.skillId),
    };
  }
  return regions;
}

List<ChapterDefinition> _buildChapters({
  required int regionNumber,
  required _RegionPlan plan,
  required Set<String> previousRegionSkills,
  required Map<String, String?> nextStageIdById,
  required Set<BoardMechanicId> introducedBoardMechanics,
  required Map<String, int> stageOrdinalById,
}) {
  final chapters = <ChapterDefinition>[];
  var previousChapterSkills = previousRegionSkills;
  for (
    var chapterIndex = 0;
    chapterIndex < plan.chapters.length;
    chapterIndex += 1
  ) {
    final chapterPlan = plan.chapters[chapterIndex];
    chapters.add(
      _buildChapter(
        regionNumber: regionNumber,
        chapterNumber: chapterIndex + 1,
        plan: chapterPlan,
        previousChapterSkills: previousChapterSkills,
        nextStageIdById: nextStageIdById,
        introducedBoardMechanics: introducedBoardMechanics,
        stageOrdinalById: stageOrdinalById,
      ),
    );
    previousChapterSkills = {
      for (final stage in chapterPlan.stages) _masterySkillId(stage.skillId),
    };
  }
  return chapters;
}

ChapterDefinition _buildChapter({
  required int regionNumber,
  required int chapterNumber,
  required _ChapterPlan plan,
  required Set<String> previousChapterSkills,
  required Map<String, String?> nextStageIdById,
  required Set<BoardMechanicId> introducedBoardMechanics,
  required Map<String, int> stageOrdinalById,
}) {
  final chapterId = _chapterId(regionNumber, chapterNumber);
  final chapterSkills = [
    for (final stage in plan.stages) _masterySkillId(stage.skillId),
  ];
  return ChapterDefinition(
    id: chapterId,
    number: chapterNumber,
    title: plan.title,
    description: plan.description,
    prerequisiteChapterId: chapterNumber == 1
        ? null
        : _chapterId(regionNumber, chapterNumber - 1),
    stages: [
      for (var stageIndex = 0; stageIndex < plan.stages.length; stageIndex += 1)
        _buildStage(
          regionNumber: regionNumber,
          chapterNumber: chapterNumber,
          stageNumber: stageIndex + 1,
          plan: plan.stages[stageIndex],
          previousSkillId: stageIndex == 0
              ? null
              : chapterSkills[stageIndex - 1],
          previousChapterSkills: previousChapterSkills,
          priorChapterSkills: chapterSkills.take(stageIndex).toSet(),
          nextStageIdById: nextStageIdById,
          introducedBoardMechanics: introducedBoardMechanics,
          stageOrdinalById: stageOrdinalById,
        ),
    ],
  );
}

StageDefinition _buildStage({
  required int regionNumber,
  required int chapterNumber,
  required int stageNumber,
  required _StagePlan plan,
  required String? previousSkillId,
  required Set<String> previousChapterSkills,
  required Set<String> priorChapterSkills,
  required Map<String, String?> nextStageIdById,
  required Set<BoardMechanicId> introducedBoardMechanics,
  required Map<String, int> stageOrdinalById,
}) {
  final stageId = _stageId(regionNumber, chapterNumber, stageNumber);
  final stageSeed =
      202600000 + regionNumber * 10000 + chapterNumber * 100 + stageNumber;
  final learningRole = plan.learningRole ?? _learningRole(stageNumber);
  final nextStageId = nextStageIdById[stageId];
  final primarySkillId = _masterySkillId(plan.skillId);
  final matchDifficulty = _matchDifficulty(
    plan: plan,
    isFirstTutorial:
        regionNumber == 1 && chapterNumber == 1 && stageNumber == 1,
  );
  final boardMechanicPlan = _boardMechanicPlan(
    stageId: stageId,
    regionNumber: regionNumber,
    chapterNumber: chapterNumber,
    stageNumber: stageNumber,
    matchDifficulty: matchDifficulty,
    introducedMechanics: introducedBoardMechanics,
  );
  final variantProfile = _variantProfile(
    stageId: stageId,
    primarySkillId: primarySkillId,
    plan: plan,
    stageSeed: stageSeed,
  );
  final recurrencePlan = _recurrencePlan(
    plan: plan,
    revisitProfile: variantProfile,
    stageOrdinalById: stageOrdinalById,
  );
  return StageDefinition(
    id: stageId,
    chapterId: _chapterId(regionNumber, chapterNumber),
    skillId: plan.skillId,
    number: stageNumber,
    title: plan.title,
    conceptLabel: plan.conceptLabel,
    answerExpression: plan.answerExpression,
    puzzleId: 'planned.${plan.skillId}.$stageId',
    contentStatus: StageContentStatus.planned,
    sentenceMathPlan: sentenceMathPlanFor(
      regionNumber: regionNumber,
      chapterNumber: chapterNumber,
      sourceStageId: plan.sourceStageId,
    ),
    mathDifficulty: _mathDifficulty(plan),
    matchDifficulty: matchDifficulty,
    boardMechanicPlan: boardMechanicPlan,
    boardVariants: _plannedBoardVariants(stageId, stageSeed),
    moveBudget: StageMoveBudget(
      referenceMoves: plan.referenceMoves,
      parMoves: plan.parMoves,
      moveLimit: plan.moveLimit,
    ),
    starRules: const StageStarRules(),
    assistRules: _assistRules(
      role: learningRole,
      isFirstTutorial:
          regionNumber == 1 && chapterNumber == 1 && stageNumber == 1,
    ),
    learningPlan: StageLearningPlan(
      status: _learningPlanStatus(
        regionNumber,
        chapterNumber,
        plan.skillId,
        forceRevision: plan.forceLearningRevision,
      ),
      primarySkillId: primarySkillId,
      prerequisiteSkillIds: _prerequisiteSkillIds(
        primarySkillId: primarySkillId,
        role: learningRole,
        previousSkillId: previousSkillId,
        previousChapterSkills: previousChapterSkills,
      ),
      reinforcedSkillIds: {
        ..._reinforcedSkillIds(
          skillId: plan.skillId,
          primarySkillId: primarySkillId,
          role: learningRole,
          previousChapterSkills: previousChapterSkills,
          priorChapterSkills: priorChapterSkills,
        ),
        ...plan.explicitReinforcedSkillIds,
      },
      variantId: stageId,
      variantProfile: variantProfile,
      role: learningRole,
      objective: '문장의 수량 관계를 ${plan.answerExpression} 구조의 식으로 나타낸다.',
      nextStageId: nextStageId,
      additionalUnlockStageIds:
          chapterNumber == 3 && stageNumber == 10 && regionNumber < 7
          ? {_stageId(regionNumber + 1, 1, 1)}
          : const {},
    ),
    variantProfile: variantProfile,
    recurrencePlan: recurrencePlan,
    seed: stageSeed,
  );
}

MathDifficulty _mathDifficulty(_StagePlan plan) {
  final operators = <String>{};
  var operationCount = 0;
  for (final symbol in const ['+', '-', '×', '÷']) {
    final matches = symbol.allMatches(plan.answerExpression).length;
    if (matches > 0) {
      operators.add(symbol);
      operationCount += matches;
    }
  }
  final hasAdditiveOperator =
      operators.contains('+') || operators.contains('-');
  final hasMultiplicativeOperator =
      operators.contains('×') || operators.contains('÷');
  final requiresParentheses = plan.answerExpression.contains('(');
  return MathDifficulty(
    tier: MathDifficultyTier.values[plan.mathTier],
    compositionTier: CompositionTier.values[plan.compositionTier],
    readingTier: ReadingTier.values[plan.readingTier],
    reasoningSteps: operationCount.clamp(1, 4),
    operatorKindCount: operators.length.clamp(1, 4),
    usesOrderOfOperations:
        requiresParentheses ||
        (hasAdditiveOperator && hasMultiplicativeOperator),
    requiresParentheses: requiresParentheses,
  );
}

MatchDifficulty _matchDifficulty({
  required _StagePlan plan,
  required bool isFirstTutorial,
}) {
  final requiredSeals = switch (plan.compositionTier) {
    0 => 2,
    1 => 2,
    2 => 3,
    _ => 4,
  };
  return switch (plan.matchTier) {
    0 => MatchDifficulty(
      tier: MatchDifficultyTier.b0,
      gemKindCount: 4,
      requiredSealCount: requiredSeals.clamp(2, 3),
      decoySealCount: 0,
      maxSealLayers: 1,
      obstacleCount: 0,
      specialRule: MatchSpecialRule.none,
      planningDepth: 1,
      hasScriptedOpening: isFirstTutorial,
    ),
    1 => MatchDifficulty(
      tier: MatchDifficultyTier.b1,
      gemKindCount: 5,
      requiredSealCount: requiredSeals.clamp(2, 4),
      decoySealCount: 0,
      maxSealLayers: 1,
      obstacleCount: 0,
      specialRule: MatchSpecialRule.none,
      planningDepth: 2,
    ),
    2 => MatchDifficulty(
      tier: MatchDifficultyTier.b2,
      gemKindCount: 5,
      requiredSealCount: requiredSeals.clamp(2, 5),
      decoySealCount: 1,
      maxSealLayers: 1,
      obstacleCount: 0,
      specialRule: MatchSpecialRule.none,
      planningDepth: 3,
    ),
    3 => MatchDifficulty(
      tier: MatchDifficultyTier.b3,
      gemKindCount: 5,
      requiredSealCount: requiredSeals,
      decoySealCount: 0,
      maxSealLayers: plan.b3Rule == _B3Rule.layeredSeal ? 2 : 1,
      obstacleCount: plan.b3Rule == _B3Rule.dustObstacle ? 3 : 0,
      specialRule: MatchSpecialRule.none,
      planningDepth: 4,
    ),
    _ => MatchDifficulty(
      tier: MatchDifficultyTier.b4,
      gemKindCount: 5,
      requiredSealCount: requiredSeals,
      decoySealCount: 0,
      maxSealLayers: 1,
      obstacleCount: 0,
      specialRule: MatchSpecialRule.fourMatchPower,
      planningDepth: 5,
    ),
  };
}

BoardMechanicPlan _boardMechanicPlan({
  required String stageId,
  required int regionNumber,
  required int chapterNumber,
  required int stageNumber,
  required MatchDifficulty matchDifficulty,
  required Set<BoardMechanicId> introducedMechanics,
}) {
  final advancedMechanics = <BoardMechanicId>[];
  var intendedRole = BoardMechanicRole.review;
  if (chapterNumber <= 3) {
    if (matchDifficulty.maxSealLayers > 1) {
      advancedMechanics.add(BoardMechanicId.layeredSeal);
    }
    if (matchDifficulty.obstacleCount > 0) {
      advancedMechanics.add(BoardMechanicId.adjacentHitBlocker);
    }
    if (matchDifficulty.specialRule == MatchSpecialRule.fourMatchPower) {
      advancedMechanics.add(BoardMechanicId.linePower);
    }
  } else if (chapterNumber == 5 || chapterNumber == 6) {
    final theme = _regionMechanicThemes[regionNumber - 1];
    final first = theme.first;
    final second = theme.second;
    if (chapterNumber == 5) {
      switch (stageNumber) {
        case 1:
        case 6:
          break;
        case 2:
          advancedMechanics.add(first);
          intendedRole = BoardMechanicRole.introduce;
          break;
        case 3:
          advancedMechanics.add(first);
          intendedRole = BoardMechanicRole.guided;
          break;
        case 4:
          advancedMechanics.add(first);
          intendedRole = BoardMechanicRole.independent;
          break;
        case 5:
          advancedMechanics.add(first);
          intendedRole = BoardMechanicRole.review;
          break;
        case 7:
          advancedMechanics.add(second);
          intendedRole = BoardMechanicRole.introduce;
          break;
        case 8:
          advancedMechanics.add(second);
          intendedRole = BoardMechanicRole.independent;
          break;
        case 9:
        case 10:
          advancedMechanics.addAll([first, second]);
          intendedRole = BoardMechanicRole.mixed;
          break;
      }
    } else {
      switch (stageNumber) {
        case 1:
        case 3:
        case 5:
          advancedMechanics.add(first);
          intendedRole = BoardMechanicRole.review;
          break;
        case 2:
        case 6:
        case 7:
          advancedMechanics.add(second);
          intendedRole = BoardMechanicRole.review;
          break;
        case 4:
        case 8:
        case 9:
        case 10:
          advancedMechanics.addAll([first, second]);
          intendedRole = BoardMechanicRole.mixed;
          break;
      }
    }
  }

  var role = advancedMechanics.isEmpty
      ? BoardMechanicRole.baseline
      : intendedRole;
  if (advancedMechanics.length == 1) {
    final mechanic = advancedMechanics.single;
    if (!introducedMechanics.contains(mechanic)) {
      role = BoardMechanicRole.introduce;
      introducedMechanics.add(mechanic);
    } else if (role == BoardMechanicRole.introduce) {
      role = BoardMechanicRole.review;
    }
  } else if (advancedMechanics.isNotEmpty) {
    final unseen = advancedMechanics.where(
      (mechanic) => !introducedMechanics.contains(mechanic),
    );
    if (unseen.isNotEmpty) {
      throw StateError(
        'Stage $stageId mixes mechanics before introduction: '
        '${unseen.map((mechanic) => mechanic.name).join(', ')}.',
      );
    }
  }

  final mechanicIds = <BoardMechanicId>[
    BoardMechanicId.singleLayerSeal,
    ...advancedMechanics,
  ];
  return BoardMechanicPlan(
    id: '$stageId-board-mechanics',
    role: role,
    bindings: [
      for (final mechanicId in mechanicIds)
        BoardMechanicBinding(
          rule: _boardMechanicRule(mechanicId, matchDifficulty),
          skin: BoardMechanicSkin(
            key: 'region.${_twoDigits(regionNumber)}.${mechanicId.name}',
            mechanicId: mechanicId,
          ),
        ),
    ],
  );
}

BoardMechanicRule _boardMechanicRule(
  BoardMechanicId mechanicId,
  MatchDifficulty matchDifficulty,
) => switch (mechanicId) {
  BoardMechanicId.singleLayerSeal => SingleLayerSealRule(
    sealCount: matchDifficulty.requiredSealCount,
  ),
  BoardMechanicId.layeredSeal => LayeredSealRule(
    sealCount: (matchDifficulty.requiredSealCount / 2).ceil(),
    layers: 2,
  ),
  BoardMechanicId.adjacentHitBlocker => AdjacentHitBlockerRule(
    blockerCount: matchDifficulty.obstacleCount > 0
        ? matchDifficulty.obstacleCount
        : 2,
    durability: 1,
  ),
  BoardMechanicId.linePower => LinePowerRule(requiredActivations: 1),
  BoardMechanicId.swapLock => SwapLockRule(lockCount: 2, unlockHits: 1),
  BoardMechanicId.fixedBlocker => FixedBlockerRule(
    blockerCount: 2,
    durability: 1,
  ),
  BoardMechanicId.portal => PortalRule(pairCount: 1),
  BoardMechanicId.conveyor => ConveyorRule(pathCellCount: 5),
};

LearningVariantProfile _variantProfile({
  required String stageId,
  required String primarySkillId,
  required _StagePlan plan,
  required int stageSeed,
}) {
  final semanticPlan =
      plan.sourcePlan != null && !plan.semanticVariationAuthored
      ? plan.sourcePlan!
      : plan;
  return LearningVariantProfile(
    stageId: stageId,
    primarySkillId: primarySkillId,
    relationSchemaId: primarySkillId,
    answerAstShapeId: _answerAstShape(semanticPlan.answerExpression),
    operandBandId: _operandSignature(semanticPlan.answerExpression),
    unknownPositionId: semanticPlan.conceptLabel.contains('□')
        ? 'input'
        : 'result',
    contextFamilyId:
        semanticPlan.contextFamilyId ?? 'skill:${semanticPlan.skillId}',
    representationId: semanticPlan.representationId,
    problemSeed: stageSeed,
    boardSeed: stageSeed * 10 + 6,
  );
}

StageRecurrencePlan? _recurrencePlan({
  required _StagePlan plan,
  required LearningVariantProfile revisitProfile,
  required Map<String, int> stageOrdinalById,
}) {
  final sourceStageId = plan.sourceStageId;
  final sourcePlan = plan.sourcePlan;
  final revisitKind = plan.revisitKind;
  if (sourceStageId == null || sourcePlan == null || revisitKind == null) {
    return null;
  }
  final sourceRegion = int.parse(sourceStageId.substring(1, 3));
  final sourceChapter = int.parse(sourceStageId.substring(5, 7));
  final sourceStage = int.parse(sourceStageId.substring(9, 11));
  final sourceSeed =
      202600000 + sourceRegion * 10000 + sourceChapter * 100 + sourceStage;
  final sourceProfile = _variantProfile(
    stageId: sourceStageId,
    primarySkillId: revisitProfile.primarySkillId,
    plan: sourcePlan,
    stageSeed: sourceSeed,
  );
  final catalogStageGap =
      stageOrdinalById[revisitProfile.stageId]! -
      stageOrdinalById[sourceStageId]!;
  return StageRecurrencePlan(
    source: sourceProfile,
    revisit: revisitProfile,
    kind: revisitKind,
    minimumCatalogStageGap: catalogStageGap,
    maximumCatalogStageGap: catalogStageGap,
  );
}

String _answerAstShape(String expression) => expression
    .replaceAll(RegExp(r'\d+(?:\.\d+)?'), 'n')
    .replaceAll(RegExp(r'\s+'), '');

String _operandSignature(String expression) => RegExp(
  r'\d+(?:\.\d+)?',
).allMatches(expression).map((match) => match.group(0)!).join(',');

const List<({BoardMechanicId first, BoardMechanicId second})>
_regionMechanicThemes = [
  (first: BoardMechanicId.layeredSeal, second: BoardMechanicId.linePower),
  (first: BoardMechanicId.adjacentHitBlocker, second: BoardMechanicId.swapLock),
  (first: BoardMechanicId.fixedBlocker, second: BoardMechanicId.conveyor),
  (first: BoardMechanicId.portal, second: BoardMechanicId.layeredSeal),
  (
    first: BoardMechanicId.adjacentHitBlocker,
    second: BoardMechanicId.linePower,
  ),
  (first: BoardMechanicId.conveyor, second: BoardMechanicId.portal),
  (
    first: BoardMechanicId.layeredSeal,
    second: BoardMechanicId.adjacentHitBlocker,
  ),
];

BoardLayoutVariants _plannedBoardVariants(String stageId, int seed) =>
    BoardLayoutVariants(
      variants: [
        BoardLayoutVariant(
          config: DiscoveryBoardConfig.compactPhone,
          fixtureId: '$stageId-5x5-v1',
          seed: seed * 10 + 5,
          isVerified: false,
        ),
        BoardLayoutVariant(
          config: DiscoveryBoardConfig.standardPhone,
          fixtureId: '$stageId-6x6-v1',
          seed: seed * 10 + 6,
          isVerified: false,
        ),
      ],
    );

StageAssistRules _assistRules({
  required StageLearningRole role,
  required bool isFirstTutorial,
}) {
  if (isFirstTutorial) {
    return const StageAssistRules(
      tutorialMode: StageTutorialMode.forced,
      freeHintCount: 3,
      showsSuggestedSwap: true,
      allowsFreeRestart: true,
    );
  }
  if (role == StageLearningRole.introduce ||
      role == StageLearningRole.guidedPractice) {
    return const StageAssistRules(
      tutorialMode: StageTutorialMode.contextual,
      freeHintCount: 3,
      showsSuggestedSwap: false,
      allowsFreeRestart: true,
    );
  }
  return StageAssistRules(
    tutorialMode: StageTutorialMode.optional,
    freeHintCount: role == StageLearningRole.checkpoint ? 1 : 2,
    showsSuggestedSwap: false,
    allowsFreeRestart: true,
  );
}

StageLearningRole _learningRole(int stageNumber) => switch (stageNumber) {
  1 => StageLearningRole.prerequisiteCheck,
  2 => StageLearningRole.introduce,
  3 => StageLearningRole.guidedPractice,
  4 => StageLearningRole.independentPractice,
  5 => StageLearningRole.nearTransfer,
  6 => StageLearningRole.spacedReview,
  7 => StageLearningRole.representationTransfer,
  8 => StageLearningRole.farTransfer,
  9 => StageLearningRole.cumulativeReview,
  10 => StageLearningRole.checkpoint,
  _ => throw RangeError.range(stageNumber, 1, 10, 'stageNumber'),
};

const Set<(int, int)> _chaptersRequiringRevision = {
  (2, 3),
  (4, 1),
  (5, 3),
  (6, 3),
};

LearningPlanStatus _learningPlanStatus(
  int region,
  int chapter,
  String detailedSkillId, {
  required bool forceRevision,
}) {
  final primarySkillId = _masterySkillId(detailedSkillId);
  return forceRevision ||
          _chaptersRequiringRevision.contains((region, chapter)) ||
          !_plannedReadyMasterySkillIds.contains(primarySkillId)
      ? LearningPlanStatus.requiresRevision
      : LearningPlanStatus.planned;
}

/// Skills whose non-revision candidates independently provide two variants
/// and a transfer opportunity.
///
/// A stage already blocked by a chapter-level revision must never make another
/// stage look ready for planned authoring.
late final Set<String> _plannedReadyMasterySkillIds = () {
  final variantCount = <String, int>{};
  final hasTransferVariant = <String, bool>{};
  for (
    var regionIndex = 0;
    regionIndex < _regionPlans.length;
    regionIndex += 1
  ) {
    final region = _regionPlans[regionIndex];
    for (
      var chapterIndex = 0;
      chapterIndex < region.chapters.length;
      chapterIndex += 1
    ) {
      if (chapterIndex >= 3) {
        continue;
      }
      if (_chaptersRequiringRevision.contains((
        regionIndex + 1,
        chapterIndex + 1,
      ))) {
        continue;
      }
      final chapter = region.chapters[chapterIndex];
      for (var index = 0; index < chapter.stages.length; index += 1) {
        final stage = chapter.stages[index];
        if (stage.forceLearningRevision) {
          continue;
        }
        final primarySkillId = _masterySkillId(stage.skillId);
        variantCount.update(
          primarySkillId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        final role = stage.learningRole ?? _learningRole(index + 1);
        if (role == StageLearningRole.nearTransfer ||
            role == StageLearningRole.representationTransfer ||
            role == StageLearningRole.farTransfer) {
          hasTransferVariant[primarySkillId] = true;
        }
      }
    }
  }
  return {
    for (final entry in variantCount.entries)
      if (entry.value >= 2 && (hasTransferVariant[entry.key] ?? false))
        entry.key,
  };
}();

String _masterySkillId(String skillId) {
  if (skillId.startsWith('review.')) {
    if (skillId.contains('.r1.') || skillId.contains('.r1-')) {
      if (skillId.contains('order') || skillId.contains('parentheses')) {
        return 'arith.order';
      }
      if (skillId.contains('mul')) {
        return 'arith.mixed';
      }
      return 'arith.add';
    }
    if (skillId.contains('.r2.')) {
      return 'pattern.additive';
    }
    if (skillId.contains('.r3.')) {
      if (skillId.contains('time')) return 'unit.time';
      if (skillId.contains('length')) return 'unit.length';
      return 'unit.mass';
    }
    if (skillId.contains('.r4.')) {
      if (skillId.contains('inverse')) return 'rel.inverse';
      if (skillId.contains('sum-difference')) return 'rel.sum-difference';
      return 'eq.two-step';
    }
    if (skillId.contains('.r5.')) {
      if (skillId.contains('perimeter')) return 'geo.perimeter';
      if (skillId.contains('angle') || skillId.contains('grid')) {
        return 'geo.angle';
      }
      return 'geo.area';
    }
    if (skillId.contains('.r6.')) {
      if (skillId.contains('fraction')) return 'fraction.of-set';
      if (skillId.contains('percent')) return 'percent.discount';
      if (skillId.contains('mean') || skillId.contains('data'))
        return 'data.mean';
      return 'ratio.proportion';
    }
    return 'integrated.all-regions';
  }
  final parts = skillId.split('.');
  return parts.length < 2 ? skillId : '${parts[0]}.${parts[1]}';
}

Set<String> _reinforcedSkillIds({
  required String skillId,
  required String primarySkillId,
  required StageLearningRole role,
  required Set<String> previousChapterSkills,
  required Set<String> priorChapterSkills,
}) {
  final reinforced = <String>{};
  if (role == StageLearningRole.prerequisiteCheck) {
    reinforced.addAll(previousChapterSkills.take(2));
  }
  if (role == StageLearningRole.spacedReview) {
    reinforced.addAll(previousChapterSkills.take(2));
  }
  if (role == StageLearningRole.cumulativeReview ||
      role == StageLearningRole.checkpoint) {
    reinforced.addAll(priorChapterSkills);
  }
  if (skillId == 'review.r1.add-sub') {
    reinforced.add('arith.sub');
  }
  if (skillId == 'review.r4-r6.partition') {
    reinforced.addAll(const {'rel.inverse', 'ratio.partition'});
  }
  reinforced.remove(primarySkillId);
  return reinforced;
}

Set<String> _prerequisiteSkillIds({
  required String primarySkillId,
  required StageLearningRole role,
  required String? previousSkillId,
  required Set<String> previousChapterSkills,
}) {
  final prerequisites = <String>{};
  if (role == StageLearningRole.prerequisiteCheck) {
    prerequisites.addAll(previousChapterSkills.take(2));
  } else if (previousSkillId != null) {
    prerequisites.add(previousSkillId);
  }
  prerequisites.remove(primarySkillId);
  return prerequisites;
}

String _chapterId(int region, int chapter) =>
    'r${_twoDigits(region)}-c${_twoDigits(chapter)}';

String _stageId(int region, int chapter, int stage) =>
    '${_chapterId(region, chapter)}-s${_twoDigits(stage)}';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

enum _B3Rule { layeredSeal, dustObstacle }

class _RegionPlan {
  const _RegionPlan({required this.regionId, required this.chapters});

  final String regionId;
  final List<_ChapterPlan> chapters;
}

class _ChapterPlan {
  const _ChapterPlan({
    required this.title,
    required this.description,
    required this.stages,
  });

  final String title;
  final String description;
  final List<_StagePlan> stages;
}

class _StagePlan {
  _StagePlan({
    required this.title,
    required this.skillId,
    required this.conceptLabel,
    required this.answerExpression,
    required this.mathTier,
    required this.matchTier,
    required this.compositionTier,
    required this.readingTier,
    required this.referenceMoves,
    required this.parMoves,
    required this.moveLimit,
    required this.b3Rule,
    this.learningRole,
    this.sourceStageId,
    this.sourcePlan,
    this.revisitKind,
    this.forceLearningRevision = false,
    this.variantPhase = 'core',
    this.representationId = 'word-problem',
    this.contextFamilyId,
    this.semanticVariationAuthored = true,
    Iterable<String> explicitReinforcedSkillIds = const [],
  }) : explicitReinforcedSkillIds = Set.unmodifiable(
         explicitReinforcedSkillIds,
       );

  final String title;
  final String skillId;
  final String conceptLabel;
  final String answerExpression;
  final int mathTier;
  final int matchTier;
  final int compositionTier;
  final int readingTier;
  final int referenceMoves;
  final int parMoves;
  final int moveLimit;
  final _B3Rule? b3Rule;
  final StageLearningRole? learningRole;
  final String? sourceStageId;
  final _StagePlan? sourcePlan;
  final RevisitKind? revisitKind;
  final bool forceLearningRevision;
  final String variantPhase;
  final String representationId;
  final String? contextFamilyId;
  final bool semanticVariationAuthored;
  final Set<String> explicitReinforcedSkillIds;
}

const Set<String> _dustObstacleSkillIds = {
  'pattern.subtractive.next_review',
  'pattern.second_difference.next',
  'unit.rate.remaining_distance',
  'eq.balance.offset',
  'geo.area.decompose',
  'geo.grid.manhattan-distance',
  'review.r3.mass-conversion',
  'review.r6.data-rate',
};

_StagePlan _s(
  String title,
  String skillId,
  String conceptLabel,
  String difficulty,
  String moves,
) {
  final d = difficulty.split('/').map(int.parse).toList(growable: false);
  final m = moves.split('/').map(int.parse).toList(growable: false);
  final answerSeparator = conceptLabel.lastIndexOf('→');
  final answerExpression = answerSeparator < 0
      ? conceptLabel.trim()
      : conceptLabel.substring(answerSeparator + 1).trim();
  final b3Rule = d[1] == 3
      ? (_dustObstacleSkillIds.contains(skillId)
            ? _B3Rule.dustObstacle
            : _B3Rule.layeredSeal)
      : null;
  assert(d.length == 4 && m.length == 3);
  assert(answerExpression.isNotEmpty);
  return _StagePlan(
    title: title,
    skillId: skillId,
    conceptLabel: conceptLabel,
    answerExpression: answerExpression,
    mathTier: d[0],
    matchTier: d[1],
    compositionTier: d[2],
    readingTier: d[3],
    referenceMoves: m[0],
    parMoves: m[1],
    moveLimit: m[2],
    b3Rule: b3Rule,
  );
}

final List<_RegionPlan> _coreRegionPlans = [
  _RegionPlan(
    regionId: 'region-01-calculation',
    chapters: [
      _ChapterPlan(
        title: '모으기와 남기기',
        description: '덧셈과 뺄셈 문장을 식으로 옮기며 발굴 조작을 익힙니다.',
        stages: [
          _s('첫 수확', 'arith.add.combine.10', '3+2', '0/0/0/0', '2/4/10'),
          _s('남은 곡식', 'arith.sub.takeaway.10', '7-3', '1/0/0/0', '2/4/10'),
          _s('두 수레', 'arith.add.combine.10', '4+5', '1/1/1/0', '3/5/10'),
          _s('꺼낸 자루', 'arith.sub.takeaway.10', '9-4', '1/1/1/0', '3/5/10'),
          _s('한 줄 더', 'arith.add.compare_more', '6+3', '1/2/1/1', '4/6/11'),
          _s('차이만큼', 'arith.sub.difference', '10-6', '1/1/1/1', '4/6/11'),
          _s('열을 넘는 합', 'arith.add.bridge_10', '8+7', '1/2/1/1', '5/7/12'),
          _s('큰 수에서 빼기', 'arith.sub.bridge_10', '13-5', '1/2/1/1', '5/7/12'),
          _s(
            '두 번 모으기',
            'arith.mixed.add_two_step',
            '5+3+4',
            '2/1/2/1',
            '5/7/12',
          ),
          _s(
            '평원의 첫 관문',
            'arith.mixed.add_sub_two_step',
            '16-7+3',
            '2/2/2/1',
            '6/8/13',
          ),
        ],
      ),
      _ChapterPlan(
        title: '묶기와 나누기',
        description: '곱셈과 나눗셈의 두 관계를 익히고 두 단계 식으로 확장합니다.',
        stages: [
          _s('같은 묶음', 'arith.mul.equal_groups', '4×3', '1/0/1/1', '2/4/10'),
          _s('줄지은 상자', 'arith.mul.array', '5×4', '1/1/1/1', '4/6/11'),
          _s('공평하게 나누기', 'arith.div.equal_share', '12÷3', '1/0/1/1', '2/4/10'),
          _s('몇 묶음일까', 'arith.div.equal_group', '18÷3', '1/1/1/1', '4/6/11'),
          _s('묶음과 낱개', 'arith.mixed.mul_add', '4×3+2', '2/1/2/1', '5/7/12'),
          _s('깨진 묶음', 'arith.mixed.mul_sub', '5×4-2', '2/2/2/1', '5/7/12'),
          _s('나눈 뒤 더하기', 'arith.mixed.div_add', '18÷3+4', '2/2/2/1', '6/8/13'),
          _s('다시 두 배', 'arith.mixed.div_mul', '24÷6×2', '2/1/2/1', '5/7/12'),
          _s('묶음에서 덜기', 'arith.mixed.mul_sub', '3×7-5', '2/2/2/1', '7/9/14'),
          _s(
            '작업장의 기록',
            'arith.mixed.chapter_check',
            '6×3+4',
            '2/2/2/1',
            '7/9/14',
          ),
        ],
      ),
      _ChapterPlan(
        title: '연산의 바람길',
        description: '연산 순서와 괄호, 같은 값의 독립 토큰을 종합합니다.',
        stages: [
          _s(
            '먼저 계산할 것',
            'arith.order.mul_before_add',
            '2+3×4',
            '3/1/2/1',
            '6/8/13',
          ),
          _s(
            '괄호가 만든 길',
            'arith.parentheses.grouping',
            '(2+3)×4',
            '3/1/3/1',
            '7/9/14',
          ),
          _s(
            '곱하고 남기기',
            'arith.order.mul_before_sub',
            '18-2×5',
            '3/2/2/1',
            '7/9/14',
          ),
          _s(
            '나눈 뒤 모으기',
            'arith.order.div_before_add',
            '24÷3+6',
            '3/2/2/1',
            '7/9/14',
          ),
          _s(
            '차이를 묶기',
            'arith.parentheses.difference_group',
            '(12-4)×3',
            '3/1/3/1',
            '7/9/14',
          ),
          _s(
            '합으로 나누기',
            'arith.parentheses.divisor_group',
            '36÷(3+3)',
            '3/2/3/1',
            '8/10/15',
          ),
          _s(
            '쌍둥이 여섯',
            'arith.token.duplicate_value',
            '6×6',
            '2/2/2/1',
            '7/9/14',
          ),
          _s(
            '순서를 지켜 빼기',
            'arith.order.div_before_sub',
            '40-18÷3',
            '3/2/2/1',
            '8/10/15',
          ),
          _s(
            '괄호 길 건너기',
            'arith.parentheses.transfer',
            '3×(8-2)',
            '3/1/3/1',
            '8/10/15',
          ),
          _s(
            '평원의 수문장',
            'arith.order.region_mastery',
            '(24+12)÷6',
            '3/2/3/2',
            '9/11/16',
          ),
        ],
      ),
    ],
  ),
  _RegionPlan(
    regionId: 'region-02-pattern',
    chapters: [
      _ChapterPlan(
        title: '일정한 발자국',
        description: '등차수열의 다음 값과 항의 위치를 관찰해 식으로 표현합니다.',
        stages: [
          _s(
            '둘씩 자라는 잎',
            'pattern.additive.next_small',
            '6+2',
            '1/1/1/0',
            '3/5/10',
          ),
          _s(
            '둘씩 줄어드는 열매',
            'pattern.subtractive.next_small',
            '5-2',
            '1/1/1/0',
            '3/5/10',
          ),
          _s(
            '세 칸의 발자국',
            'pattern.additive.infer_step',
            '9+3',
            '2/1/1/0',
            '4/6/11',
          ),
          _s(
            '네 칸씩 뒤로',
            'pattern.subtractive.infer_step',
            '12-4',
            '2/2/1/0',
            '5/7/12',
          ),
          _s(
            '다섯 잎의 간격',
            'pattern.additive.transfer',
            '15+5',
            '2/2/1/0',
            '5/7/12',
          ),
          _s(
            '여섯 칸의 내리막',
            'pattern.subtractive.transfer',
            '18-6',
            '2/1/1/0',
            '4/6/11',
          ),
          _s(
            '다섯 번째 나무',
            'pattern.additive.nth_term',
            '3+2×4',
            '3/1/2/1',
            '6/8/13',
          ),
          _s(
            '다섯 번째 내리막',
            'pattern.subtractive.nth_term',
            '25-3×4',
            '3/2/2/1',
            '7/9/14',
          ),
          _s(
            '두 숲길의 간격',
            'pattern.compare.next_values',
            '18-17',
            '2/2/1/2',
            '6/8/13',
          ),
          _s(
            '발자국의 관문',
            'pattern.additive.nth_term_mastery',
            '4+3×5',
            '3/2/2/1',
            '7/9/14',
          ),
        ],
      ),
      _ChapterPlan(
        title: '번갈아 자라는 숲',
        description: '곱셈 규칙과 교대·재귀 규칙을 읽고 다음 값을 찾습니다.',
        stages: [
          _s(
            '두 배의 덩굴',
            'pattern.geometric.double',
            '12×2',
            '2/1/1/0',
            '5/7/12',
          ),
          _s('반으로 접힌 잎', 'pattern.geometric.half', '8÷2', '2/2/1/0', '6/8/13'),
          _s(
            '둘, 넷, 다시 둘',
            'pattern.alternate.add_steps',
            '9,11,15,17에서 +2,+4 반복 → 17+4',
            '3/1/1/1',
            '6/8/13',
          ),
          _s(
            '두 배와 하나',
            'pattern.alternate.mul_add',
            '3,6,7,14,15에서 ×2,+1 반복 → 15×2',
            '3/1/1/1',
            '6/8/13',
          ),
          _s(
            '짝지은 나무',
            'pattern.paired_growth',
            '4,4,6,6 다음 쌍의 수 → 6+2',
            '3/2/1/1',
            '7/9/14',
          ),
          _s(
            '단단한 나이테',
            'pattern.additive.next_review',
            '12+4',
            '1/3/1/0',
            '7/9/14',
          ),
          _s(
            '겹친 덩굴',
            'pattern.geometric.double_review',
            '20×2',
            '2/3/1/0',
            '8/10/15',
          ),
          _s(
            '먼지 속 발자국',
            'pattern.subtractive.next_review',
            '18-3',
            '2/3/1/0',
            '7/9/14',
          ),
          _s(
            '두 단계 성장법',
            'pattern.recursive.mul_add',
            '23×2+1',
            '3/2/2/1',
            '7/9/14',
          ),
          _s(
            '고목의 성장법',
            'pattern.recursive.mul_add_transfer',
            '31×2+1',
            '3/3/2/1',
            '9/11/16',
          ),
        ],
      ),
      _ChapterPlan(
        title: '규칙의 고목',
        description: '입출력표, 도형수와 두 단계 규칙을 종합합니다.',
        stages: [
          _s(
            '세 배하고 하나',
            'pattern.table.forward_mul_add',
            '5×3+1',
            '3/1/2/1',
            '6/8/13',
          ),
          _s(
            '규칙 기계의 출력',
            'pattern.table.forward_transfer',
            '6×2+1',
            '3/2/2/1',
            '7/9/14',
          ),
          _s(
            '입력을 되찾아라',
            'pattern.table.inverse_mul_add',
            '(19-1)÷3',
            '4/1/3/2',
            '7/9/14',
          ),
          _s(
            '두 칸짜리 기계',
            'pattern.machine.parenthesized',
            '(4+2)×3',
            '3/2/3/1',
            '8/10/15',
          ),
          _s(
            '커지는 차이',
            'pattern.second_difference.next',
            '14+6',
            '3/3/1/1',
            '8/10/15',
          ),
          _s('네모수의 가지', 'pattern.square_numbers', '5×5', '3/2/2/1', '7/9/14'),
          _s(
            '층층이 쌓인 잎',
            'pattern.triangular_numbers',
            '10+5',
            '3/2/1/1',
            '8/10/15',
          ),
          _s(
            '네 줄기의 빛',
            'pattern.additive.power_tile_intro',
            '18+6',
            '1/4/1/0',
            '8/10/15',
          ),
          _s(
            '네모수에 하나',
            'pattern.square_plus_one',
            '5×5+1',
            '3/3/2/1',
            '9/11/16',
          ),
          _s(
            '숲의 수문장',
            'pattern.square_plus_one_mastery',
            '6×6+1',
            '3/4/2/2',
            '10/12/17',
          ),
        ],
      ),
    ],
  ),
  _RegionPlan(
    regionId: 'region-03-unit',
    chapters: [
      _ChapterPlan(
        title: '시간과 길이의 길',
        description: '시간과 길이를 한 단위로 바꾸고 혼합 단위를 계산합니다.',
        stages: [
          _s('시간의 모래', 'unit.time.hour_to_min', '2×60', '4/0/1/1', '2/4/10'),
          _s(
            '시간과 분을 함께',
            'unit.time.hour_min_to_min',
            '2×60+35',
            '4/1/2/1',
            '4/6/11',
          ),
          _s('분을 시간으로', 'unit.time.min_to_hour', '180÷60', '4/1/1/1', '4/6/11'),
          _s(
            '다음 시각까지',
            'unit.time.elapsed_cross_hour',
            '(60-45)+20',
            '4/2/3/2',
            '6/8/13',
          ),
          _s('미터를 센티미터로', 'unit.length.m_to_cm', '3×100', '4/1/1/1', '4/6/11'),
          _s(
            '두 단위의 밧줄',
            'unit.length.m_cm_to_cm',
            '2×100+35',
            '4/2/2/1',
            '6/8/13',
          ),
          _s(
            '센티미터를 미터로',
            'unit.length.cm_to_m',
            '600÷100',
            '4/1/1/1',
            '5/7/12',
          ),
          _s(
            '잘라 낸 밧줄',
            'unit.length.mixed_subtract',
            '6×100-150',
            '4/2/2/2',
            '7/9/14',
          ),
          _s('킬로미터의 표지판', 'unit.length.km_to_m', '3×1000', '4/1/1/1', '5/7/12'),
          _s(
            '협곡의 긴 다리',
            'unit.length.km_m_to_m',
            '2×1000+350',
            '4/2/2/2',
            '7/9/14',
          ),
        ],
      ),
      _ChapterPlan(
        title: '무게와 들이의 골짜기',
        description: '무게와 들이의 환산, 나눔과 남은 양을 계산합니다.',
        stages: [
          _s('킬로그램 상자', 'unit.mass.kg_to_g', '4×1000', '4/1/1/1', '4/6/11'),
          _s(
            '무게를 한 단위로',
            'unit.mass.kg_g_to_g',
            '3×1000+250',
            '4/2/2/1',
            '6/8/13',
          ),
          _s(
            '두 봉지를 꺼내기',
            'unit.mass.multi_step_subtract',
            '5000-2×750',
            '3/2/2/2',
            '7/9/14',
          ),
          _s(
            '같은 무게로 나누기',
            'unit.mass.equal_packages',
            '3600÷6',
            '2/3/1/1',
            '7/9/14',
          ),
          _s('리터 물통', 'unit.capacity.l_to_ml', '2×1000', '4/1/1/1', '4/6/11'),
          _s(
            '리터와 밀리리터',
            'unit.capacity.l_ml_to_ml',
            '1×1000+750',
            '4/2/2/1',
            '6/8/13',
          ),
          _s(
            '세 병을 따르고',
            'unit.capacity.multi_step_subtract',
            '5000-3×1200',
            '3/2/2/2',
            '7/9/14',
          ),
          _s(
            '같은 병 여섯 개',
            'unit.capacity.equal_bottles',
            '4200÷6',
            '2/3/1/1',
            '8/10/15',
          ),
          _s(
            '남은 물의 차이',
            'unit.capacity.compare_mixed',
            '3×1000-2400',
            '4/2/2/2',
            '7/9/14',
          ),
          _s(
            '협곡의 물 저장소',
            'unit.capacity.mixed_total',
            '2000+3×500',
            '4/3/2/2',
            '9/11/16',
          ),
        ],
      ),
      _ChapterPlan(
        title: '거리와 빠르기의 길',
        description: '거리·속력·시간의 관계를 한 가지씩 전환하며 적용합니다.',
        stages: [
          _s(
            '한 시간마다 가는 길',
            'unit.rate.distance_from_speed_time',
            '12×3',
            '2/1/1/1',
            '5/7/12',
          ),
          _s(
            '네 시간의 이동',
            'unit.rate.distance_transfer',
            '18×4',
            '2/2/1/1',
            '6/8/13',
          ),
          _s(
            '몇 시간이 걸릴까',
            'unit.rate.time_from_distance_speed',
            '72÷12',
            '3/1/1/2',
            '6/8/13',
          ),
          _s(
            '한 시간에 얼마나',
            'unit.rate.speed_from_distance_time',
            '96÷4',
            '3/2/1/2',
            '7/9/14',
          ),
          _s(
            '두 시간을 분으로',
            'unit.rate.hour_to_min_context',
            '2×60',
            '4/1/1/2',
            '6/8/13',
          ),
          _s(
            '분마다 걷는 거리',
            'unit.rate.per_minute_distance',
            '30×4',
            '2/2/1/1',
            '6/8/13',
          ),
          _s(
            '두 번째 길까지',
            'unit.rate.two_leg_total',
            '36+8×2',
            '3/2/2/2',
            '8/10/15',
          ),
          _s(
            '남은 협곡 길',
            'unit.rate.remaining_distance',
            '200-35×4',
            '3/3/2/2',
            '9/11/16',
          ),
          _s(
            '킬로미터와 남은 길',
            'unit.rate.mixed_distance',
            '2×1000+350',
            '4/3/2/2',
            '9/11/16',
          ),
          _s(
            '협곡의 수문장',
            'unit.rate.region_mastery',
            '250×6+500',
            '4/4/2/2',
            '10/12/17',
          ),
        ],
      ),
    ],
  ),
  _RegionPlan(
    regionId: 'region-04-equation',
    chapters: [
      _ChapterPlan(
        title: '반대 연산의 오솔길',
        description: '빈칸과 등식의 관계를 반대 연산으로 풀어냅니다.',
        stages: [
          _s(
            '사라진 더하기',
            'rel.inverse.add',
            '□+5=12 → 12-5',
            '1/0/1/0',
            '2/4/10',
          ),
          _s(
            '빠진 빼기',
            'rel.inverse.subtract',
            '15-□=9 → 15-9',
            '1/1/1/0',
            '4/6/11',
          ),
          _s('처음의 수', 'rel.inverse.start', '□-6=8 → 8+6', '1/1/1/1', '4/6/11'),
          _s(
            '두 번 변한 수',
            'rel.inverse.additive-two-step',
            '□+7+5=24 → 24-7-5',
            '2/1/2/1',
            '6/8/13',
          ),
          _s(
            '같은 높이',
            'eq.balance.mixed-side',
            '□+9=4×4 → 4×4-9',
            '2/1/2/1',
            '4/6/11',
          ),
          _s(
            '세 개 더 가진 친구',
            'rel.additive-comparison',
            '11보다 3 큰 수 → 11+3',
            '1/2/1/1',
            '6/8/13',
          ),
          _s(
            '합과 차의 큰 수',
            'rel.sum-difference.large',
            '합26·차6 → (26+6)÷2',
            '4/1/3/2',
            '4/6/11',
          ),
          _s(
            '합과 차의 작은 수',
            'rel.sum-difference.small',
            '합26·차6 → (26-6)÷2',
            '4/2/3/2',
            '6/8/13',
          ),
          _s(
            '이웃한 두 수',
            'rel.consecutive-pair',
            '연속 두 수 합19 → (19+1)÷2',
            '4/3/3/2',
            '8/10/15',
          ),
          _s(
            '첫 능선의 관문',
            'eq.additive-group-check',
            '3×□+8=38 → (38-8)÷3',
            '3/2/3/2',
            '6/8/14',
          ),
        ],
      ),
      _ChapterPlan(
        title: '곱셈과 나눗셈 등성이',
        description: '곱셈·나눗셈 관계와 두 단계 방정식을 연결합니다.',
        stages: [
          _s(
            '네 묶음의 빈칸',
            'rel.inverse.multiply',
            '□×4=28 → 28÷4',
            '1/1/1/1',
            '4/6/11',
          ),
          _s(
            '다섯 줄의 빈칸',
            'rel.inverse.factor',
            '5×□=35 → 35÷5',
            '1/2/1/1',
            '6/8/13',
          ),
          _s(
            '나누기 전의 수',
            'rel.inverse.dividend',
            '□÷6=7 → 6×7',
            '1/1/1/1',
            '4/6/11',
          ),
          _s(
            '네 묶음과 낱개',
            'eq.two-step.add',
            '4×□+5=29 → (29-5)÷4',
            '3/1/3/1',
            '4/6/11',
          ),
          _s(
            '여섯 묶음에서 빼기',
            'eq.two-step.subtract',
            '6×□-7=47 → (47+7)÷6',
            '3/2/3/1',
            '6/8/13',
          ),
          _s(
            '합쳐진 묶음',
            'eq.grouped-factor',
            '(3+3)×□=54 → 54÷(3+3)',
            '3/3/3/2',
            '8/10/15',
          ),
          _s(
            '세 배의 깃발',
            'rel.multiplicative.large',
            '8의 3배 → 8×3',
            '1/4/1/1',
            '9/11/16',
          ),
          _s(
            '다섯 배의 반대편',
            'rel.multiplicative.small',
            '45가 작은 수의 5배 → 45÷5',
            '1/2/1/1',
            '6/8/13',
          ),
          _s(
            '다섯 팀의 몫',
            'eq.group-total-offset',
            '5×□+12=72 → (72-12)÷5',
            '3/2/3/2',
            '8/10/15',
          ),
          _s(
            '등성이 기록석',
            'eq.group-total-check',
            '6×□-8=64 → (64+8)÷6',
            '3/2/3/2',
            '6/8/14',
          ),
        ],
      ),
      _ChapterPlan(
        title: '균형의 정상',
        description: '양쪽 식의 값을 맞추고 합·차 관계를 다시 적용합니다.',
        stages: [
          _s(
            '양쪽의 무게',
            'eq.balance.evaluate-side',
            '□+8=6×4 → 6×4-8',
            '2/1/2/1',
            '4/6/11',
          ),
          _s(
            '합을 나누는 저울',
            'eq.balance.divide-side',
            '5×□=30+10 → (30+10)÷5',
            '3/1/3/1',
            '6/8/13',
          ),
          _s(
            '세 칸 낮은 값',
            'eq.balance.offset',
            '□-3=5×7 → 5×7+3',
            '2/3/2/1',
            '8/10/15',
          ),
          _s(
            '다섯 배와 여섯',
            'eq.linear.add',
            '5×□+6=31 → (31-6)÷5',
            '3/2/3/2',
            '6/8/13',
          ),
          _s(
            '일곱 배에서 여덟',
            'eq.linear.subtract',
            '7×□-8=48 → (48+8)÷7',
            '3/3/3/2',
            '8/10/15',
          ),
          _s(
            '두 묶음의 괄호',
            'eq.factor.sum',
            '(2+4)×□=36 → 36÷(2+4)',
            '3/1/3/2',
            '4/6/11',
          ),
          _s(
            '네 배의 봉인',
            'eq.linear.review',
            '4×□+6=42 → (42-6)÷4',
            '3/2/3/2',
            '6/8/14',
          ),
          _s(
            '다시 만난 큰 수',
            'rel.sum-difference.large-transfer',
            '합46·차12 → (46+12)÷2',
            '4/1/3/2',
            '4/6/11',
          ),
          _s(
            '다시 만난 작은 수',
            'rel.sum-difference.small-transfer',
            '합46·차12 → (46-12)÷2',
            '4/3/3/2',
            '8/10/15',
          ),
          _s(
            '산맥의 수문장',
            'eq.balance.multiplicative-check',
            '4×9=3×□ → 4×9÷3',
            '3/2/2/2',
            '7/9/14',
          ),
        ],
      ),
    ],
  ),
  _RegionPlan(
    regionId: 'region-05-geometry',
    chapters: [
      _ChapterPlan(
        title: '변과 둘레의 해변',
        description: '여러 도형의 둘레와 빠진 변의 길이를 식으로 구합니다.',
        stages: [
          _s(
            '세 변의 모래성',
            'geo.perimeter.equilateral',
            '한 변4인 정삼각형 → 3×4',
            '1/1/1/0',
            '4/6/11',
          ),
          _s(
            '네 변의 정원',
            'geo.perimeter.square',
            '한 변6인 정사각형 → 4×6',
            '1/2/1/0',
            '6/8/13',
          ),
          _s(
            '직사각형 산책길',
            'geo.perimeter.rectangle',
            '가로7·세로5 → 2×(7+5)',
            '3/1/3/1',
            '4/6/11',
          ),
          _s(
            '숨은 세로 길이',
            'geo.perimeter.missing-side',
            '둘레30·가로9 → 30÷2-9',
            '2/2/2/1',
            '6/8/13',
          ),
          _s(
            '삼각형의 빈 변',
            'geo.perimeter.triangle-missing',
            '둘레24, 두 변7·8 → 24-7-8',
            '2/3/2/1',
            '8/10/15',
          ),
          _s(
            '다섯 변의 등대',
            'geo.perimeter.regular-polygon',
            '한 변3인 정오각형 → 5×3',
            '1/2/1/1',
            '6/8/13',
          ),
          _s(
            '꺾인 해안선',
            'geo.length.segment-sum',
            '이어진 길이8·5·3 → 8+5+3',
            '2/2/2/1',
            '8/10/15',
          ),
          _s(
            '정사각형의 한 변',
            'geo.perimeter.square-inverse',
            '둘레36 → 36÷4',
            '1/1/1/1',
            '4/6/11',
          ),
          _s(
            '여섯 개의 빛',
            'geo.perimeter.hexagon',
            '한 변4인 정육각형 → 6×4',
            '1/4/1/0',
            '9/11/16',
          ),
          _s(
            '해변의 경계석',
            'geo.perimeter.irregular',
            '7인 변3개, 4인 변2개 → 3×7+2×4',
            '3/2/3/2',
            '7/9/14',
          ),
        ],
      ),
      _ChapterPlan(
        title: '넓이의 정원',
        description: '직사각형 넓이를 합치고 잘라 복합 넓이를 계산합니다.',
        stages: [
          _s(
            '직사각형 화단',
            'geo.area.rectangle',
            '가로7·세로5 → 7×5',
            '1/1/1/0',
            '4/6/11',
          ),
          _s(
            '같은 두 개의 6',
            'geo.area.square',
            '한 변6인 정사각형 → 6×6',
            '2/1/2/1',
            '6/8/13',
          ),
          _s(
            '넓이로 찾는 변',
            'geo.area.missing-side',
            '넓이42·한 변7 → 42÷7',
            '1/3/1/1',
            '8/10/15',
          ),
          _s(
            '두 화단 합치기',
            'geo.area.compose-add',
            '4×3과 2×5 → 4×3+2×5',
            '3/1/3/1',
            '4/6/11',
          ),
          _s(
            '잘라 낸 마당',
            'geo.area.compose-subtract',
            '8×6에서 3×4 제거 → 8×6-3×4',
            '3/2/3/1',
            '6/8/13',
          ),
          _s(
            'ㄴ자 화단',
            'geo.area.decompose',
            '6×5와 2×3 합 → 6×5+2×3',
            '3/3/3/2',
            '8/10/15',
          ),
          _s(
            '같은 폭, 새 길이',
            'geo.area.scale-one-side',
            '넓이48·기존 길이8, 새 길이9 → 48÷8×9',
            '2/1/2/2',
            '4/6/11',
          ),
          _s(
            '바닥 타일',
            'geo.area.tile-count',
            '7줄×4칸 → 7×4',
            '1/2/1/1',
            '6/8/13',
          ),
          _s(
            '그늘진 부분',
            'geo.area.shaded-difference',
            '9×6에서 3×2 제외 → 9×6-3×2',
            '3/2/3/2',
            '9/11/16',
          ),
          _s(
            '정원의 기록석',
            'geo.area.composite-check',
            '12×8에서 4×3 제외 → 12×8-4×3',
            '3/2/3/2',
            '7/9/14',
          ),
        ],
      ),
      _ChapterPlan(
        title: '각과 공간의 전망대',
        description: '각, 대칭, 좌표 거리와 입체도형의 양을 계산합니다.',
        stages: [
          _s(
            '직각을 나눈 빛',
            'geo.angle.complement',
            '직각에서35° 제외 → 90-35',
            '2/1/1/1',
            '4/6/11',
          ),
          _s(
            '삼각형의 빈 각',
            'geo.angle.triangle-sum',
            '70°·45°와 나머지 → 180-70-45',
            '2/2/2/1',
            '6/8/13',
          ),
          _s(
            '곧은 선의 반대각',
            'geo.angle.supplement',
            '일직선에서118° 제외 → 180-118',
            '1/3/1/1',
            '8/10/15',
          ),
          _s(
            '네 각의 마지막',
            'geo.angle.quadrilateral-sum',
            '90°·85°·95°와 나머지 → 360-90-85-95',
            '3/1/3/2',
            '4/6/11',
          ),
          _s(
            '거울선 네 개',
            'geo.symmetry.square-axes',
            '가로·세로2 + 대각선2 → 2+2',
            '1/2/1/1',
            '6/8/13',
          ),
          _s(
            '격자섬 최단길',
            'geo.grid.manhattan-distance',
            '가로4칸·세로3칸 → 4+3',
            '1/3/1/1',
            '8/10/15',
          ),
          _s(
            '좌표의 가로 거리',
            'geo.coordinate.axis-distance',
            'x=2와 x=7 → 7-2',
            '1/2/1/1',
            '6/8/13',
          ),
          _s(
            '상자의 부피',
            'geo.volume.rectangular-prism',
            '4×3×2 상자 → 4×3×2',
            '2/2/2/1',
            '9/11/16',
          ),
          _s(
            '정육면체 모서리',
            'geo.solid.edge-total',
            '모서리12개가 각4 → 12×4',
            '1/3/1/2',
            '8/10/15',
          ),
          _s(
            '섬의 수문장',
            'geo.area.composite-final',
            '10×8에서 4×3 제외 → 10×8-4×3',
            '3/2/3/2',
            '7/9/15',
          ),
        ],
      ),
    ],
  ),
  _RegionPlan(
    regionId: 'region-06-ratio',
    chapters: [
      _ChapterPlan(
        title: '같은 비의 항구',
        description: '단위율과 비례배분으로 같은 비를 유지하는 값을 찾습니다.',
        stages: [
          _s(
            '두 배의 주스',
            'ratio.scale.double',
            '3컵의 두 배 → 3×2',
            '1/1/1/0',
            '4/6/11',
          ),
          _s(
            '세 척의 같은 짐',
            'ratio.scale.triple',
            '4상자의 세 배 → 4×3',
            '1/2/1/0',
            '6/8/13',
          ),
          _s(
            '한 묶음의 값',
            'ratio.unit-rate',
            '3묶음이18 → 18÷3',
            '1/1/1/1',
            '4/6/11',
          ),
          _s(
            '다섯 묶음으로',
            'ratio.unit-rate.scale',
            '4묶음이20, 5묶음 → 20÷4×5',
            '2/1/2/1',
            '6/8/13',
          ),
          _s(
            '지도 위 항해',
            'ratio.map-scale',
            '지도3cm, 1cm당4km → 3×4',
            '4/1/1/1',
            '4/6/11',
          ),
          _s(
            '둘 대 다섯',
            'ratio.equivalent.find-fourth',
            '2:5에서 첫값6 → 6÷2×5',
            '2/3/2/2',
            '8/10/15',
          ),
          _s(
            '네 몫으로 나누기',
            'ratio.partition.unit',
            '1:3, 전체24의 한 몫 → 24÷(1+3)',
            '3/1/3/2',
            '4/6/11',
          ),
          _s(
            '세 몫의 보물',
            'ratio.partition.large',
            '전체24의 3/4 → 24÷4×3',
            '2/2/2/2',
            '6/8/13',
          ),
          _s(
            '세에서 일곱으로',
            'ratio.proportion.scale',
            '3몫이15, 7몫 → 15÷3×7',
            '2/4/2/2',
            '9/11/16',
          ),
          _s(
            '항구의 기록석',
            'ratio.proportion.check',
            '6몫이42, 5몫 → 42÷6×5',
            '2/2/2/2',
            '7/9/14',
          ),
        ],
      ),
      _ChapterPlan(
        title: '분수·백분율의 만',
        description: '양의 일부를 분수와 정수 결과의 백분율로 계산합니다.',
        stages: [
          _s(
            '절반의 조개',
            'fraction.of-set.half',
            '18의 1/2 → 18÷2',
            '1/1/1/1',
            '4/6/11',
          ),
          _s(
            '네 조각 중 하나',
            'fraction.of-set.quarter',
            '28의 1/4 → 28÷4',
            '1/2/1/1',
            '6/8/13',
          ),
          _s(
            '네 조각 중 셋',
            'fraction.of-set.three-quarters',
            '28의 3/4 → 28÷4×3',
            '2/2/2/1',
            '8/10/15',
          ),
          _s(
            '백 개 중 열 몫',
            'percent.ten',
            '90의 10% → 90÷10',
            '4/1/1/1',
            '4/6/11',
          ),
          _s(
            '다섯 몫 중 하나',
            'percent.twenty',
            '80의 20% → 80÷5',
            '4/2/1/1',
            '6/8/13',
          ),
          _s(
            '네 몫 중 하나',
            'percent.twenty-five',
            '60의 25% → 60÷4',
            '4/3/1/1',
            '8/10/15',
          ),
          _s(
            '절반만큼 더',
            'percent.increase.fifty',
            '40의 150% → 40+40÷2',
            '4/1/2/2',
            '4/6/11',
          ),
          _s(
            '할인 깃발',
            'percent.discount.twenty',
            '100에서 20% 할인 → 100-100÷5',
            '4/2/2/2',
            '6/8/13',
          ),
          _s(
            '십 퍼센트 더 싣기',
            'percent.increase.ten',
            '70에서 10% 증가 → 70+70÷10',
            '4/4/2/2',
            '9/11/16',
          ),
          _s(
            '백분율 항로표',
            'percent.fraction-equivalence',
            '64의 75% → 64÷4×3',
            '4/2/2/2',
            '7/9/14',
          ),
        ],
      ),
      _ChapterPlan(
        title: '자료의 등대',
        description: '그림표·막대·표의 합, 차, 평균과 대표값을 해석합니다.',
        stages: [
          _s(
            '그림표의 조개',
            'data.pictograph.total',
            '아이콘6개, 하나당4 → 4×6',
            '1/1/1/1',
            '4/6/11',
          ),
          _s(
            '두 막대의 차이',
            'data.bar.difference',
            '18과11의 차 → 18-11',
            '1/2/1/1',
            '6/8/13',
          ),
          _s(
            '세 항목의 합',
            'data.table.total',
            '12·15·9 합 → 12+15+9',
            '2/2/2/1',
            '8/10/15',
          ),
          _s(
            '두 날의 평균',
            'data.mean.two-values',
            '12와18의 평균 → (12+18)÷2',
            '3/1/3/2',
            '4/6/11',
          ),
          _s(
            '가장 큰 차이',
            'data.range',
            '최댓값23·최솟값8 → 23-8',
            '1/4/1/1',
            '9/11/16',
          ),
          _s(
            '표의 빈칸',
            'data.table.missing-from-total',
            '전체60, 18·17 제외 → 60-18-17',
            '2/2/2/2',
            '6/8/13',
          ),
          _s(
            '두 종류의 표',
            'data.weighted.total',
            '4짜리5개+2짜리3개 → 5×4+3×2',
            '3/1/3/2',
            '4/6/11',
          ),
          _s(
            '가장 자주 온 수',
            'data.mode.difference-from-min',
            '4,7,7,9에서 최빈값과 최솟값의 차 → 7-4',
            '2/2/1/2',
            '6/8/13',
          ),
          _s(
            '가운데 두 수',
            'data.median.even-count',
            '3,5,9,11의 중앙값 → (5+9)÷2',
            '3/2/3/2',
            '8/10/15',
          ),
          _s(
            '등대의 수문장',
            'data.rate.projection',
            '3일에18, 5일 예상 → 18÷3×5',
            '2/2/2/2',
            '7/9/15',
          ),
        ],
      ),
    ],
  ),
  _RegionPlan(
    regionId: 'region-07-wisdom',
    chapters: [
      _ChapterPlan(
        title: '세 지역의 기록길',
        description: '계산·패턴·단위의 핵심 개념을 짧게 재인출합니다.',
        stages: [
          _s(
            '다시 모으고 남기기',
            'review.r1.add-sub',
            '18에서6 빼고4 더하기 → 18-6+4',
            '2/1/2/0',
            '4/6/11',
          ),
          _s(
            '묶음과 낱개의 기억',
            'review.r1.mul-add',
            '3묶음×4와 낱개5 → 3×4+5',
            '2/2/2/1',
            '6/8/13',
          ),
          _s('먼저 계산할 것', 'review.r1.order', '2+3×4', '3/1/2/1', '4/6/11'),
          _s(
            '괄호로 달라진 길',
            'review.r1.parentheses',
            '(2+3)×4',
            '3/2/3/1',
            '6/8/13',
          ),
          _s(
            '되풀이되는 차이',
            'review.r2.arithmetic-pattern',
            '9,13,17 다음 → 17+(17-13)',
            '3/2/3/1',
            '6/8/13',
          ),
          _s(
            '무늬의 반복 횟수',
            'review.r2.repeat-unit',
            '24칸, 4칸 주기 → 24÷4',
            '1/3/1/1',
            '8/10/15',
          ),
          _s(
            '시간의 기록',
            'review.r3.time-conversion',
            '2시간20분 → 2×60+20',
            '4/1/2/2',
            '4/6/11',
          ),
          _s(
            '길이의 기록',
            'review.r3.length-conversion',
            '3m25cm → 3×100+25',
            '4/2/2/2',
            '6/8/13',
          ),
          _s(
            '무게의 기록',
            'review.r3.mass-conversion',
            '5kg에서750g 사용 → 5×1000-750',
            '4/3/2/2',
            '8/10/15',
          ),
          _s(
            '첫 회랑의 관문',
            'review.r1-r3.integrated',
            '90분에서20분씩3회 → 90-3×20',
            '3/2/2/2',
            '7/9/14',
          ),
        ],
      ),
      _ChapterPlan(
        title: '관계와 공간의 회랑',
        description: '방정식과 도형 문제를 번갈아 풀며 표현을 전이합니다.',
        stages: [
          _s(
            '빈칸의 반대 연산',
            'review.r4.inverse',
            '□+9=25 → 25-9',
            '1/1/1/1',
            '4/6/11',
          ),
          _s(
            '네 묶음의 빈칸',
            'review.r4.two-step-equation',
            '4×□+5=37 → (37-5)÷4',
            '3/1/3/1',
            '6/8/13',
          ),
          _s(
            '합과 차의 재회',
            'review.r4.sum-difference',
            '합40·차8 → (40+8)÷2',
            '4/1/3/2',
            '4/6/11',
          ),
          _s(
            '직사각형 길목',
            'review.r5.perimeter',
            '가로8·세로4 → 2×(8+4)',
            '3/1/3/1',
            '4/6/11',
          ),
          _s('넓이의 문', 'review.r5.area', '8×4 직사각형 → 8×4', '1/2/1/1', '6/8/13'),
          _s(
            '넓이에서 찾은 변',
            'review.r5.missing-side',
            '넓이48·한 변6 → 48÷6',
            '1/3/1/1',
            '8/10/15',
          ),
          _s(
            '삼각형의 남은 각',
            'review.r5.angle',
            '65°·55°와 나머지 → 180-65-55',
            '2/1/2/1',
            '4/6/11',
          ),
          _s(
            '잘라 낸 정상 정원',
            'review.r5.composite-area',
            '9×7에서3×4 제외 → 9×7-3×4',
            '3/1/3/2',
            '6/8/13',
          ),
          _s(
            '좌표 다리',
            'review.r5.grid-distance',
            '가로5·세로4 이동 → 5+4',
            '1/4/1/1',
            '9/11/16',
          ),
          _s(
            '두 번째 회랑의 관문',
            'review.r4-r5.integrated',
            '둘레34·가로10 → 34÷2-10',
            '2/2/2/2',
            '7/9/14',
          ),
        ],
      ),
      _ChapterPlan(
        title: '마지막 지혜의 길',
        description: '비율·자료와 앞선 모든 개념을 새 규칙 없이 종합합니다.',
        stages: [
          _s(
            '같은 비의 귀환',
            'review.r6.proportion',
            '3몫이18, 5몫 → 18÷3×5',
            '2/1/2/1',
            '4/6/11',
          ),
          _s(
            '네 조각 중 셋',
            'review.r6.fraction',
            '32의 3/4 → 32÷4×3',
            '2/2/2/1',
            '6/8/13',
          ),
          _s(
            '사분의 일 할인',
            'review.r6.percent',
            '100에서25% 할인 → 100-100÷4',
            '4/1/2/2',
            '4/6/11',
          ),
          _s(
            '두 기록의 평균',
            'review.r6.mean',
            '14와18의 평균 → (14+18)÷2',
            '3/2/3/2',
            '6/8/13',
          ),
          _s(
            '다섯 날의 예상',
            'review.r6.data-rate',
            '3일에12, 5일 예상 → 12÷3×5',
            '2/3/2/2',
            '8/10/15',
          ),
          _s(
            '시간의 사분의 일',
            'review.r3-r6.unit-ratio',
            '2시간의 1/4을 분으로 → 2×60÷4',
            '4/1/2/2',
            '4/6/11',
          ),
          _s(
            '넓이의 절반',
            'review.r5-r6.area-fraction',
            '8×6 직사각형의 절반 → 8×6÷2',
            '3/2/2/2',
            '6/8/13',
          ),
          _s(
            '여덟 몫의 보급품',
            'review.r4-r6.partition',
            '3:5로 전체48 분배 → 48÷(3+5)',
            '3/3/3/2',
            '8/10/15',
          ),
          _s(
            '마지막 남은 보급품',
            'review.r1.order-transfer',
            '60에서8개씩4묶음 → 60-4×8',
            '3/1/2/1',
            '4/6/11',
          ),
          _s(
            '지혜의 정상',
            'review.all-regions.final',
            '72개와18개를 합쳐3팀 → (72+18)÷3',
            '3/2/3/2',
            '7/9/15',
          ),
        ],
      ),
    ],
  ),
];

late final List<_RegionPlan> _regionPlans = [
  for (
    var regionIndex = 0;
    regionIndex < _coreRegionPlans.length;
    regionIndex += 1
  )
    _expandRegionPlan(_coreRegionPlans[regionIndex], regionIndex + 1),
];

_RegionPlan _expandRegionPlan(_RegionPlan core, int regionNumber) =>
    _RegionPlan(
      regionId: core.regionId,
      chapters: [...core.chapters, ..._buildSpiralChapters(core, regionNumber)],
    );

List<_ChapterPlan> _buildSpiralChapters(_RegionPlan core, int regionNumber) {
  final coreStages = [for (final chapter in core.chapters) ...chapter.stages];
  assert(coreStages.length == 30);
  final titles = _spiralChapterTitles[regionNumber - 1];
  return [
    _buildSpiralChapter(
      title: titles[0],
      description: '같은 풀이 관계를 다른 수와 문장으로 다시 꺼내 장기 기억을 만듭니다.',
      regionNumber: regionNumber,
      chapterNumber: 4,
      coreStages: coreStages,
      sourceIndexes: const [5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
      revisitKind: RevisitKind.sameRegionSpiral,
      phase: 'spiral-recall',
      representationId: 'varied-word-problem',
      learningRole: StageLearningRole.nearTransfer,
    ),
    _buildSpiralChapter(
      title: titles[1],
      description: '익숙한 수학 관계를 사용해 지역별 보드 효과를 한 가지씩 익힙니다.',
      regionNumber: regionNumber,
      chapterNumber: 5,
      coreStages: coreStages,
      sourceIndexes: const [15, 16, 17, 18, 19, 20, 21, 22, 23, 24],
      revisitKind: RevisitKind.sameRegionSpiral,
      phase: 'mechanic-transfer',
      representationId: 'mechanic-story',
      learningRole: StageLearningRole.representationTransfer,
    ),
    _buildSpiralChapter(
      title: titles[2],
      description: '현재 리전 숙련을 확인하고 이전 리전 전이 문제를 제작할 자리입니다.',
      regionNumber: regionNumber,
      chapterNumber: 6,
      coreStages: coreStages,
      sourceIndexes: const [0, 1, 2, 3, 4, 25, 26, 27, 28, 29],
      revisitKind: RevisitKind.sameRegionMastery,
      phase: 'cross-region',
      representationId: 'mixed-representation',
      learningRole: StageLearningRole.farTransfer,
    ),
  ];
}

_ChapterPlan _buildSpiralChapter({
  required String title,
  required String description,
  required int regionNumber,
  required int chapterNumber,
  required List<_StagePlan> coreStages,
  required List<int> sourceIndexes,
  required RevisitKind revisitKind,
  required String phase,
  required String representationId,
  required StageLearningRole learningRole,
}) => _ChapterPlan(
  title: title,
  description: description,
  stages: [
    for (var index = 0; index < sourceIndexes.length; index += 1)
      _spiralVariantOf(
        source: coreStages[sourceIndexes[index]],
        sourceStageId: _stageId(
          regionNumber,
          sourceIndexes[index] ~/ 10 + 1,
          sourceIndexes[index] % 10 + 1,
        ),
        regionNumber: regionNumber,
        chapterNumber: chapterNumber,
        stageNumber: index + 1,
        revisitKind: revisitKind,
        phase: phase,
        representationId: representationId,
        learningRole: learningRole,
      ),
  ],
);

_StagePlan _spiralVariantOf({
  required _StagePlan source,
  required String sourceStageId,
  required int regionNumber,
  required int chapterNumber,
  required int stageNumber,
  required RevisitKind revisitKind,
  required String phase,
  required String representationId,
  required StageLearningRole learningRole,
}) {
  final matchTier = chapterNumber == 4
      ? (source.matchTier > 2 ? 2 : source.matchTier)
      : 2;
  final prefix = switch (chapterNumber) {
    4 => '다시 만난',
    5 => '효과 원정',
    _ => '교차 도전',
  };
  return _StagePlan(
    title: '$prefix ${source.title}',
    skillId: source.skillId,
    conceptLabel: '${source.conceptLabel} [새 수·문맥 제작 예정]',
    answerExpression: source.answerExpression,
    mathTier: source.mathTier,
    matchTier: matchTier,
    compositionTier: source.compositionTier,
    readingTier: source.readingTier,
    referenceMoves: source.referenceMoves + (chapterNumber == 4 ? 0 : 1),
    parMoves: source.parMoves + (chapterNumber == 4 ? 0 : 1),
    moveLimit: source.moveLimit + (chapterNumber == 6 ? 1 : 0),
    b3Rule: null,
    learningRole: learningRole,
    sourceStageId: sourceStageId,
    sourcePlan: source,
    revisitKind: revisitKind,
    forceLearningRevision: true,
    variantPhase: phase,
    representationId: representationId,
    contextFamilyId: 'planned.$phase',
    semanticVariationAuthored: false,
  );
}

const List<List<String>> _spiralChapterTitles = [
  ['다시 만나는 계산길', '봉인 수확제', '평원의 대장정'],
  ['되돌아오는 숲길', '덩굴과 꽃의 미로', '숲과 평원의 교차로'],
  ['측정의 역참', '바위와 물길', '협곡의 운송대'],
  ['반대 연산 회랑', '연결 저울의 문', '미지수 원정'],
  ['경계와 면의 산책', '섬의 다리와 문', '공간 탐사 지도'],
  ['같은 값의 항로', '조류와 등대', '분석 원정선'],
  ['교차표현 회랑', '수호자 효과 시험', '지혜의 별자리'],
];
