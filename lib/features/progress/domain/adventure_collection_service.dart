import '../../campaign/domain/campaign_models.dart';
import '../../campaign/domain/learning_models.dart';
import '../../garden/domain/garden_models.dart';
import 'campaign_access_policy.dart';
import 'daily_route_service.dart';
import 'progress_models.dart';

class MemorySeed {
  const MemorySeed({
    required this.skillId,
    required this.label,
    required this.completedVariations,
    required this.mastery,
  });
  final String skillId;
  final String label;
  final int completedVariations;
  final SkillMasteryState mastery;

  /// Cosmetic growth from cleared variants, NOT a mastery judgement. Assisted
  /// clears grow too; only the existing learning engine decides retention.
  int get growth => completedVariations.clamp(1, 3);
  String get growthLabel => switch (growth) {
    1 => '새싹',
    2 => '꽃봉오리',
    _ => '기억꽃',
  };
}

class MemorySeedCollection {
  MemorySeedCollection({
    required this.daily,
    required Iterable<MemorySeed> seeds,
    required this.reviewDays,
    required this.hasActiveReview,
  }) : seeds = List.unmodifiable(seeds);
  final DailyRouteRecommendations daily;
  final List<MemorySeed> seeds;
  final int reviewDays;
  final bool hasActiveReview;
  int get bouquets => reviewDays ~/ 5;
  int get nextBouquetProgress => reviewDays % 5;
}

enum ExpeditionTraceState { hidden, discovered, recorded }

class ExpeditionTrace {
  const ExpeditionTrace({required this.node, required this.state});
  final RestorationNode node;
  final ExpeditionTraceState state;
}

class ExpeditionStamp {
  ExpeditionStamp({
    required this.regionId,
    required this.regionTitle,
    required this.chapter,
    required this.completedStages,
    required this.playableStages,
    required this.canExplore,
    required Iterable<ExpeditionTrace> traces,
  }) : traces = List.unmodifiable(traces);
  final String regionId;
  final String regionTitle;
  final ChapterDefinition chapter;
  final int completedStages;
  final int playableStages;
  final bool canExplore;
  final List<ExpeditionTrace> traces;

  // An incomplete content tranche never awards a chapter-completion stamp.
  bool get stamped =>
      completedStages == chapter.stages.length &&
      playableStages == chapter.stages.length;
}

class ExpeditionDay {
  const ExpeditionDay(this.date, this.actions, this.reviews);
  final DateTime date;
  final int actions;
  final int reviews;
}

class ExpeditionBadge {
  const ExpeditionBadge(this.id, this.title, this.requirement, this.earned);
  final String id;
  final String title;
  final String requirement;
  final bool earned;
}

class ExpeditionJournal {
  ExpeditionJournal({
    required Iterable<ExpeditionStamp> stamps,
    required Iterable<ExpeditionDay> recentDays,
    required Iterable<ExpeditionBadge> badges,
  }) : stamps = List.unmodifiable(stamps),
       recentDays = List.unmodifiable(recentDays),
       badges = List.unmodifiable(badges);
  final List<ExpeditionStamp> stamps;
  final List<ExpeditionDay> recentDays;
  final List<ExpeditionBadge> badges;
  int get weeklyActions =>
      recentDays.fold(0, (total, day) => total + day.actions);
}

/// Read-only collections reconstructed from existing saves. Browsing, a new
/// day, or collecting a cosmetic badge never writes learning evidence, spends
/// stars, issues rewards, resets a streak, or consumes a review ticket.
class AdventureCollectionService {
  const AdventureCollectionService();

  MemorySeedCollection memorySeeds(
    SaveEnvelopeV1 save,
    CampaignDefinition campaign, {
    required DateTime now,
  }) {
    final concepts = <String, List<StageDefinition>>{};
    for (final stage in campaign.stages) {
      if (stage.isPlayable && save.completedStageIds.contains(stage.id)) {
        concepts
            .putIfAbsent(stage.learningPlan.primarySkillId, () => [])
            .add(stage);
      }
    }
    final daily = const DailyRouteService().build(save, campaign, now: now);
    final seeds = [
      for (final entry in concepts.entries)
        MemorySeed(
          skillId: entry.key,
          label: entry.value.first.conceptLabel,
          completedVariations: entry.value.length,
          mastery: save.masteryStates[entry.key] ?? SkillMasteryState.learning,
        ),
    ];
    // The ready seed is surfaced without changing the scheduler's choice.
    final todaySkill = daily.reviewStage?.learningPlan.primarySkillId;
    seeds.sort((a, b) {
      if (a.skillId == todaySkill && b.skillId != todaySkill) return -1;
      if (b.skillId == todaySkill && a.skillId != todaySkill) return 1;
      return a.skillId.compareTo(b.skillId);
    });
    return MemorySeedCollection(
      daily: daily,
      seeds: seeds,
      reviewDays: _reviewDays(save, now),
      hasActiveReview: save.activeSession?['isDailyReview'] == true,
    );
  }

  ExpeditionJournal journal(
    SaveEnvelopeV1 save,
    CampaignDefinition campaign,
    Iterable<GardenDefinition> gardens, {
    required DateTime now,
  }) {
    final earnedNodeIds = {
      for (final receipt in save.rewardLedger.values)
        ...receipt.unlockedRestorationNodeIds,
    };
    final nodes = {for (final garden in gardens) garden.regionId: garden};
    final stamps = <ExpeditionStamp>[];
    for (final region in campaign.regions) {
      for (final chapter in region.chapters) {
        final playable = chapter.stages.where((stage) => stage.isPlayable);
        if (playable.isEmpty) continue;
        stamps.add(
          ExpeditionStamp(
            regionId: region.id,
            regionTitle: region.title,
            chapter: chapter,
            completedStages: playable
                .where((stage) => save.completedStageIds.contains(stage.id))
                .length,
            playableStages: playable.length,
            canExplore: playable.any(
              (stage) =>
                  save.unlockedStageIds.contains(stage.id) &&
                  const CampaignAccessPolicy().canEnterStage(
                    stage,
                    campaign,
                    save.completedStageIds,
                  ),
            ),
            traces: [
              for (final node
                  in nodes[region.id]?.restorationNodes ?? <RestorationNode>[])
                if (node.chapterId == chapter.id)
                  ExpeditionTrace(
                    node: node,
                    state: save.restoredNodeIds.contains(node.id)
                        ? ExpeditionTraceState.recorded
                        : earnedNodeIds.contains(node.id)
                        ? ExpeditionTraceState.discovered
                        : ExpeditionTraceState.hidden,
                  ),
            ],
          ),
        );
      }
    }
    final date = now.toLocal();
    final starter = save.starterCharacterId ?? save.playerCharacterId;
    final knownCompanions = {
      for (final region in campaign.regions) ...region.featuredCharacterIds,
    };
    return ExpeditionJournal(
      stamps: stamps,
      recentDays: [
        for (var offset = 6; offset >= 0; offset--)
          _day(save, DateTime(date.year, date.month, date.day - offset)),
      ],
      badges: [
        ExpeditionBadge(
          'first-step',
          '첫 발자국',
          '스테이지 1개 완료',
          stamps.any((stamp) => stamp.completedStages > 0),
        ),
        ExpeditionBadge(
          'chapter',
          '길 개척자',
          '챕터 1개 완료',
          stamps.any((stamp) => stamp.stamped),
        ),
        ExpeditionBadge(
          'seed',
          '기억꽃 수집가',
          '날짜를 달리해 복습 5번',
          _reviewDays(save, now) >= 5,
        ),
        ExpeditionBadge(
          'trace',
          '흔적 발견자',
          '발견한 이정표 1개 기록',
          stamps.any(
            (stamp) => stamp.traces.any(
              (trace) => trace.state == ExpeditionTraceState.recorded,
            ),
          ),
        ),
        ExpeditionBadge(
          'companion',
          '함께 걷는 길',
          '새 동료 1명과 합류',
          save.unlockedCharacterIds.any(
            (id) => id != starter && knownCompanions.contains(id),
          ),
        ),
      ],
    );
  }

  int _reviewDays(SaveEnvelopeV1 save, DateTime now) {
    final today = localDateKey(now);
    return save.dailyReviewActions.entries
        .where((entry) => entry.value > 0 && entry.key.compareTo(today) <= 0)
        .length;
  }

  ExpeditionDay _day(SaveEnvelopeV1 save, DateTime date) {
    final key = localDateKey(date);
    return ExpeditionDay(
      date,
      save.dailyActions[key] ?? 0,
      save.dailyReviewActions[key] ?? 0,
    );
  }
}
