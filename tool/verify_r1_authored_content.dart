import 'dart:io';

import '../lib/features/campaign/data/initial_campaign.dart';
import '../lib/features/campaign/data/r1_authored_campaign.dart';
import '../lib/features/campaign/data/regional_campaign.dart';
import '../lib/features/campaign/domain/campaign_validator.dart';
import '../lib/features/campaign/domain/learning_models.dart';
import '../lib/features/puzzle/domain/equation_token.dart';
import '../lib/features/puzzle/domain/puzzle.dart';

void main() {
  _expect(r1PuzzlesByStageId.length == 60, 'exactly60 authored stages');
  final report = const CampaignValidator().validate(
    campaign: initialCampaign,
    puzzles: r1PuzzlesByStageId.values,
  );
  _expect(
    report.isValid,
    report.errors
        .map((issue) => '${issue.location}: ${issue.message}')
        .join('\n'),
  );
  _expect(report.warnings.length == 360, 'remaining360 stages stay planned');
  _expect(
    regionalCampaign.stages.every((stage) => !stage.hasAuthoredPuzzle),
    'blueprint stays immutable and planned',
  );
  for (final entry in r1PuzzlesByStageId.entries) {
    final stage = initialCampaign.stageById(entry.key)!;
    final puzzle = entry.value;
    final blueprint = regionalCampaign.stageById(entry.key)!;
    _expect(stage.isPlayable, '${stage.id} runtime readiness');
    _expect(
      stage.learningPlan.status == LearningPlanStatus.authored,
      'authored',
    );
    _expect(puzzle.learningSupport!.hasCompletePlayableSupport, 'support');
    _expect(puzzle.visualDescription.isNotEmpty, 'text visual equivalent');
    _expect(puzzle.question.length <= 110, 'compact real Korean question');
    _expect(puzzle.tokens.length <= 7, 'compact token manifest');
    _expect(stage.seed == blueprint.seed, 'problem seed preserved');
    _expect(stage.skillId == blueprint.skillId, 'stable skill ID');
    _expect(stage.puzzleId == blueprint.puzzleId, 'stable puzzle ID');
    _expect(
      stage.buriedTokenIds.length >= 2 && stage.buriedTokenIds.length <= 3,
      'bounded baseline seals',
    );
    _expect(
      stage.startingTokenIds.intersection(stage.buriedTokenIds).isEmpty,
      'disjoint token manifest',
    );
    final byId = {for (final token in puzzle.tokens) token.id: token};
    final expression = [
      for (final id in r1AnswerTokenIdsByStageId[entry.key]!) byId[id]!,
    ];
    _expect(
      const PuzzleValidator().validate(puzzle, expression).isCorrect,
      'answer AST accepted ${stage.id}',
    );
    _expect(
      expression.map((token) => token.label).join() == stage.answerExpression,
      'answer token order',
    );
    final flippedOperator = expression
        .map(
          (token) => token.kind == EquationTokenKind.operator
              ? EquationToken(
                  id: token.id,
                  label: token.label == '+' ? '-' : '+',
                  kind: token.kind,
                )
              : token,
        )
        .toList();
    _expect(
      !const PuzzleValidator().validate(puzzle, flippedOperator).isCorrect,
      'altered operator rejected',
    );
    for (final fixture in stage.boardVariants.variants) {
      final original = blueprint.boardVariants.variantFor(fixture.config);
      _expect(
        fixture.fixtureId == original.fixtureId &&
            fixture.seed == original.seed,
        'stable physical fixture IDs/seeds',
      );
    }
    if (stage.chapterId == 'r01-c04' ||
        stage.chapterId == 'r01-c05' ||
        stage.chapterId == 'r01-c06') {
      final recurrence = stage.recurrencePlan!;
      final source = initialCampaign.stageById(recurrence.sourceStageId)!;
      _expect(
        recurrence.source.meaningfulFingerprint ==
            source.variantProfile.meaningfulFingerprint,
        'actual source profile',
      );
      _expect(
        stage.variantProfile.isIndependentVariationFrom(source.variantProfile),
        'actual independent review ${stage.id}',
      );
      _expect(
        source.learningPlan.additionalUnlockStageIds.contains(stage.id) ==
            (stage.chapterId == 'r01-c04'),
        'only C04 gets early source-linked access',
      );
    }
  }
  _expect(
    initialCampaign
        .stageById('r01-c03-s10')!
        .learningPlan
        .additionalUnlockStageIds
        .contains('r02-c01-s01'),
    'original next region gate',
  );
  stdout.writeln(
    'R1 authored content verification passed:60 alpha stages, '
    'actual ASTs including parentheses, complete support,30 independent '
    'source-linked revisits,360 planned slots; '
    'board paths/human calibration checked separately.',
  );
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
