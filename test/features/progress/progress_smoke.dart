// Standalone Dart check for persistence without a Flutter device/runtime.
import 'dart:io';

import '../../../lib/features/campaign/data/initial_campaign.dart';
import '../../../lib/features/campaign/domain/campaign_models.dart';
import '../../../lib/features/progress/data/progress_repository.dart';
import '../../../lib/features/progress/domain/progress_models.dart';
import '../../../lib/features/progress/domain/stage_completion_service.dart';

Future<void> main() async {
  final store = MemoryKeyValueSaveStore();
  final repo = ProgressRepository(store);
  final service = StageCompletionService(repo);
  final attempt = StageAttemptResult(
    attemptId: 'smoke-attempt',
    stage: verticalSliceStage,
    completedAt: DateTime(2026, 10, 11),
    metrics: const StageAttemptMetrics(
      completed: true,
      movesUsed: 3,
      meaningfulSubmissionCount: 1,
      firstMeaningfulSubmissionCorrect: true,
      highestMathHintTierUsed: 0,
      usedDirectPathHint: true,
      usedGuidedCompletion: true,
    ),
  );
  await Future.wait([service.complete(attempt), service.complete(attempt)]);
  final saved = await ProgressRepository(store).load();
  if (saved.generation != 1 ||
      saved.rewardLedger.length != 1 ||
      saved.dailyActions['2026-10-11'] != 1) {
    throw StateError('Idempotent completion or persisted state failed.');
  }
  if (saved.skillProgress.values.single.independentVariantProfiles.isNotEmpty) {
    throw StateError('Forced tutorial produced independent mastery evidence.');
  }
  await Future.wait(
    List.generate(
      10,
      (i) => repo.update(
        (s) => s.copyWith(viewedStoryIds: {...s.viewedStoryIds, 'smoke-$i'}),
      ),
    ),
  );
  if ((await repo.load()).viewedStoryIds.length != 10)
    throw StateError('Serialized update lost progress.');
  stdout.writeln(
    'Progress smoke passed: serialized saves, restart, idempotent rewards, tutorial evidence.',
  );
}
