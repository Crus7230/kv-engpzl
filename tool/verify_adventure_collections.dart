import 'dart:convert';
import 'dart:io';

import '../lib/core/branding/intro_motion_timeline.dart';
import '../lib/features/campaign/data/initial_campaign.dart';
import '../lib/features/campaign/data/regional_campaign.dart';
import '../lib/features/campaign/domain/campaign_models.dart';
import '../lib/features/campaign/domain/learning_models.dart';
import '../lib/features/garden/data/garden_catalog.dart';
import '../lib/features/progress/domain/adventure_collection_service.dart';
import '../lib/features/progress/domain/progress_models.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  const service = AdventureCollectionService();
  final now = DateTime(2026, 10, 13);
  final fresh = SaveEnvelopeV1.initial();
  check(
    service.memorySeeds(fresh, initialCampaign, now: now).seeds.isEmpty,
    'No seed is invented for a new player',
  );
  final freshJournal = service.journal(
    fresh,
    initialCampaign,
    gardenDefinitions,
    now: now,
  );
  check(
    freshJournal.stamps.length == 12,
    'Only the 12 authored R1/R2 chapters enter the passport',
  );
  check(
    freshJournal.stamps.every((stamp) => !stamp.stamped),
    'New players do not receive chapter stamps',
  );
  check(
    freshJournal.stamps
        .where((stamp) => stamp.regionId == 'region-02-pattern')
        .every((stamp) => !stamp.canExplore),
    'Passport retains the R1 to R2 access gate',
  );

  final firstChapter = initialCampaign.regions.first.chapters.first;
  final garden = gardenDefinitions.first;
  final firstNode = garden.restorationNodes.first;
  final receipt = CompletionReceipt(
    attemptId: 'collection-fixture',
    stageId: firstNode.requiredStageId,
    stars: 1,
    firstCompletion: true,
    supportReviewNeeded: true,
    unlockedRestorationNodeIds: [firstNode.id],
  );
  final snapshot = SaveEnvelopeV1(
    completedStageIds: [
      ...firstChapter.stages.map((stage) => stage.id),
      'future-stage-id',
    ],
    unlockedStageIds: firstChapter.stages.map((stage) => stage.id),
    playerCharacterId: 'CHAR_D',
    starterCharacterId: 'CHAR_D',
    unlockedCharacterIds: const ['CHAR_D', 'CHAR_J'],
    dailyReviewActions: const {
      '2026-10-01': 1,
      '2026-10-03': 8,
      '2026-10-07': 1,
      '2026-10-09': 1,
      '2026-10-13': 1,
      '2026-10-14': 1,
    },
    dailyActions: const {'2026-10-09': 2, '2026-10-13': 3},
    rewardLedger: {receipt.attemptId: receipt},
  );
  final before = jsonEncode(snapshot.toJson());
  final seeds = service.memorySeeds(snapshot, initialCampaign, now: now);
  check(
    seeds.reviewDays == 5 &&
        seeds.bouquets == 1 &&
        seeds.nextBouquetProgress == 0,
    'One petal per completed review date, not per repeated attempt',
  );
  check(
    seeds.seeds.fold<int>(0, (sum, seed) => sum + seed.completedVariations) ==
        10,
    'Unknown stages create no cosmetic seeds',
  );
  check(
    seeds.seeds.every((seed) => seed.mastery == SkillMasteryState.learning),
    'Cosmetic growth does not invent mastery or exclude supported clears',
  );
  final tomorrow = service.memorySeeds(
    snapshot,
    initialCampaign,
    now: DateTime(2026, 10, 14),
  );
  check(
    tomorrow.reviewDays == 6 &&
        tomorrow.bouquets == 1 &&
        tomorrow.nextBouquetProgress == 1,
    'No consecutive-day or streak reset',
  );
  final resumed = service.memorySeeds(
    snapshot.copyWith(
      activeSession: {'stageId': 'r01-c01-s01', 'isDailyReview': true},
    ),
    initialCampaign,
    now: now,
  );
  check(resumed.hasActiveReview, 'Saved daily reviews retain resume access');

  final journal = service.journal(
    snapshot,
    initialCampaign,
    gardenDefinitions,
    now: now,
  );
  final stamp = journal.stamps.first;
  check(
    stamp.stamped && stamp.completedStages == 10,
    'A completed authored chapter receives its stamp',
  );
  final partialChapter = ChapterDefinition(
    id: firstChapter.id,
    number: firstChapter.number,
    title: firstChapter.title,
    description: firstChapter.description,
    prerequisiteChapterId: firstChapter.prerequisiteChapterId,
    stages: [
      ...firstChapter.stages.take(2),
      ...regionalCampaign.regions.first.chapters.first.stages.skip(2),
    ],
  );
  final partialCampaign = CampaignDefinition.regional(
    id: 'partial-collection-fixture',
    version: 1,
    regions: [
      RegionDefinition(
        metadata: initialCampaign.regions.first.metadata,
        chapters: [partialChapter],
      ),
    ],
  );
  final partial = service.journal(
    snapshot,
    partialCampaign,
    gardenDefinitions,
    now: now,
  );
  check(
    partial.stamps.single.completedStages == 2 &&
        !partial.stamps.single.stamped,
    'A partly authored chapter does not masquerade as a completed chapter',
  );
  check(
    stamp.traces.first.state == ExpeditionTraceState.discovered,
    'Reward ledger discovery is separate from a recorded restoration',
  );
  check(
    stamp.traces
        .skip(1)
        .every((trace) => trace.state == ExpeditionTraceState.hidden),
    'Completed stage IDs alone do not fabricate restoration rewards',
  );
  final restored = service.journal(
    snapshot.copyWith(restoredNodeIds: [firstNode.id]),
    initialCampaign,
    gardenDefinitions,
    now: now,
  );
  check(
    restored.stamps.first.traces.first.state == ExpeditionTraceState.recorded,
    'Recorded milestones are recovered from old saves',
  );
  check(
    journal.weeklyActions == 5,
    'Last seven calendar days preserve action counts',
  );
  check(
    journal.recentDays.first.date == DateTime(2026, 10, 7) &&
        journal.recentDays.last.date == now,
    'Seven-day journal includes today',
  );
  check(
    journal.badges.firstWhere((badge) => badge.id == 'companion').earned,
    'Starter ownership alone is distinct from a rescued companion',
  );
  final starterOnly = service.journal(
    snapshot.copyWith(unlockedCharacterIds: const ['CHAR_D', 'UNKNOWN']),
    initialCampaign,
    gardenDefinitions,
    now: now,
  );
  check(
    !starterOnly.badges.firstWhere((badge) => badge.id == 'companion').earned,
    'Unknown retained character IDs do not award a companion badge',
  );
  final locked = service.journal(
    fresh.copyWith(
      unlockedStageIds: initialCampaign.stages
          .where((stage) => stage.isPlayable)
          .map((stage) => stage.id),
    ),
    initialCampaign,
    gardenDefinitions,
    now: now,
  );
  check(
    locked.stamps
        .where((stamp) => stamp.regionId == 'region-02-pattern')
        .every((stamp) => !stamp.canExplore),
    'Raw future unlock IDs cannot bypass gates',
  );

  for (var repeat = 0; repeat < 20; repeat++) {
    service.memorySeeds(snapshot, initialCampaign, now: now);
    service.journal(snapshot, initialCampaign, gardenDefinitions, now: now);
  }
  check(
    jsonEncode(snapshot.toJson()) == before,
    'Browsing cannot mutate progress, tickets, saves or reward ledger',
  );
  check(
    jsonEncode(SaveEnvelopeV1.fromJson(snapshot.toJson()).toJson()) == before,
    'Existing save schema and records survive round-trip unchanged',
  );

  check(
    IntroMotionTimeline.logo(400) > 0 && IntroMotionTimeline.title(400) == 0,
    'Logo precedes the legacy-style title',
  );
  check(
    IntroMotionTimeline.tagline(1000) > 0 &&
        IntroMotionTimeline.status(1000) == 0,
    'Caption precedes status prompt',
  );
  for (var time = 0; time <= 4000; time += 25) {
    for (final value in [
      IntroMotionTimeline.logo(time.toDouble()),
      IntroMotionTimeline.title(time.toDouble()),
      IntroMotionTimeline.tagline(time.toDouble()),
      IntroMotionTimeline.status(time.toDouble()),
      IntroMotionTimeline.promptBrightness(time.toDouble()),
    ]) {
      check(value >= 0 && value <= 1, 'Intro opacity stays within bounds');
    }
  }
  check(
    IntroMotionTimeline.status(2200) == 1 &&
        IntroMotionTimeline.promptBrightness(2200) == 1,
    'The finite sequence completes within the existing startup hold',
  );
  stdout.writeln(
    'PASS: adventure collections, cosmetic/learning separation, save preservation, '
    'R2 gates, review-date petals, passport stamps and finite intro timeline.',
  );
}
