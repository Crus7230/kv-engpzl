import 'dart:io';

import '../lib/features/campaign/data/initial_campaign.dart'
    hide initialCampaign;
import '../lib/features/campaign/data/regional_campaign.dart' as blueprint;
import '../lib/features/campaign/domain/campaign_models.dart';
import '../lib/features/campaign/domain/campaign_validator.dart';
import '../lib/features/discovery/data/tutorial_discovery_fixture.dart';
import '../lib/features/discovery/domain/discovery_engine.dart';
import '../lib/features/discovery/domain/discovery_models.dart';
import '../lib/features/discovery/domain/discovery_piece_source.dart';
import '../lib/features/puzzle/data/sample_puzzles.dart';
import '../lib/features/puzzle/domain/equation_token.dart';

// This legacy verifier protects the immutable curriculum blueprint. The
// composed runtime has its own authored-content and board-fixture verifiers.
final initialCampaign = blueprint.regionalCampaign;

void main() {
  _verifyRegionalCurriculum();
  _verifyPrototype();
  stdout.writeln(
    'Campaign verification passed: 7 regions, 42 chapters, 420 planned '
    'curriculum stages, and 1 separate playable prototype.',
  );
}

void _verifyRegionalCurriculum() {
  _expect(
    initialCampaign.version == 4,
    'The 420-stage branch graph requires campaign version 4.',
  );
  const validator = CampaignValidator();
  final report = validator.validate(
    campaign: initialCampaign,
    puzzles: samplePuzzles,
    knownCharacterIds: List.generate(
      26,
      (index) => 'CHAR_${String.fromCharCode('A'.codeUnitAt(0) + index)}',
    ),
  );
  _expect(
    report.isValid,
    'regional campaign errors: '
    '${report.errors.map((issue) => issue.message).join(' | ')}',
  );

  final regions = initialCampaign.regions;
  final chapters = initialCampaign.chapters;
  final stages = initialCampaign.stages.toList();
  _expect(regions.length == 7, 'campaign should contain seven regions');
  _expect(
    regions.every(
      (region) =>
          region.chapters.length == 6 &&
          region.chapters.every((chapter) => chapter.stages.length == 10),
    ),
    'every region should contain six chapters of ten stages',
  );
  _expect(chapters.length == 42, 'campaign should contain 42 chapters');
  _expect(stages.length == 420, 'campaign should reserve 420 stages');
  _expect(
    stages.every((stage) => stage.contentStatus == StageContentStatus.planned),
    'every regional stage should remain planned until authored and verified',
  );
  _expect(
    report.warnings.length == stages.length &&
        report.warnings.every(
          (issue) => issue.code == CampaignIssueCode.unresolvedPlannedPuzzle,
        ),
    'every unresolved planned puzzle should produce exactly one warning',
  );

  const anchors = [
    (
      regionId: 'region-01-calculation',
      firstSkill: 'arith.add.combine.10',
      lastSkill: 'arith.order.region_mastery',
      firstMoves: (2, 4, 10),
      lastMoves: (9, 11, 16),
    ),
    (
      regionId: 'region-02-pattern',
      firstSkill: 'pattern.additive.next_small',
      lastSkill: 'pattern.square_plus_one_mastery',
      firstMoves: (3, 5, 10),
      lastMoves: (10, 12, 17),
    ),
    (
      regionId: 'region-03-unit',
      firstSkill: 'unit.time.hour_to_min',
      lastSkill: 'unit.rate.region_mastery',
      firstMoves: (2, 4, 10),
      lastMoves: (10, 12, 17),
    ),
    (
      regionId: 'region-04-equation',
      firstSkill: 'rel.inverse.add',
      lastSkill: 'eq.balance.multiplicative-check',
      firstMoves: (2, 4, 10),
      lastMoves: (7, 9, 14),
    ),
    (
      regionId: 'region-05-geometry',
      firstSkill: 'geo.perimeter.equilateral',
      lastSkill: 'geo.area.composite-final',
      firstMoves: (4, 6, 11),
      lastMoves: (7, 9, 15),
    ),
    (
      regionId: 'region-06-ratio',
      firstSkill: 'ratio.scale.double',
      lastSkill: 'data.rate.projection',
      firstMoves: (4, 6, 11),
      lastMoves: (7, 9, 15),
    ),
    (
      regionId: 'region-07-wisdom',
      firstSkill: 'review.r1.add-sub',
      lastSkill: 'review.all-regions.final',
      firstMoves: (4, 6, 11),
      lastMoves: (7, 9, 15),
    ),
  ];
  for (var index = 0; index < regions.length; index += 1) {
    final region = regions[index];
    final anchor = anchors[index];
    final regionStages = region.stages.toList();
    final accessGate = region.stageById(region.accessGateStageId)!;
    _expect(region.id == anchor.regionId, '${region.id} region order mismatch');
    _expect(
      regionStages.first.skillId == anchor.firstSkill &&
          accessGate.skillId == anchor.lastSkill,
      '${region.id} curriculum boundary mismatch',
    );
    _expect(
      _moves(regionStages.first) == anchor.firstMoves &&
          _moves(accessGate) == anchor.lastMoves,
      '${region.id} W/P/L boundary mismatch',
    );
    _expect(
      region.finalStageId == regionStages.last.id,
      '${region.id} final stage mismatch',
    );
    _expect(
      region.accessGateStageId ==
          'r${(index + 1).toString().padLeft(2, '0')}-c03-s10',
      '${region.id} access gate must preserve the C03 core milestone',
    );
    _expect(
      regionStages.take(30).every((stage) => stage.recurrencePlan == null) &&
          regionStages.skip(30).every((stage) => stage.recurrencePlan != null),
      '${region.id} should add exactly 30 explicit spiral revisits',
    );
    _verifyLayoutFixtureIdentity(regionStages, shouldBeVerified: false);
  }

  final matchTiers = stages.map((stage) => stage.matchDifficulty.tier).toSet();
  final mathTiers = stages.map((stage) => stage.mathDifficulty.tier).toSet();
  _expect(
    matchTiers.length == MatchDifficultyTier.values.length,
    'regional curve should exercise B0 through B4',
  );
  _expect(
    mathTiers.length == MathDifficultyTier.values.length,
    'regional curve should exercise M0 through M4',
  );
  _expect(
    regions.first.stages.every(
      (stage) => stage.matchDifficulty.tier.index <= 2,
    ),
    'the first region should stay within currently planned B0-B2 mechanics',
  );
  _expect(
    {for (final region in regions) ...region.featuredCharacterIds}.length == 26,
    'all 26 legacy characters should be featured across the seven regions',
  );
  _verifyRepresentativeDifficultyMetadata();
}

void _verifyRepresentativeDifficultyMetadata() {
  _expectMathMetadata(
    'r04-c01-s01',
    operations: 1,
    operatorKinds: 1,
    usesOrderOfOperations: false,
  );
  _expectMathMetadata(
    'r04-c02-s04',
    operations: 2,
    operatorKinds: 2,
    usesOrderOfOperations: true,
  );
  _expectMathMetadata(
    'r05-c02-s04',
    operations: 3,
    operatorKinds: 2,
    usesOrderOfOperations: true,
  );
  _expectMathMetadata(
    'r06-c03-s08',
    operations: 1,
    operatorKinds: 1,
    usesOrderOfOperations: false,
  );

  final layeredSeal = initialCampaign.stageById('r02-c02-s06')!;
  final dustObstacle = initialCampaign.stageById('r02-c02-s08')!;
  _expect(
    layeredSeal.matchDifficulty.maxSealLayers == 2 &&
        layeredSeal.matchDifficulty.obstacleCount == 0 &&
        dustObstacle.matchDifficulty.maxSealLayers == 1 &&
        dustObstacle.matchDifficulty.obstacleCount == 3,
    'B3 variants should be authored explicitly, not inferred from stage order',
  );
}

void _expectMathMetadata(
  String stageId, {
  required int operations,
  required int operatorKinds,
  required bool usesOrderOfOperations,
}) {
  final stage = initialCampaign.stageById(stageId)!;
  final math = stage.mathDifficulty;
  _expect(
    math.reasoningSteps == operations &&
        math.operatorKindCount == operatorKinds &&
        math.usesOrderOfOperations == usesOrderOfOperations,
    '$stageId answer-expression metadata mismatch',
  );
}

void _verifyPrototype() {
  const validator = CampaignValidator();
  final report = validator.validate(
    campaign: prototypeCampaign,
    puzzles: samplePuzzles,
  );
  _expect(
    report.isValid && report.warnings.isEmpty,
    'prototype campaign should be fully authored and valid',
  );
  _expect(verticalSliceStage.isPlayable, 'vertical slice should be playable');
  _expect(
    _moves(verticalSliceStage) == (3, 5, 12),
    'vertical slice should preserve its verified 3/5/12 budget',
  );
  _verifyLayoutFixtureIdentity([verticalSliceStage], shouldBeVerified: true);
  _verifyStarSemantics(verticalSliceStage);
  _verifyTutorialLayoutEquivalence(verticalSliceStage);
}

(int, int, int) _moves(StageDefinition stage) => (
  stage.moveBudget.referenceMoves,
  stage.moveBudget.parMoves,
  stage.moveBudget.moveLimit,
);

void _verifyLayoutFixtureIdentity(
  Iterable<StageDefinition> stages, {
  required bool shouldBeVerified,
}) {
  for (final stage in stages) {
    final variants = stage.boardVariants.variants;
    _expect(
      stage.boardVariants.supports(DiscoveryBoardConfig.compactPhone) &&
          stage.boardVariants.supports(DiscoveryBoardConfig.standardPhone),
      '${stage.id} should declare 5x5 and 6x6 fixtures',
    );
    _expect(
      variants.map((variant) => variant.fixtureId).toSet().length == 2 &&
          variants.map((variant) => variant.seed).toSet().length == 2,
      '${stage.id} fixtures should preserve independent IDs and seeds',
    );
    _expect(
      variants.every((variant) => variant.isVerified == shouldBeVerified),
      '${stage.id} fixture verification state is inaccurate',
    );
  }
}

void _verifyStarSemantics(StageDefinition stage) {
  const perfect = StageAttemptMetrics(
    completed: true,
    movesUsed: 5,
    meaningfulSubmissionCount: 1,
    firstMeaningfulSubmissionCorrect: true,
    highestMathHintTierUsed: 1,
    usedDirectPathHint: false,
    usedGuidedCompletion: false,
  );
  _expect(
    stage.starRules.evaluate(perfect, stage.moveBudget).total == 3,
    'perfect semantic attempt should earn all three stars',
  );
  const assisted = StageAttemptMetrics(
    completed: true,
    movesUsed: 6,
    meaningfulSubmissionCount: 2,
    firstMeaningfulSubmissionCorrect: false,
    highestMathHintTierUsed: 2,
    usedDirectPathHint: true,
    usedGuidedCompletion: true,
  );
  _expect(
    stage.starRules.evaluate(assisted, stage.moveBudget).total == 1,
    'completion should remain when mastery criteria are missed',
  );
}

void _verifyTutorialLayoutEquivalence(StageDefinition stage) {
  final puzzle = samplePuzzles.singleWhere(
    (candidate) => candidate.id == stage.puzzleId,
  );
  final tokenById = {for (final token in puzzle.tokens) token.id: token};
  for (final variant in stage.boardVariants.variants) {
    final engine = DiscoveryEngine(
      initialBoard: DiscoveryTutorialFixture.build(
        config: variant.config,
        timesTarget: _discoveryPiece(tokenById['p1-times']!),
        plusTarget: _discoveryPiece(tokenById['p1-plus']!),
        twoTarget: _discoveryPiece(tokenById['p1-n2']!),
      ),
      requiredTargetIds: stage.buriedTokenIds,
      moves: stage.moveLimit,
      refillSource: QueuedPieceSource(
        pieces: DiscoveryTutorialFixture.refillPieces(
          idPrefix: variant.fixtureId,
        ),
        fallback: SeededGemPieceSource(
          seed: variant.seed,
          idPrefix: '${variant.fixtureId}-fallback',
        ),
      ),
    );
    for (final step in DiscoveryTutorialFixture.steps) {
      _expect(
        engine.swap(step.from, step.to).isAccepted,
        '${variant.fixtureId} tutorial step should be accepted',
      );
    }
    final movesUsed = stage.moveLimit - engine.state.movesRemaining;
    _expect(
      engine.state.isCompleted &&
          movesUsed == stage.moveBudget.referenceMoves &&
          movesUsed <= stage.moveBudget.parMoves,
      '${variant.fixtureId} should complete at the shared W/P budget',
    );
  }
}

DiscoveryPiece _discoveryPiece(EquationToken token) => switch (token.kind) {
  EquationTokenKind.number => DiscoveryPiece.numberToken(
    id: token.id,
    label: token.label,
  ),
  EquationTokenKind.operator => DiscoveryPiece.operatorToken(
    id: token.id,
    label: token.label,
  ),
  EquationTokenKind.leftParenthesis || EquationTokenKind.rightParenthesis =>
    DiscoveryPiece.parenthesisToken(id: token.id, label: token.label),
};

void _expect(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}
