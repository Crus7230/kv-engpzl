import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/campaign/data/initial_campaign.dart';
import '../../../lib/features/campaign/data/r1_authored_campaign.dart';
import '../../../lib/features/campaign/domain/board_mechanic_models.dart';
import '../../../lib/features/campaign/domain/campaign_models.dart';
import '../../../lib/features/campaign/domain/campaign_validator.dart';
import '../../../lib/features/campaign/domain/stage_recurrence_models.dart';
import '../../../lib/features/puzzle/domain/puzzle.dart';

void main() {
  final layered = initialCampaign.stageById('r01-c05-s01')!;
  final power = initialCampaign.stageById('r01-c05-s06')!;

  test(
    'real earlier authored recurrences introduce and combine supported effects',
    () {
      final report = const CampaignValidator().validate(
        campaign: initialCampaign,
        puzzles: r1PuzzlesByStageId.values,
      );
      expect(report.errors, isEmpty);
      for (final id in ['r01-c05-s01', 'r01-c05-s06', 'r01-c06-s10']) {
        expect(
          currentDiscoveryBoardMechanics.supportsForPlay(
            initialCampaign.stageById(id)!.boardMechanicPlan,
          ),
          isTrue,
        );
      }
    },
  );

  test('chapter name alone never exempts hard math at effect introduction', () {
    for (final target in [layered, power]) {
      final replacement = _copy(target, clearRecurrence: true);
      final codes = _codes(replacement);
      expect(
        codes,
        contains(CampaignIssueCode.advancedMatchRuleIntroducedWithHardMath),
      );
      if (target.id == power.id) {
        expect(
          codes,
          contains(CampaignIssueCode.simultaneousDifficultyIncrease),
        );
      }
      expect(
        codes,
        isNot(contains(CampaignIssueCode.unsupportedPlayableMatchRules)),
      );
    }
  });

  test('missing or future source cannot excuse hard math', () {
    for (final sourceId in ['missing-authored-source', 'r01-c06-s10']) {
      final recurrence = layered.recurrencePlan!;
      final replacement = _copy(
        layered,
        recurrence: StageRecurrencePlan(
          source: _profileWithId(recurrence.source, sourceId),
          revisit: recurrence.revisit,
          kind: recurrence.kind,
          minimumCatalogStageGap: recurrence.minimumCatalogStageGap,
          maximumCatalogStageGap: recurrence.maximumCatalogStageGap,
        ),
      );
      expect(
        _codes(replacement),
        contains(CampaignIssueCode.advancedMatchRuleIntroducedWithHardMath),
        reason: sourceId,
      );
    }
  });

  test('planned source and absent source puzzle cannot excuse hard math', () {
    final source = initialCampaign.stageById(
      layered.recurrencePlan!.sourceStageId,
    )!;
    final planned = _copy(source, contentStatus: StageContentStatus.planned);
    final report = const CampaignValidator().validate(
      campaign: _replaceStages({source.id: planned}),
      puzzles: r1PuzzlesByStageId.values,
    );
    expect(
      _codesAt(report, layered.id),
      contains(CampaignIssueCode.advancedMatchRuleIntroducedWithHardMath),
    );
    expect(
      _codes(
        layered,
        puzzles: r1PuzzlesByStageId.values.where(
          (puzzle) => puzzle.id != source.puzzleId,
        ),
      ),
      contains(CampaignIssueCode.advancedMatchRuleIntroducedWithHardMath),
    );
  });

  test(
    'a harder revisit or mismatched source fingerprint still fails introduction',
    () {
      final harder = _copy(
        layered,
        math: _mathWithTier(layered.mathDifficulty, MathDifficultyTier.m3),
      );
      expect(
        _codes(harder),
        contains(CampaignIssueCode.advancedMatchRuleIntroducedWithHardMath),
      );
      final recurrence = layered.recurrencePlan!;
      final source = recurrence.source;
      final forgedSource = LearningVariantProfile(
        stageId: source.stageId,
        primarySkillId: source.primarySkillId,
        relationSchemaId: 'not-the-real-authored-relation',
        answerAstShapeId: source.answerAstShapeId,
        operandBandId: source.operandBandId,
        unknownPositionId: source.unknownPositionId,
        contextFamilyId: source.contextFamilyId,
        representationId: source.representationId,
      );
      expect(
        _codes(
          _copy(
            layered,
            recurrence: StageRecurrencePlan(
              source: forgedSource,
              revisit: recurrence.revisit,
              kind: recurrence.kind,
              minimumCatalogStageGap: recurrence.minimumCatalogStageGap,
              maximumCatalogStageGap: recurrence.maximumCatalogStageGap,
            ),
          ),
        ),
        contains(CampaignIssueCode.advancedMatchRuleIntroducedWithHardMath),
      );
    },
  );

  test('unverified source fixtures do not grant a familiar-math exception', () {
    final source = initialCampaign.stageById(
      layered.recurrencePlan!.sourceStageId,
    )!;
    final unverified = _copy(
      source,
      boardVariants: BoardLayoutVariants(
        variants: [
          for (final variant in source.boardVariants.variants)
            BoardLayoutVariant(
              config: variant.config,
              fixtureId: variant.fixtureId,
              seed: variant.seed,
              isVerified: false,
            ),
        ],
      ),
    );
    final report = const CampaignValidator().validate(
      campaign: _replaceStages({source.id: unverified}),
      puzzles: r1PuzzlesByStageId.values,
    );
    expect(
      _codesAt(report, layered.id),
      contains(CampaignIssueCode.advancedMatchRuleIntroducedWithHardMath),
    );
  });

  test('two-layer metadata needs a matching real binding and seal count', () {
    final onlyBaseline = _plan(layered, const []);
    expect(
      _codes(_copy(layered, boardPlan: onlyBaseline)),
      contains(CampaignIssueCode.unsupportedPlayableMatchRules),
    );
    final wrongCount = _plan(layered, [
      LayeredSealRule(sealCount: layered.buriedTokenIds.length + 1, layers: 2),
    ]);
    expect(
      _codes(_copy(layered, boardPlan: wrongCount)),
      contains(CampaignIssueCode.unsupportedPlayableMatchRules),
    );
    final threeLayers = _plan(layered, [
      LayeredSealRule(sealCount: layered.buriedTokenIds.length, layers: 3),
    ]);
    expect(
      _codes(
        _copy(
          layered,
          boardPlan: threeLayers,
          match: _match(layered.matchDifficulty, layers: 3),
        ),
      ),
      contains(CampaignIssueCode.unsupportedPlayableMatchRules),
    );
  });

  test(
    'four-match metadata cannot run without the exact supported power contract',
    () {
      expect(
        _codes(_copy(power, boardPlan: _plan(power, const []))),
        contains(CampaignIssueCode.unsupportedPlayableMatchRules),
      );
      for (final rule in [
        LinePowerRule(requiredActivations: 1, creationMatchLength: 5),
        LinePowerRule(requiredActivations: 2),
      ]) {
        expect(
          _codes(_copy(power, boardPlan: _plan(power, [rule]))),
          contains(CampaignIssueCode.unsupportedPlayableMatchRules),
        );
      }
      expect(
        _codes(
          _copy(
            power,
            match: _match(
              power.matchDifficulty,
              special: MatchSpecialRule.none,
            ),
          ),
        ),
        contains(CampaignIssueCode.unsupportedPlayableMatchRules),
      );
    },
  );

  test('obstacles and model-only or reserved mechanics remain blocked', () {
    final blockers = _plan(layered, [
      AdjacentHitBlockerRule(blockerCount: 1, durability: 1),
    ]);
    final replacement = _copy(
      layered,
      boardPlan: blockers,
      match: _match(layered.matchDifficulty, layers: 1, obstacles: 1),
    );
    final codes = _codes(replacement);
    expect(codes, contains(CampaignIssueCode.unsupportedPlayableMatchRules));
    expect(codes, contains(CampaignIssueCode.unsupportedPlayableBoardMechanic));
    for (final rule in [
      SwapLockRule(lockCount: 2, unlockHits: 1),
      PortalRule(pairCount: 1),
    ]) {
      expect(
        _codes(_copy(layered, boardPlan: _plan(layered, [rule]))),
        contains(CampaignIssueCode.unsupportedPlayableBoardMechanic),
      );
    }
  });
}

Set<CampaignIssueCode> _codes(
  StageDefinition stage, {
  Iterable<Puzzle>? puzzles,
}) => _codesAt(
  const CampaignValidator().validate(
    campaign: _replaceStages({stage.id: stage}),
    puzzles: puzzles ?? r1PuzzlesByStageId.values,
  ),
  stage.id,
);

Set<CampaignIssueCode> _codesAt(
  CampaignValidationReport report,
  String stageId,
) => {
  for (final issue in report.errors)
    if (issue.location == 'stage:$stageId') issue.code,
};

CampaignDefinition _replaceStages(Map<String, StageDefinition> replacements) =>
    CampaignDefinition.regional(
      id: initialCampaign.id,
      version: initialCampaign.version,
      regions: [
        for (final region in initialCampaign.regions)
          region.metadata.bindChapters([
            for (final chapter in region.chapters)
              ChapterDefinition(
                id: chapter.id,
                number: chapter.number,
                title: chapter.title,
                description: chapter.description,
                prerequisiteChapterId: chapter.prerequisiteChapterId,
                stages: [
                  for (final stage in chapter.stages)
                    replacements[stage.id] ?? stage,
                ],
              ),
          ]),
      ],
    );

StageDefinition _copy(
  StageDefinition stage, {
  bool clearRecurrence = false,
  StageRecurrencePlan? recurrence,
  StageContentStatus? contentStatus,
  MathDifficulty? math,
  MatchDifficulty? match,
  BoardMechanicPlan? boardPlan,
  BoardLayoutVariants? boardVariants,
}) => StageDefinition(
  id: stage.id,
  chapterId: stage.chapterId,
  skillId: stage.skillId,
  number: stage.number,
  title: stage.title,
  conceptLabel: stage.conceptLabel,
  answerExpression: stage.answerExpression,
  puzzleId: stage.puzzleId,
  contentStatus: contentStatus ?? stage.contentStatus,
  mathDifficulty: math ?? stage.mathDifficulty,
  matchDifficulty: match ?? stage.matchDifficulty,
  boardMechanicPlan: boardPlan ?? stage.boardMechanicPlan,
  boardVariants: boardVariants ?? stage.boardVariants,
  moveBudget: stage.moveBudget,
  starRules: stage.starRules,
  assistRules: stage.assistRules,
  learningPlan: stage.learningPlan,
  variantProfile: stage.variantProfile,
  recurrencePlan: clearRecurrence ? null : recurrence ?? stage.recurrencePlan,
  seed: stage.seed,
  startingTokenIds: stage.startingTokenIds,
  buriedTokenIds: stage.buriedTokenIds,
  decoyTokenIds: stage.decoyTokenIds,
);

LearningVariantProfile _profileWithId(
  LearningVariantProfile profile,
  String id,
) => LearningVariantProfile(
  stageId: id,
  primarySkillId: profile.primarySkillId,
  relationSchemaId: profile.relationSchemaId,
  answerAstShapeId: profile.answerAstShapeId,
  operandBandId: profile.operandBandId,
  unknownPositionId: profile.unknownPositionId,
  contextFamilyId: profile.contextFamilyId,
  representationId: profile.representationId,
);

MathDifficulty _mathWithTier(MathDifficulty math, MathDifficultyTier tier) =>
    MathDifficulty(
      tier: tier,
      compositionTier: math.compositionTier,
      readingTier: math.readingTier,
      reasoningSteps: math.reasoningSteps,
      operatorKindCount: math.operatorKindCount,
      usesOrderOfOperations: math.usesOrderOfOperations,
      requiresParentheses: math.requiresParentheses,
    );

MatchDifficulty _match(
  MatchDifficulty match, {
  int? layers,
  int? obstacles,
  MatchSpecialRule? special,
}) => MatchDifficulty(
  tier: match.tier,
  gemKindCount: match.gemKindCount,
  requiredSealCount: match.requiredSealCount,
  decoySealCount: match.decoySealCount,
  maxSealLayers: layers ?? match.maxSealLayers,
  obstacleCount: obstacles ?? match.obstacleCount,
  specialRule: special ?? match.specialRule,
  planningDepth: match.planningDepth,
);

BoardMechanicPlan _plan(
  StageDefinition stage,
  List<BoardMechanicRule> advanced,
) => BoardMechanicPlan(
  id: stage.boardMechanicPlan.id,
  role: advanced.isEmpty
      ? BoardMechanicRole.baseline
      : BoardMechanicRole.introduce,
  bindings: [
    for (final rule in [
      SingleLayerSealRule(sealCount: stage.buriedTokenIds.length),
      ...advanced,
    ])
      BoardMechanicBinding(
        rule: rule,
        skin: BoardMechanicSkin(
          key: 'validator.${rule.mechanicId.name}',
          mechanicId: rule.mechanicId,
        ),
      ),
  ],
);
