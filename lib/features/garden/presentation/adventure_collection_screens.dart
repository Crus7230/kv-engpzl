import 'package:flutter/material.dart';

import '../../campaign/domain/learning_models.dart';
import '../../exploration/data/r1_expedition_catalog.dart';
import '../../progress/domain/adventure_collection_service.dart';
import '../../progress/domain/daily_route_service.dart';
import 'collection_storybook_art.dart';
import 'garden_scene.dart';

class MemorySeedsScreen extends StatefulWidget {
  const MemorySeedsScreen({
    required this.collection,
    required this.onBack,
    required this.onReview,
    required this.onExplore,
    this.initialSkillId,
    super.key,
  });
  final MemorySeedCollection collection;
  final VoidCallback onBack;
  final VoidCallback? onReview;
  final VoidCallback? onExplore;
  final String? initialSkillId;
  @override
  State<MemorySeedsScreen> createState() => _MemorySeedsScreenState();
}

class _MemorySeedsScreenState extends State<MemorySeedsScreen> {
  String? _selectedSkill;
  @override
  void initState() {
    super.initState();
    _selectedSkill = widget.initialSkillId;
  }

  @override
  Widget build(BuildContext context) {
    final collection = widget.collection;
    final daily = collection.daily;
    final compact = MediaQuery.sizeOf(context).height < 340;
    final selected =
        collection.seeds
            .where((seed) => seed.skillId == _selectedSkill)
            .firstOrNull ??
        collection.seeds.firstOrNull;
    final reviewLabel = collection.hasActiveReview
        ? '풀던 씨앗 이어가기'
        : daily.reviewCompletedToday
        ? '오늘의 씨앗을 깨웠어요'
        : daily.reviewStage != null
        ? '오늘의 씨앗 깨우기'
        : '탐험에서 씨앗을 찾아요';
    return _CollectionFrame(
      title: '기억의 씨앗 · 기억꽃 모으기',
      onBack: widget.onBack,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: _PaperPanel(
              child: SingleChildScrollView(
                key: const ValueKey('memory-seed-detail'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reviewLabel, style: _heading(context)),
                    const SizedBox(height: 6),
                    Text(
                      daily.reviewStage != null
                          ? '${daily.reviewStage!.conceptLabel}\n${daily.reviewKind == DailyReviewKind.dueReview ? '다른 단서에서 같은 관계를 다시 찾아요.' : '익숙한 개념을 다시 꺼내 보는 오늘의 한 문제예요.'}'
                          : daily.reviewCompletedToday
                          ? '꽃잎 한 장을 남겼어요. 더 하고 싶다면 새로운 탐험으로 이어가요.'
                          : '오늘 배운 개념은 다음 날 다시 만나요. 도래한 복습이 먼저 추천됩니다.',
                      style: _body,
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      key: const ValueKey('memory-seed-play'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: GardenColors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: widget.onReview ?? widget.onExplore,
                      icon: Icon(
                        widget.onReview == null
                            ? Icons.explore_outlined
                            : Icons.spa_outlined,
                      ),
                      label: Text(
                        widget.onReview != null
                            ? collection.hasActiveReview
                                  ? '복습 이어가기'
                                  : '씨앗 깨우기'
                            : daily.reviewCompletedToday
                            ? '다음 탐험으로'
                            : '탐험 시작',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '나만의 기억꽃 다발 ${collection.bouquets}개',
                      style: _heading(context),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '다음 다발 ${collection.nextBouquetProgress}/5장',
                      style: _body,
                    ),
                    SizedBox(
                      height: 44,
                      child: PetalGarlandArt(
                        petals: collection.nextBouquetProgress,
                        bouquets: collection.bouquets,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '복습한 날마다 꽃잎 1장 · 총 ${collection.reviewDays}일\n'
                      '5장이 모이면 다발이 늘어요. 쉬는 날에도 모은 꽃잎은 남아요.',
                      style: _body,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: _PaperPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '개념 씨앗 ${collection.seeds.length}종',
                    style: _heading(context),
                  ),
                  if (selected != null)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4E5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: GardenColors.border),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: compact ? 76 : 116,
                            height: compact ? 62 : 90,
                            child: SeedGardenArt(
                              seedId: selected.skillId,
                              growth: selected.growth,
                              ready:
                                  selected.skillId ==
                                  daily
                                      .reviewStage
                                      ?.learningPlan
                                      .primarySkillId,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${selected.label} · ${selected.growthLabel}',
                                  style: _body.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '풀이 ${selected.completedVariations}종 · ${_masteryLabel(selected.mastery)}',
                                  style: const TextStyle(
                                    color: GardenColors.muted,
                                    fontSize: 11,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: collection.seeds.isEmpty
                        ? const Center(
                            child: Text(
                              '첫 문제를 풀면\n이곳에 개념 씨앗이 생겨요.',
                              textAlign: TextAlign.center,
                              style: _body,
                            ),
                          )
                        : ListView.separated(
                            key: const ValueKey('memory-seed-collection'),
                            itemCount: collection.seeds.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 5),
                            itemBuilder: (context, index) {
                              final seed = collection.seeds[index];
                              final ready =
                                  seed.skillId ==
                                  daily
                                      .reviewStage
                                      ?.learningPlan
                                      .primarySkillId;
                              return _CollectionTile(
                                key: ValueKey('memory-seed-${seed.skillId}'),
                                selected: seed.skillId == selected?.skillId,
                                onTap: () => setState(
                                  () => _selectedSkill = seed.skillId,
                                ),
                                leading: SizedBox(
                                  width: 38,
                                  height: 38,
                                  child: SeedSticker(
                                    growth: seed.growth,
                                    ready: ready,
                                  ),
                                ),
                                title: seed.label,
                                subtitle: ready ? '오늘 깨울 씨앗' : seed.growthLabel,
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '꽃 모양은 풀이 수집 기록이며, 숙련도 판정과는 별개예요.',
                    style: TextStyle(color: GardenColors.muted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExpeditionTracesScreen extends StatefulWidget {
  const ExpeditionTracesScreen({
    required this.journal,
    required this.onBack,
    required this.onRegion,
    required this.onRestore,
    required this.onCompanions,
    super.key,
  });
  final ExpeditionJournal journal;
  final VoidCallback onBack;
  final ValueChanged<String> onRegion;
  final ValueChanged<String> onRestore;
  final VoidCallback onCompanions;
  @override
  State<ExpeditionTracesScreen> createState() => _ExpeditionTracesScreenState();
}

class _ExpeditionTracesScreenState extends State<ExpeditionTracesScreen> {
  String? _chapterId;
  @override
  Widget build(BuildContext context) {
    final journal = widget.journal;
    final compact = MediaQuery.sizeOf(context).height < 340;
    final selected =
        journal.stamps
            .where((stamp) => stamp.chapter.id == _chapterId)
            .firstOrNull ??
        journal.stamps
            .where((stamp) => stamp.canExplore && !stamp.stamped)
            .firstOrNull ??
        journal.stamps.firstOrNull;
    return _CollectionFrame(
      title: '탐험의 흔적 · 나의 탐험 여권',
      passport: true,
      onBack: widget.onBack,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: _PaperPanel(
              passport: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '챕터 도장 ${journal.stamps.where((s) => s.stamped).length}개',
                    style: _heading(context),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      key: const ValueKey('expedition-passport'),
                      itemCount: journal.stamps.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 5),
                      itemBuilder: (context, index) {
                        final stamp = journal.stamps[index];
                        return _CollectionTile(
                          key: ValueKey('passport-${stamp.chapter.id}'),
                          selected: stamp == selected,
                          onTap: () =>
                              setState(() => _chapterId = stamp.chapter.id),
                          leading: SizedBox(
                            width: 46,
                            height: 46,
                            child: ChapterStampArt(
                              chapter: stamp.chapter.number,
                              region: expeditionRegionNumber(stamp.regionId),
                              earned: stamp.stamped,
                              available: stamp.canExplore,
                            ),
                          ),
                          title:
                              '${stamp.regionTitle} · C${stamp.chapter.number.toString().padLeft(2, '0')}',
                          subtitle:
                              '${stamp.completedStages}/${stamp.playableStages}개 완료'
                              '${stamp.stamped ? ' · 도장 획득' : ''}',
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '최근 7일 ${journal.weeklyActions}번의 발걸음 · 목표 5번',
                    style: _body,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (final day in journal.recentDays)
                        Expanded(
                          child: Semantics(
                            label:
                                '${day.date.month}월 ${day.date.day}일 '
                                '${day.actions}번 완료, 복습 ${day.reviews}번',
                            child: Column(
                              children: [
                                Container(
                                  width: 23,
                                  height: 23,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: day.actions > 0
                                        ? const Color(0xFFF4E5BB)
                                        : GardenColors.cream,
                                    border: Border.all(
                                      color: GardenColors.border,
                                    ),
                                  ),
                                  child: Icon(
                                    day.actions > 0
                                        ? Icons.pets
                                        : Icons.more_horiz,
                                    color: day.reviews > 0
                                        ? GardenColors.green
                                        : day.actions > 0
                                        ? const Color(0xFFAF8044)
                                        : GardenColors.border,
                                    size: 14,
                                  ),
                                ),
                                Text(
                                  '${day.date.day}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: _PaperPanel(
              passport: true,
              child: SingleChildScrollView(
                key: const ValueKey('expedition-stamp-detail'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selected != null) ...[
                      Text(selected.chapter.title, style: _heading(context)),
                      const SizedBox(height: 5),
                      Text(selected.chapter.description, style: _body),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: compact ? 64 : 88,
                        child: PassportMapArt(
                          chapterId: selected.chapter.id,
                          chapter: selected.chapter.number,
                          region: expeditionRegionNumber(selected.regionId),
                          completed: selected.completedStages,
                          total: selected.playableStages,
                          earned: selected.stamped,
                          discovered: [
                            for (final trace in selected.traces)
                              trace.state != ExpeditionTraceState.hidden,
                          ],
                          recorded: [
                            for (final trace in selected.traces)
                              trace.state == ExpeditionTraceState.recorded,
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final trace in selected.traces)
                        ListTile(
                          key: ValueKey('trace-${trace.node.id}'),
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(switch (trace.state) {
                            ExpeditionTraceState.hidden => Icons.lock_outline,
                            ExpeditionTraceState.discovered =>
                              Icons.add_location_alt_outlined,
                            ExpeditionTraceState.recorded =>
                              Icons.place_outlined,
                          }),
                          title: Text(
                            expeditionMilestoneTitle(trace.node),
                            style: _body,
                          ),
                          subtitle: Text(switch (trace.state) {
                            ExpeditionTraceState.hidden =>
                              'S${trace.node.milestone.toString().padLeft(2, '0')}에서 발견',
                            ExpeditionTraceState.discovered => '발견 완료 · 표식 남기기',
                            ExpeditionTraceState.recorded =>
                              '여권에 기록됨 · 모습 다시 고르기',
                          }, style: const TextStyle(fontSize: 11)),
                          onTap: trace.state == ExpeditionTraceState.hidden
                              ? null
                              : () => widget.onRestore(trace.node.id),
                        ),
                      OutlinedButton.icon(
                        key: const ValueKey('passport-explore'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: selected.canExplore
                            ? () => widget.onRegion(selected.regionId)
                            : null,
                        icon: const Icon(Icons.explore_outlined),
                        label: Text(
                          selected.canExplore ? '이 지역 탐험하기' : '앞 지역의 길을 먼저 열어요',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text('모험 배지', style: _heading(context)),
                    const SizedBox(height: 5),
                    for (final badge in journal.badges)
                      Container(
                        key: ValueKey('expedition-badge-${badge.id}'),
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: badge.earned
                              ? const Color(0xFFFFF1CB)
                              : const Color(0xFFF1F2E8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: badge.earned
                                ? const Color(0xFFE5C980)
                                : GardenColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 42,
                              height: 42,
                              child: CollectionBadgeArt(
                                earned: badge.earned,
                                icon: switch (badge.id) {
                                  'first-step' => Icons.pets,
                                  'chapter' => Icons.explore_outlined,
                                  'seed' => Icons.local_florist_outlined,
                                  'trace' => Icons.flag_outlined,
                                  _ => Icons.groups_outlined,
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    badge.title,
                                    style: _body.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    badge.earned
                                        ? '획득 완료 · ${badge.requirement}'
                                        : badge.requirement,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextButton.icon(
                      key: const ValueKey('passport-companions'),
                      onPressed: widget.onCompanions,
                      icon: const Icon(Icons.groups_outlined),
                      label: const Text('함께 걷는 동료와 합류 이야기'),
                    ),
                    const Text(
                      '도장과 배지는 기록이에요. 별을 쓰거나 연속 출석을 요구하지 않아요.',
                      style: _body,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _body = TextStyle(color: GardenColors.ink, fontSize: 12, height: 1.4);
TextStyle _heading(BuildContext context) => const TextStyle(
  color: GardenColors.ink,
  fontSize: 15,
  fontWeight: FontWeight.w700,
);

String _masteryLabel(SkillMasteryState mastery) => switch (mastery) {
  SkillMasteryState.unseen || SkillMasteryState.learning => '학습 중',
  SkillMasteryState.provisionalMastery => '다음 복습을 기다려요',
  SkillMasteryState.reviewDue => '복습할 개념',
  SkillMasteryState.mastered => '지연 복습 확인',
};

class _CollectionFrame extends StatelessWidget {
  const _CollectionFrame({
    required this.title,
    required this.onBack,
    required this.child,
    this.passport = false,
  });
  final String title;
  final VoidCallback onBack;
  final Widget child;
  final bool passport;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: passport
        ? const Color(0xFFEDE4D0)
        : const Color(0xFFEBF0DF),
    body: SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  tooltip: '모험 지도로 돌아가기',
                  icon: const Icon(Icons.arrow_back),
                ),
                Icon(
                  passport ? Icons.auto_stories_outlined : Icons.local_florist,
                  size: 19,
                  color: passport
                      ? const Color(0xFFAC7E4D)
                      : GardenColors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _heading(context),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: child,
            ),
          ),
        ],
      ),
    ),
  );
}

class _PaperPanel extends StatelessWidget {
  const _PaperPanel({required this.child, this.passport = false});
  final Widget child;
  final bool passport;
  @override
  Widget build(BuildContext context) => Material(
    color: GardenColors.paper,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: GardenColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: CustomPaint(
      painter: CollectionPaperPainter(passport: passport),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    ),
  );
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.selected,
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
    super.key,
  });
  final bool selected;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFFE8EEDC) : GardenColors.cream,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: selected ? GardenColors.moss : GardenColors.border,
      ),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Semantics(
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _body,
                      ),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: GardenColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.chevron_right,
                  size: 17,
                  color: selected ? GardenColors.green : GardenColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
