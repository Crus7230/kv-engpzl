import '../../discovery/domain/discovery_models.dart';
import '../domain/board_mechanic_models.dart';
import '../domain/campaign_models.dart';
import '../domain/learning_models.dart';
import '../domain/stage_recurrence_models.dart';
import 'regional_campaign.dart';
import 'r1_authored_campaign.dart';

/// Active7-region,42-chapter,420-slot campaign with25 authored R1 alpha stages.
///
/// The regional blueprint stays untouched. The authored overlay promotes only
/// content whose AST/support and both phone reference fixtures are verified.
final CampaignDefinition initialCampaign = buildR1Campaign(regionalCampaign);

/// Development tutorial, kept outside [initialCampaign] so its forced path and
/// progress never stand in for independent regional learning evidence.
final LearningVariantProfile _verticalSliceVariantProfile =
    LearningVariantProfile(
      stageId: 'prototype-bundle-add',
      primarySkillId: 'arith.mixed.mul-add',
      relationSchemaId: 'equal-groups-plus-remainder',
      answerAstShapeId: 'mul-add',
      operandBandId: 'single-digit',
      unknownPositionId: 'result',
      contextFamilyId: 'bundle-items',
      representationId: 'word-problem',
      problemSeed: 2026,
      boardSeed: 20260606,
    );

final StageDefinition verticalSliceStage = StageDefinition(
  id: 'prototype-bundle-add',
  chapterId: 'prototype-chapter',
  skillId: 'prototype.bundle-add',
  number: 1,
  title: '수식 광산 프로토타입',
  conceptLabel: '곱셈 후 덧셈',
  answerExpression: '4×3+2',
  puzzleId: 'bundle-add-01',
  contentStatus: StageContentStatus.playable,
  mathDifficulty: const MathDifficulty(
    tier: MathDifficultyTier.m2,
    compositionTier: CompositionTier.c2,
    readingTier: ReadingTier.r1,
    reasoningSteps: 2,
    operatorKindCount: 2,
    usesOrderOfOperations: true,
    requiresParentheses: false,
  ),
  matchDifficulty: const MatchDifficulty(
    tier: MatchDifficultyTier.b1,
    gemKindCount: 5,
    requiredSealCount: 3,
    decoySealCount: 0,
    maxSealLayers: 1,
    obstacleCount: 0,
    specialRule: MatchSpecialRule.none,
    planningDepth: 1,
    hasScriptedOpening: true,
  ),
  boardMechanicPlan: BoardMechanicPlan(
    id: 'prototype-bundle-add-mechanics',
    role: BoardMechanicRole.baseline,
    bindings: [
      BoardMechanicBinding(
        rule: SingleLayerSealRule(sealCount: 3),
        skin: BoardMechanicSkin(
          key: 'prototype.seal.default',
          mechanicId: BoardMechanicId.singleLayerSeal,
        ),
      ),
    ],
  ),
  boardVariants: BoardLayoutVariants(
    variants: const [
      BoardLayoutVariant(
        config: DiscoveryBoardConfig.compactPhone,
        fixtureId: 'prototype-bundle-add-5x5-v1',
        seed: 20260505,
        isVerified: true,
      ),
      BoardLayoutVariant(
        config: DiscoveryBoardConfig.standardPhone,
        fixtureId: 'prototype-bundle-add-6x6-v1',
        seed: 20260606,
        isVerified: true,
      ),
    ],
  ),
  moveBudget: const StageMoveBudget(
    referenceMoves: 3,
    parMoves: 5,
    moveLimit: 12,
  ),
  starRules: const StageStarRules(),
  assistRules: const StageAssistRules(
    tutorialMode: StageTutorialMode.forced,
    freeHintCount: 3,
    showsSuggestedSwap: true,
    allowsFreeRestart: true,
  ),
  learningPlan: StageLearningPlan(
    status: LearningPlanStatus.authored,
    primarySkillId: 'arith.mixed.mul-add',
    prerequisiteSkillIds: const {'arith.multiply', 'arith.add'},
    reinforcedSkillIds: const {'arith.multiply', 'arith.add'},
    variantId: 'prototype-bundle-add',
    variantProfile: _verticalSliceVariantProfile,
    role: StageLearningRole.introduce,
    objective: '같은 수의 묶음은 곱셈으로, 남은 낱개는 덧셈으로 나타낸다.',
    nextStageId: null,
  ),
  variantProfile: _verticalSliceVariantProfile,
  seed: 2026,
  startingTokenIds: {'p1-n4', 'p1-n3'},
  buriedTokenIds: {'p1-times', 'p1-plus', 'p1-n2'},
);

final CampaignDefinition prototypeCampaign = CampaignDefinition(
  id: 'equation-discovery-prototype',
  version: 1,
  chapters: [
    ChapterDefinition(
      id: 'prototype-chapter',
      number: 1,
      title: '프로토타입',
      description: '현재 엔진으로 끝까지 실행 검증된 세로 조각입니다.',
      prerequisiteChapterId: null,
      stages: [verticalSliceStage],
    ),
  ],
);
