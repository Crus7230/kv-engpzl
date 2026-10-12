import 'dart:io';

import '../lib/features/campaign/data/initial_campaign.dart'
    hide initialCampaign;
import '../lib/features/campaign/data/regional_campaign.dart' as blueprint;
import '../lib/features/campaign/domain/board_mechanic_models.dart';
import '../lib/features/campaign/domain/campaign_models.dart';
import '../lib/features/campaign/domain/campaign_validator.dart';
import '../lib/features/puzzle/data/sample_puzzles.dart';

// Preserve blueprint-only introduction/cadence assertions.
final initialCampaign = blueprint.regionalCampaign;

void main() {
  _verifyCatalogSequence();
  _verifyRegionalSkins();
  _verifyMechanicChapters();
  _verifyCapabilityBoundary();
  stdout.writeln(
    'Board mechanic catalog verification passed: 420 plans, seven advanced '
    'introductions, C05/C06 cadence, regional skins, and playable capability.',
  );
}

void _verifyCatalogSequence() {
  final stages = initialCampaign.stages.toList(growable: false);
  _expect(
    stages.length == 420,
    'The regional catalog must contain 420 stages.',
  );
  _expect(
    stages.every((stage) => stage.contentStatus == StageContentStatus.planned),
    'No regional stage may be playable before its content and fixtures exist.',
  );

  final sequenceIssues = const BoardMechanicSequenceValidator().validate(
    stages.map((stage) => stage.boardMechanicPlan),
  );
  _expect(
    sequenceIssues.isEmpty,
    'Board mechanic sequence errors: ${sequenceIssues.map((issue) => '${issue.planId}:${issue.code.name}').join(' | ')}',
  );

  final firstStageByMechanic = <BoardMechanicId, StageDefinition>{};
  for (final stage in stages) {
    final baselineRules = stage.boardMechanicPlan.bindings
        .map((binding) => binding.rule)
        .whereType<SingleLayerSealRule>()
        .toList(growable: false);
    _expect(
      baselineRules.length == 1 &&
          baselineRules.single.sealCount ==
              stage.matchDifficulty.requiredSealCount,
      '${stage.id} must have one baseline seal rule matching MatchDifficulty.',
    );
    for (final mechanicId in _advanced(stage)) {
      firstStageByMechanic.putIfAbsent(mechanicId, () => stage);
    }
  }

  const expectedIntroductions = [
    (BoardMechanicId.layeredSeal, 'r01-c05-s02'),
    (BoardMechanicId.linePower, 'r01-c05-s07'),
    (BoardMechanicId.adjacentHitBlocker, 'r02-c02-s08'),
    (BoardMechanicId.swapLock, 'r02-c05-s07'),
    (BoardMechanicId.fixedBlocker, 'r03-c05-s02'),
    (BoardMechanicId.conveyor, 'r03-c05-s07'),
    (BoardMechanicId.portal, 'r04-c05-s02'),
  ];
  _expect(
    firstStageByMechanic.length == expectedIntroductions.length,
    'The catalog must exercise exactly seven advanced mechanics.',
  );
  for (final (mechanicId, stageId) in expectedIntroductions) {
    final firstStage = firstStageByMechanic[mechanicId];
    _expect(
      firstStage?.id == stageId &&
          firstStage?.boardMechanicPlan.role == BoardMechanicRole.introduce &&
          firstStage?.boardMechanicPlan.advancedMechanicIds.length == 1,
      '${mechanicId.name} must first appear alone at $stageId.',
    );
  }
}

void _verifyRegionalSkins() {
  for (final region in initialCampaign.regions) {
    final regionKey = region.number.toString().padLeft(2, '0');
    for (final stage in region.stages) {
      for (final binding in stage.boardMechanicPlan.bindings) {
        final expectedKey = 'region.$regionKey.${binding.rule.mechanicId.name}';
        _expect(
          binding.skin.mechanicId == binding.rule.mechanicId &&
              binding.skin.key == expectedKey,
          '${stage.id} must use the regional skin $expectedKey.',
        );
      }
    }
  }
}

void _verifyMechanicChapters() {
  final orderedStages = initialCampaign.stages.toList(growable: false);
  final stageIndexById = {
    for (var index = 0; index < orderedStages.length; index += 1)
      orderedStages[index].id: index,
  };
  final firstIndexByMechanic = <BoardMechanicId, int>{};
  for (var index = 0; index < orderedStages.length; index += 1) {
    for (final mechanicId in _advanced(orderedStages[index])) {
      firstIndexByMechanic.putIfAbsent(mechanicId, () => index);
    }
  }

  for (final region in initialCampaign.regions) {
    final chapterFive = region.chapters.singleWhere(
      (chapter) => chapter.number == 5,
    );
    final c05 = chapterFive.stages;
    _expect(c05.length == 10, '${chapterFive.id} must contain ten stages.');

    final first = _advanced(c05[1]).single;
    final second = _advanced(c05[6]).single;
    _expect(first != second, '${chapterFive.id} needs two distinct mechanics.');

    _expect(
      _advanced(c05[0]).isEmpty && _advanced(c05[5]).isEmpty,
      '${chapterFive.id} stages 1 and 6 must be baseline recovery stages.',
    );
    for (final index in const [1, 2, 3, 4]) {
      _expect(
        _sameSet(_advanced(c05[index]), {first}),
        '${c05[index].id} must practice only ${first.name}.',
      );
    }
    for (final index in const [6, 7]) {
      _expect(
        _sameSet(_advanced(c05[index]), {second}),
        '${c05[index].id} must practice only ${second.name}.',
      );
    }
    for (final index in const [8, 9]) {
      _expect(
        _sameSet(_advanced(c05[index]), {first, second}) &&
            c05[index].boardMechanicPlan.role == BoardMechanicRole.mixed,
        '${c05[index].id} must mix only the two established regional mechanics.',
      );
    }

    final firstOpeningRole = c05[1].boardMechanicPlan.role;
    final secondOpeningRole = c05[6].boardMechanicPlan.role;
    _expect(
      firstOpeningRole == BoardMechanicRole.introduce ||
          firstOpeningRole == BoardMechanicRole.review,
      '${c05[1].id} must introduce or revisit its first mechanic.',
    );
    _expect(
      secondOpeningRole == BoardMechanicRole.introduce ||
          secondOpeningRole == BoardMechanicRole.review,
      '${c05[6].id} must introduce or revisit its second mechanic.',
    );
    _expect(
      c05[2].boardMechanicPlan.role == BoardMechanicRole.guided &&
          c05[3].boardMechanicPlan.role == BoardMechanicRole.independent &&
          c05[4].boardMechanicPlan.role == BoardMechanicRole.review &&
          c05[7].boardMechanicPlan.role == BoardMechanicRole.independent,
      '${chapterFive.id} must preserve introduce, guided, independent, and review cadence.',
    );

    final chapterSix = region.chapters.singleWhere(
      (chapter) => chapter.number == 6,
    );
    final c06 = chapterSix.stages;
    _expect(c06.length == 10, '${chapterSix.id} must contain ten stages.');
    for (final index in const [0, 2, 4]) {
      _expect(
        _sameSet(_advanced(c06[index]), {first}) &&
            c06[index].boardMechanicPlan.role == BoardMechanicRole.review,
        '${c06[index].id} must review only ${first.name}.',
      );
    }
    for (final index in const [1, 5, 6]) {
      _expect(
        _sameSet(_advanced(c06[index]), {second}) &&
            c06[index].boardMechanicPlan.role == BoardMechanicRole.review,
        '${c06[index].id} must review only ${second.name}.',
      );
    }
    for (final index in const [3, 7, 8, 9]) {
      _expect(
        _sameSet(_advanced(c06[index]), {first, second}) &&
            c06[index].boardMechanicPlan.role == BoardMechanicRole.mixed,
        '${c06[index].id} must combine both previously introduced mechanics.',
      );
    }
    final c06Start = stageIndexById[c06.first.id]!;
    _expect(
      firstIndexByMechanic[first]! < c06Start &&
          firstIndexByMechanic[second]! < c06Start,
      '${chapterSix.id} must not introduce a mechanic while combining effects.',
    );
  }
}

void _verifyCapabilityBoundary() {
  final capabilities = currentDiscoveryBoardMechanics;
  _expect(
    capabilities.capabilityFor(BoardMechanicId.singleLayerSeal).supportState ==
        BoardMechanicSupportState.supported,
    'The single-layer core remains supported.',
  );
  for (final mechanicId in const [
    BoardMechanicId.layeredSeal,
    BoardMechanicId.linePower,
  ]) {
    _expect(
      capabilities.capabilityFor(mechanicId).supportState ==
          BoardMechanicSupportState.supported,
      '${mechanicId.name} has executable paired fixtures.',
    );
  }
  _expect(
    capabilities
            .capabilityFor(BoardMechanicId.adjacentHitBlocker)
            .supportState ==
        BoardMechanicSupportState.supported,
    'Adjacent-hit covers are implemented; fixed blockers remain planned.',
  );
  for (final mechanicId in const [
    BoardMechanicId.swapLock,
    BoardMechanicId.fixedBlocker,
    BoardMechanicId.portal,
    BoardMechanicId.conveyor,
  ]) {
    _expect(
      capabilities.capabilityFor(mechanicId).supportState ==
          BoardMechanicSupportState.planned,
      '${mechanicId.name} must remain planned.',
    );
  }

  final advancedStages = initialCampaign.stages.where(
    (stage) => _advanced(stage).isNotEmpty,
  );
  _expect(
    advancedStages.isNotEmpty &&
        advancedStages.every((stage) => !stage.isPlayable),
    'The immutable regional blueprint remains non-playable until authored.',
  );
  _expect(
    verticalSliceStage.isPlayable &&
        capabilities.supportsForPlay(verticalSliceStage.boardMechanicPlan),
    'The verified single-layer prototype must remain capability-compatible.',
  );

  final unsupportedStage = _copyWithBoardMechanics(
    verticalSliceStage,
    BoardMechanicPlan(
      id: 'unsupported-playable-mechanics',
      role: BoardMechanicRole.introduce,
      bindings: [
        BoardMechanicBinding(
          rule: SingleLayerSealRule(
            sealCount: verticalSliceStage.matchDifficulty.requiredSealCount,
          ),
          skin: BoardMechanicSkin(
            key: 'prototype.seal.default',
            mechanicId: BoardMechanicId.singleLayerSeal,
          ),
        ),
        BoardMechanicBinding(
          rule: AdjacentHitBlockerRule(blockerCount: 1, durability: 1),
          skin: BoardMechanicSkin(
            key: 'prototype.blocker.adjacent',
            mechanicId: BoardMechanicId.adjacentHitBlocker,
          ),
        ),
      ],
    ),
  );
  final unsupportedCampaign = CampaignDefinition(
    id: 'unsupported-board-mechanic-probe',
    version: 1,
    chapters: [
      ChapterDefinition(
        id: unsupportedStage.chapterId,
        number: 1,
        title: 'Capability probe',
        description: 'Validator regression fixture.',
        prerequisiteChapterId: null,
        stages: [unsupportedStage],
      ),
    ],
  );
  final report = const CampaignValidator().validate(
    campaign: unsupportedCampaign,
    puzzles: samplePuzzles,
  );
  _expect(
    report.errors.any(
      (issue) =>
          issue.code == CampaignIssueCode.unsupportedPlayableBoardMechanic,
    ),
    'CampaignValidator must reject a playable model-only mechanic.',
  );
}

StageDefinition _copyWithBoardMechanics(
  StageDefinition source,
  BoardMechanicPlan boardMechanicPlan,
) => StageDefinition(
  id: source.id,
  chapterId: source.chapterId,
  skillId: source.skillId,
  number: source.number,
  title: source.title,
  conceptLabel: source.conceptLabel,
  answerExpression: source.answerExpression,
  puzzleId: source.puzzleId,
  contentStatus: source.contentStatus,
  mathDifficulty: source.mathDifficulty,
  matchDifficulty: source.matchDifficulty,
  boardMechanicPlan: boardMechanicPlan,
  boardVariants: source.boardVariants,
  moveBudget: source.moveBudget,
  starRules: source.starRules,
  assistRules: source.assistRules,
  learningPlan: source.learningPlan,
  variantProfile: source.variantProfile,
  recurrencePlan: source.recurrencePlan,
  sentenceMathPlan: source.sentenceMathPlan,
  seed: source.seed,
  startingTokenIds: source.startingTokenIds,
  buriedTokenIds: source.buriedTokenIds,
  decoyTokenIds: source.decoyTokenIds,
);

Set<BoardMechanicId> _advanced(StageDefinition stage) =>
    stage.boardMechanicPlan.advancedMechanicIds;

bool _sameSet<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);

void _expect(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}
