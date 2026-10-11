import 'dart:convert';
import 'dart:io';

import '../lib/features/campaign/data/initial_campaign.dart';
import '../lib/features/campaign/domain/campaign_models.dart';
import '../lib/features/garden/data/garden_catalog.dart';
import '../lib/features/progress/data/progress_repository.dart';
import '../lib/features/progress/domain/campaign_access_policy.dart';
import '../lib/features/progress/domain/daily_route_service.dart';
import '../lib/features/progress/domain/progress_models.dart';
import '../lib/features/progress/domain/stage_completion_service.dart';

Future<void> main() async {
  final store = MemoryKeyValueSaveStore();
  var repository = ProgressRepository(store);
  final region = initialCampaign.regions.first;
  final orderedStages = region.stages.toList();
  final garden = gardenDefinitionByRegionId(region.id)!;
  _expect(region.stages.length == 60, 'R1 has 60 stable stage IDs');
  _expect(region.stages.every((stage) => stage.isPlayable), 'R1 authored');
  _expect(garden.restorationNodes.length == 24, '24 restoration nodes');
  _expect(garden.projectScenes.length == 6, 'six chapter projects');
  _expect(r1CharacterStories.length == 4, 'four inherited characters');

  final earnedNodes = <String>{};
  for (var index = 0; index < 60; index++) {
    final before = await repository.load();
    final now = DateTime(2026, 10, 11 + index ~/ 5, 10);
    final route = const DailyRouteService().build(
      before,
      initialCampaign,
      now: now,
    );
    final stage = route.explorationStage;
    _expect(stage != null, 'no dead end before stage ${index + 1}');
    _expect(
      stage!.id == orderedStages[index].id,
      'sequential route ${stage.id}',
    );
    _expect(
      const CampaignAccessPolicy().canEnterStage(
        stage,
        initialCampaign,
        before.completedStageIds,
      ),
      'source/project gates ${stage.id}',
    );
    final result = _success(stage, index, now);
    final service = StageCompletionService(
      repository,
      campaign: initialCampaign,
    );
    final receipt = await service.complete(result);
    _expect(receipt.firstCompletion, 'first completion ${stage.id}');
    _expect(receipt.stars >= 1, 'assistance does not block rewards');
    earnedNodes.addAll(receipt.unlockedRestorationNodeIds);
    for (final nodeId in receipt.unlockedRestorationNodeIds) {
      final node = garden.nodeById(nodeId);
      _expect(node != null, 'earned node exists $nodeId');
      _expect(node!.requiredStageId == stage.id, 'node maps to exact stage');
      await repository.update((current) {
        final authorized = current.rewardLedger.values.any(
          (reward) => reward.unlockedRestorationNodeIds.contains(nodeId),
        );
        _expect(authorized, 'restoration was earned');
        return current.copyWith(
          restoredNodeIds: {...current.restoredNodeIds, nodeId},
          decorationChoices: {...current.decorationChoices, nodeId: 'herbs'},
          viewedStoryIds: {...current.viewedStoryIds, node.storyId},
        );
      });
    }
    final after = await repository.load();
    final duplicate = await service.complete(result);
    final afterDuplicate = await repository.load();
    _expect(
      duplicate.attemptId == receipt.attemptId,
      'same completion receipt',
    );
    _expect(
      afterDuplicate.generation == after.generation,
      'duplicate is no-op',
    );
    _expect(
      afterDuplicate.dailyActions.length == after.dailyActions.length,
      'no duplicated calendar record',
    );
    _expect(
      afterDuplicate.restoredNodeIds.length == earnedNodes.length,
      'restoration persists independently of reward replay',
    );
    if ((index + 1) % 5 == 0) {
      // New repository instance simulates loading the committed double slot.
      repository = ProgressRepository(store);
      final resumed = await repository.load();
      _expect(resumed.completedStageIds.contains(stage.id), 'restart stage');
      _expect(
        resumed.restoredNodeIds.length == earnedNodes.length,
        'restart garden',
      );
    }
  }

  final finalSave = await repository.load();
  final finalRoute = const DailyRouteService().build(
    finalSave,
    initialCampaign,
    now: DateTime(2026, 11, 1),
  );
  _expect(
    finalSave.completedStageIds.length == 60,
    'all sixty first completions',
  );
  _expect(finalSave.rewardLedger.length == 60, 'one ledger entry per attempt');
  _expect(finalSave.restoredNodeIds.length == 24, 'all restoration projects');
  _expect(
    finalSave.decorationChoices.length == 24,
    'all decorations persisted',
  );
  _expect(
    finalSave.viewedStoryIds.length == 24,
    'all restoration stories persisted',
  );
  _expect(
    finalSave.unlockedCharacterIds.containsAll(region.featuredCharacterIds),
    'four characters unlocked',
  );
  _expect(
    finalSave.unlockedStageIds.contains('r02-c01-s01'),
    'next region metadata preserved',
  );
  _expect(finalRoute.explorationStage == null, 'no fake new stage after R1');
  _expect(
    finalRoute.completedRegionIds.contains(region.id),
    'R1 complete contract',
  );
  _expect(
    !finalRoute.campaignCompleted,
    'future planned regions are not complete',
  );
  _expect(finalRoute.reviewStage != null, 'review remains available after R1');
  final reencoded = SaveEnvelopeV1.fromJson(
    jsonDecode(jsonEncode(finalSave.toJson())),
  );
  _expect(reencoded.restoredNodeIds.length == 24, 'version-one round trip');
  stdout.writeln(
    'R1 progress verification PASS: 60 stages, 24 restorations, '
    '4 characters, 60 duplicate deliveries, 12 repository restarts.',
  );
}

StageAttemptResult _success(StageDefinition stage, int index, DateTime now) =>
    StageAttemptResult(
      attemptId: 'r1-full-${stage.id}',
      stage: stage,
      completedAt: now,
      metrics: StageAttemptMetrics(
        completed: true,
        movesUsed: stage.moveBudget.referenceMoves,
        meaningfulSubmissionCount: 1,
        firstMeaningfulSubmissionCorrect: true,
        highestMathHintTierUsed: index.isEven ? 3 : 0,
        usedDirectPathHint: index.isEven,
        usedGuidedCompletion: index.isEven,
      ),
    );

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
