import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/campaign/data/r1_authored_campaign.dart';
import 'package:kvm/features/campaign/data/regional_campaign.dart';
import 'package:kvm/features/campaign/domain/board_mechanic_models.dart';
import 'package:kvm/features/campaign/domain/campaign_validator.dart';
import 'package:kvm/features/campaign/domain/sentence_math_validator.dart';
import 'package:kvm/features/puzzle/domain/puzzle.dart';
import 'package:kvm/features/puzzle/domain/puzzle_learning_support.dart';
import 'package:kvm/features/puzzle/domain/sentence_math_problem.dart';
import 'package:kvm/features/progress/domain/campaign_access_policy.dart';

void main() {
  test('R2 has sixty distinct authored records with real AST/support', () {
    final region = initialCampaign.regions[1];
    expect(r2PuzzlesByStageId, hasLength(60));
    expect(region.chapters, hasLength(6));
    expect(
      r2PuzzlesByStageId.values.map((p) => p.question).toSet(),
      hasLength(60),
    );
    for (final chapter in region.chapters) {
      expect(chapter.stages, hasLength(10));
      for (final stage in chapter.stages) {
        final puzzle = r2PuzzlesByStageId[stage.id]!;
        final blueprint = regionalCampaign.stageById(stage.id)!;
        expect(stage.isPlayable, isTrue);
        expect(stage.seed, blueprint.seed);
        expect(
          stage.learningPlan.nextStageId,
          blueprint.learningPlan.nextStageId,
        );
        expect(puzzle.question.length, lessThanOrEqualTo(120));
        expect(
          const SentenceMathValidator().validate(stage, puzzle),
          isEmpty,
          reason: stage.id,
        );
        expect(
          puzzle.sentenceMath!.presentationKind,
          ProblemPresentationKind.textRecord,
        );
        expect(puzzle.learningSupport!.hasCompletePlayableSupport, isTrue);
        expect(puzzle.learningSupport!.hintSteps.map((h) => h.kind), [
          PuzzleHintKind.observation,
          PuzzleHintKind.relationship,
          PuzzleHintKind.partialExpression,
        ]);
        expect(
          const PuzzleValidator().validate(puzzle, puzzle.tokens).isCorrect,
          isTrue,
        );
        expect(
          puzzle.tokens.map((t) => t.id).toSet().length,
          puzzle.tokens.length,
        );
        expect({
          ...stage.startingTokenIds,
          ...stage.buriedTokenIds,
        }, puzzle.requiredTokenIds);
        if (chapter.number >= 4) {
          final source = initialCampaign.stageById(
            stage.recurrencePlan!.sourceStageId,
          )!;
          expect(source.isPlayable, isTrue);
          expect(
            source.variantProfile.isIndependentVariationFrom(
              stage.variantProfile,
            ),
            isTrue,
            reason: stage.id,
          );
          expect(
            stage.recurrencePlan!.source.meaningfulFingerprint,
            source.variantProfile.meaningfulFingerprint,
          );
        }
      }
    }
    final report = const CampaignValidator().validate(
      campaign: initialCampaign,
      puzzles: authoredPuzzlesByStageId.values,
    );
    expect(
      report.errors,
      isEmpty,
      reason: report.errors
          .map((e) => '${e.location}: ${e.message}')
          .join('\n'),
    );
    expect(report.warnings, hasLength(300));
  });

  test('R2 mathematics changes while the core board stays unchanged', () {
    final core = initialCampaign.regions[1].chapters
        .take(3)
        .expand((c) => c.stages);
    final first = core.first;
    for (final stage in core) {
      final power = stage.boardMechanicPlan.bindings
          .map((b) => b.rule)
          .whereType<LinePowerRule>()
          .single;
      final firstPower = first.boardMechanicPlan.bindings
          .map((b) => b.rule)
          .whereType<LinePowerRule>()
          .single;
      expect(power.logicalSignature, firstPower.logicalSignature);
      expect(stage.boardMechanicPlan.challengeLevel, 4);
      expect(stage.matchDifficulty.obstacleCount, 1);
      expect(stage.matchDifficulty.maxSealLayers, 1);
      expect(
        stage.boardMechanicPlan.mechanicIds,
        isNot(contains(BoardMechanicId.swapLock)),
      );
    }
    final hardVines = initialCampaign.stageById('r02-c05-s06')!;
    expect(hardVines.boardMechanicPlan.learningSourceStageId, 'r02-c03-s01');
    expect(
      hardVines.boardMechanicPlan.bindings
          .map((b) => b.rule)
          .whereType<AdjacentHitBlockerRule>()
          .single
          .durability,
      2,
    );
    final stages = initialCampaign.regions[1].stages.toList();
    for (var i = 1; i < stages.length; i++) {
      final current = stages[i], previous = stages[i - 1];
      if (current.boardMechanicPlan.challengeLevel <=
          previous.boardMechanicPlan.challengeLevel)
        continue;
      expect(
        current.boardMechanicPlan.learningSourceStageId,
        isNotNull,
        reason: current.id,
      );
      expect(
        current.mathDifficulty.tier.index,
        lessThanOrEqualTo(previous.mathDifficulty.tier.index),
      );
      expect(
        current.mathDifficulty.reasoningSteps,
        lessThanOrEqualTo(previous.mathDifficulty.reasoningSteps),
      );
      expect(
        current.mathDifficulty.operatorKindCount,
        lessThanOrEqualTo(previous.mathDifficulty.operatorKindCount),
      );
    }
  });

  test(
    'R2 entry requires R1 core gate, not optional R1 chapter completion',
    () {
      final stage = initialCampaign.stageById('r02-c01-s01')!;
      const access = CampaignAccessPolicy();
      expect(access.canEnterStage(stage, initialCampaign, const {}), isFalse);
      expect(
        access.canEnterStage(stage, initialCampaign, const {'r01-c03-s10'}),
        isTrue,
      );
      expect(
        access.canEnterStage(
          initialCampaign.stageById('r03-c01-s01')!,
          initialCampaign,
          const {'r01-c03-s10', 'r02-c03-s10'},
        ),
        isFalse,
      );
    },
  );

  test('R1 authored and legacy contracts are unchanged by the R2 overlay', () {
    final r1Only = buildR1Campaign(regionalCampaign);
    for (final stage in initialCampaign.regions.first.stages) {
      final before = r1Only.stageById(stage.id)!;
      expect(stage.answerExpression, before.answerExpression);
      expect(
        stage.variantProfile.meaningfulFingerprint,
        before.variantProfile.meaningfulFingerprint,
      );
      expect(
        stage.boardMechanicPlan.logicalSignature,
        before.boardMechanicPlan.logicalSignature,
      );
      expect(
        stage.boardVariants.variants.map((v) => v.fixtureId),
        before.boardVariants.variants.map((v) => v.fixtureId),
      );
      expect(stage.startingTokenIds, before.startingTokenIds);
      expect(stage.buriedTokenIds, before.buriedTokenIds);
      expect(
        r1LegacyStagesById[stage.id]!.boardVariants.variants.every(
          (v) => !v.fixtureId.endsWith('-physics3'),
        ),
        isTrue,
      );
    }
  });
}
