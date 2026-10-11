import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../campaign/domain/campaign_models.dart';
import '../../companions/data/companion_catalog.dart';
import '../../companions/presentation/companion_screens.dart';
import '../data/r1_expedition_catalog.dart';

const _ink = Color(0xFF183F40);
const _muted = Color(0xFF607374);
const _teal = Color(0xFF256D66);
const _paper = Color(0xFFFFFCF1);
const _gold = Color(0xFFF6CE72);

/// An illustrated trail, not a second progression authority. All selectable
/// nodes use the existing authored-stage and prerequisite checks supplied by
/// the application; viewing a future destination never unlocks it.
class R1ExpeditionScreen extends StatefulWidget {
  const R1ExpeditionScreen({
    required this.stages,
    required this.completedStageIds,
    required this.unlockedStageIds,
    required this.restoredNodeIds,
    required this.decorationChoices,
    required this.onBack,
    required this.onSelectStage,
    required this.onPlay,
    required this.onRestore,
    required this.hasActiveSession,
    required this.canRestore,
    this.nextStageId,
    this.canEnterStage,
    this.onStories,
    this.onCompanions,
    this.playerCharacterId,
    this.unlockedCharacterIds = const {'CHAR_D', 'CHAR_J'},
    super.key,
  });

  final List<StageDefinition> stages;
  final Set<String> completedStageIds;
  final Set<String> unlockedStageIds;
  final Set<String> restoredNodeIds;
  final Map<String, String> decorationChoices;
  final VoidCallback onBack, onRestore;
  final VoidCallback? onPlay;
  final ValueChanged<String> onSelectStage;
  final bool hasActiveSession, canRestore;
  final String? nextStageId;
  final bool Function(StageDefinition)? canEnterStage;
  final VoidCallback? onStories, onCompanions;
  final Set<String> unlockedCharacterIds;
  final String? playerCharacterId;

  @override
  State<R1ExpeditionScreen> createState() => _R1ExpeditionScreenState();
}

class _R1ExpeditionScreenState extends State<R1ExpeditionScreen> {
  int _chapter = 1;
  bool _overview = false;

  @override
  void initState() {
    super.initState();
    _followNextStage();
  }

  @override
  void didUpdateWidget(covariant R1ExpeditionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.nextStageId != oldWidget.nextStageId) _followNextStage();
  }

  void _followNextStage() {
    for (final stage in widget.stages) {
      if (stage.id == widget.nextStageId) {
        _chapter = int.tryParse(stage.chapterId.split('-c').last) ?? 1;
        return;
      }
    }
  }

  bool _canEnter(StageDefinition stage) =>
      stage.isPlayable &&
      widget.unlockedStageIds.contains(stage.id) &&
      (widget.canEnterStage?.call(stage) ?? true);

  @override
  Widget build(BuildContext context) {
    final destination = expeditionDestinationForChapter(_chapter);
    final player = companionProfileById(widget.playerCharacterId ?? '');
    final stages =
        widget.stages
            .where((stage) => stage.chapterId == destination.chapterId)
            .toList()
          ..sort((a, b) => a.number.compareTo(b.number));
    final completed = widget.stages
        .where((stage) => widget.completedStageIds.contains(stage.id))
        .length;
    final selectedCompleted = stages
        .where((stage) => widget.completedStageIds.contains(stage.id))
        .length;
    final milestones = widget.restoredNodeIds
        .where((id) => id.startsWith('${destination.chapterId}-garden-'))
        .length;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final canSeeChapter = stages.any(
      (stage) =>
          widget.completedStageIds.contains(stage.id) || _canEnter(stage),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF0F3E9),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 46,
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    tooltip: '탐험 지도에서 월드맵으로',
                    icon: const Icon(Icons.arrow_back_rounded, color: _ink),
                  ),
                  if (player != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Tooltip(
                        message: '내 탐험가 · ${player.letter} ${player.name}',
                        child: CompanionPortrait(
                          key: const ValueKey('expedition-player-portrait'),
                          profile: player,
                          size: 32,
                        ),
                      ),
                    ),
                  const Expanded(
                    child: Text(
                      '계산의 평원 · 탐험 지도',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Semantics(
                    label: '계산의 평원 탐험 $completed / ${widget.stages.length} 완료',
                    child: Text(
                      '$completed / ${widget.stages.length}',
                      style: const TextStyle(
                        color: _teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    key: const ValueKey('expedition-overview'),
                    tooltip: '평원 전체 지도',
                    onPressed: () => setState(() => _overview = !_overview),
                    icon: Icon(
                      _overview ? Icons.route_outlined : Icons.map_outlined,
                      size: 21,
                    ),
                  ),
                  if (widget.onStories != null)
                    IconButton(
                      tooltip: '탐험 이야기',
                      onPressed: widget.onStories,
                      icon: const Icon(Icons.auto_stories_outlined, size: 21),
                    ),
                  if (widget.onCompanions != null)
                    TextButton.icon(
                      key: const ValueKey('expedition-companions'),
                      onPressed: widget.onCompanions,
                      icon: const Icon(Icons.groups_2_outlined, size: 20),
                      label: Text(
                        '동료 ${widget.unlockedCharacterIds.length}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 5),
              child: SizedBox(
                height: 35,
                child: Row(
                  children: [
                    for (final entry in r1ExpeditionDestinations)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _DestinationTab(
                            destination: entry,
                            selected: _chapter == entry.number,
                            accessible: widget.stages.any(
                              (stage) =>
                                  stage.chapterId == entry.chapterId &&
                                  (_canEnter(stage) ||
                                      widget.completedStageIds.contains(
                                        stage.id,
                                      )),
                            ),
                            onTap: () => setState(() {
                              _chapter = entry.number;
                              _overview = false;
                            }),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 350),
                        child: SizedBox.expand(
                          key: ValueKey('scene-$_chapter-$_overview'),
                          child: ExpeditionBackdrop(
                            chapter: _overview ? null : _chapter,
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF102F32).withValues(alpha: .10),
                              const Color(0xFF102F32).withValues(alpha: .02),
                              const Color(0xFF102F32).withValues(alpha: .22),
                            ],
                          ),
                        ),
                      ),
                      if (!_overview && !canSeeChapter)
                        const IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xB8DFE6E1), Color(0xD9DDE8E5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (_overview) {
                            return _OverviewMap(
                              size: Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              ),
                              completedCounts: [
                                for (final entry in r1ExpeditionDestinations)
                                  widget.stages
                                      .where(
                                        (stage) =>
                                            stage.chapterId ==
                                                entry.chapterId &&
                                            widget.completedStageIds.contains(
                                              stage.id,
                                            ),
                                      )
                                      .length,
                              ],
                              accessible: [
                                for (final entry in r1ExpeditionDestinations)
                                  widget.stages.any(
                                    (stage) =>
                                        stage.chapterId == entry.chapterId &&
                                        (_canEnter(stage) ||
                                            widget.completedStageIds.contains(
                                              stage.id,
                                            )),
                                  ),
                              ],
                              onSelect: (chapter) => setState(() {
                                _chapter = chapter;
                                _overview = false;
                              }),
                            );
                          }
                          final points = expeditionTrailPoints(
                            Size(constraints.maxWidth, constraints.maxHeight),
                          );
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              CustomPaint(
                                painter: _ExpeditionTrailPainter(
                                  points: points,
                                  completed: [
                                    for (final stage in stages)
                                      widget.completedStageIds.contains(
                                        stage.id,
                                      ),
                                  ],
                                ),
                              ),
                              for (
                                var index = 0;
                                index < stages.length;
                                index++
                              )
                                Positioned(
                                  left: points[index].dx - 23,
                                  top: points[index].dy - 23,
                                  child: _StageTrailNode(
                                    stage: stages[index],
                                    completed: widget.completedStageIds
                                        .contains(stages[index].id),
                                    unlocked: _canEnter(stages[index]),
                                    current:
                                        stages[index].id == widget.nextStageId,
                                    onTap: _canEnter(stages[index])
                                        ? () => widget.onSelectStage(
                                            stages[index].id,
                                          )
                                        : null,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      Positioned(
                        top: 8,
                        left: 10,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _paper.withValues(alpha: .95),
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x20152D28),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              child: Text(
                                _overview
                                    ? '계산의 평원 · 여섯 탐험길'
                                    : '${destination.title}  ·  $selectedCompleted / ${stages.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!_overview && milestones > 0)
                        Positioned(
                          top: 9,
                          right: 10,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _teal.withValues(alpha: .94),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                '발견한 흔적 $milestones / 4',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 7, 10, 8),
              child: SizedBox(
                height: 49,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.hasActiveSession
                                ? '작성 중인 퍼즐에서 이어서 출발해요'
                                : completed == 60
                                ? '평원 탐험 완료 · 다음 지역 업데이트 예정'
                                : canSeeChapter
                                ? destination.description
                                : '안개 너머의 장소 · 앞 탐험의 단서를 모아 열어요',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _chapter == 4
                                ? '복습길은 각 원본 문제를 완료하면 열려요.'
                                : '챕터를 완성하며 알파벳 동료를 만나요.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.canRestore)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: OutlinedButton.icon(
                          key: const ValueKey('expedition-milestone'),
                          onPressed: widget.onRestore,
                          icon: const Icon(Icons.flag_outlined, size: 18),
                          label: const Text(
                            '탐험 흔적',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    FilledButton.icon(
                      key: const ValueKey('expedition-play'),
                      onPressed: widget.onPlay,
                      style: FilledButton.styleFrom(
                        backgroundColor: _teal,
                        minimumSize: const Size(130, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(Icons.near_me_outlined, size: 17),
                      label: Text(
                        widget.hasActiveSession
                            ? '이어서 탐험하기'
                            : widget.onPlay == null
                            ? '평원 탐험 완료'
                            : '다음 탐험',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Enhanced artwork is optional while loading or recovering the asset pack.
/// The legacy source image remains a valid fallback without changing saves.
class ExpeditionBackdrop extends StatelessWidget {
  const ExpeditionBackdrop({this.chapter, super.key});

  final int? chapter;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/expedition/r1-trail.png',
    fit: BoxFit.cover,
    alignment: switch (chapter) {
      1 => const Alignment(-.76, .44),
      2 => const Alignment(-.64, -.16),
      3 => const Alignment(-.14, -.14),
      4 => const Alignment(.36, .22),
      5 => const Alignment(.44, -.38),
      6 => const Alignment(.82, -.76),
      _ => Alignment.center,
    },
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) => Image.asset(
      'assets/legacy/plains.png',
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB8D8C8), Color(0xFFDAE2A8), Color(0xFF6E9C7C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    ),
  );
}

/// The same destination landmark is used in the trail and milestone reveal.
class ExpeditionEnvironmentArt extends StatelessWidget {
  const ExpeditionEnvironmentArt({
    required this.chapter,
    this.milestones = 0,
    this.decorationId,
    super.key,
  });

  final int chapter, milestones;
  final String? decorationId;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ExpeditionBackdrop(chapter: chapter),
      if (decorationId != null)
        Align(
          alignment: const Alignment(.64, .55),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _paper.withValues(alpha: .91),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Color(0x30314432), blurRadius: 10),
              ],
            ),
            child: Icon(
              switch (decorationId) {
                'stone-path' => Icons.signpost_outlined,
                'herbs' => Icons.cabin_outlined,
                _ => Icons.local_florist_outlined,
              },
              size: 28,
              color: _teal,
            ),
          ),
        ),
    ],
  );
}

/// A stage briefing depicts only the chosen explorer. Rescued companion
/// ownership is deliberately not inferred from the default legacy scene.
class ExpeditionTravelerScene extends StatelessWidget {
  const ExpeditionTravelerScene({
    required this.chapter,
    this.playerCharacterId,
    super.key,
  });

  final int chapter;
  final String? playerCharacterId;

  @override
  Widget build(BuildContext context) {
    final player = companionProfileById(playerCharacterId ?? '');
    final destination = expeditionDestinationForChapter(chapter);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            ExpeditionBackdrop(chapter: chapter),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00183F3B), Color(0xA6183F3B)],
                  stops: [.35, 1],
                ),
              ),
            ),
            if (player != null)
              Align(
                alignment: const Alignment(0, -.05),
                child: CompanionPortrait(
                  key: const ValueKey('briefing-player-portrait'),
                  profile: player,
                  size: math.min(
                    constraints.maxHeight * .66,
                    constraints.maxWidth * .65,
                  ),
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (player != null)
                    Text(
                      '${player.letter} · ${player.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: _ink, blurRadius: 6)],
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${destination.title}에서 관계를 찾아요',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFFE6AF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: _ink, blurRadius: 6)],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationTab extends StatelessWidget {
  const _DestinationTab({
    required this.destination,
    required this.selected,
    required this.accessible,
    required this.onTap,
  });

  final ExpeditionDestination destination;
  final bool selected, accessible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    label: '${destination.title}${accessible ? '' : ', 미탐험 장소'}',
    child: TextButton(
      key: ValueKey('expedition-chapter-${destination.number}'),
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: selected ? _teal : _paper,
        foregroundColor: selected ? Colors.white : _ink,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        minimumSize: const Size(0, 35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!accessible) ...[
            Icon(
              Icons.lock_outline_rounded,
              size: 11,
              color: selected ? Colors.white70 : _muted,
            ),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              destination.shortTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StageTrailNode extends StatelessWidget {
  const _StageTrailNode({
    required this.stage,
    required this.completed,
    required this.unlocked,
    required this.current,
    required this.onTap,
  });

  final StageDefinition stage;
  final bool completed, unlocked, current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: unlocked,
    label:
        'S${stage.number.toString().padLeft(2, '0')} ${stage.title}, '
        '${completed
            ? '완료'
            : unlocked
            ? '탐험 가능'
            : '잠김'}',
    child: Tooltip(
      message: unlocked
          ? '${stage.title} · ${stage.conceptLabel}'
          : stage.chapterId == 'r01-c04'
          ? '원본 문제를 완료하면 열려요'
          : '앞 탐험을 완료하면 열려요',
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          key: ValueKey('expedition-stage-${stage.id}'),
          onTap: onTap,
          radius: 28,
          containedInkWell: true,
          customBorder: const CircleBorder(),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completed
                  ? _teal
                  : current && unlocked
                  ? _gold
                  : unlocked
                  ? _paper
                  : const Color(0xFFD4DFD9),
              border: Border.all(
                color: completed ? const Color(0xFFC6E4CD) : Colors.white,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: current && unlocked
                      ? _gold.withValues(alpha: .5)
                      : const Color(0x40243E31),
                  offset: const Offset(0, 3),
                  blurRadius: current && unlocked ? 10 : 4,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!unlocked && !completed)
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 12,
                      color: _muted,
                    )
                  else if (completed)
                    const Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  Text(
                    '${stage.number}',
                    style: TextStyle(
                      color: completed ? Colors.white : _ink,
                      fontSize: 13,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _OverviewMap extends StatelessWidget {
  const _OverviewMap({
    required this.size,
    required this.completedCounts,
    required this.accessible,
    required this.onSelect,
  });

  final Size size;
  final List<int> completedCounts;
  final List<bool> accessible;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final points = expeditionDestinationPoints(size);
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _ExpeditionFogPainter(
            points: points,
            accessible: accessible,
          ),
        ),
        CustomPaint(
          painter: _ExpeditionTrailPainter(
            points: points,
            completed: [for (final count in completedCounts) count == 10],
          ),
        ),
        for (var index = 0; index < points.length; index++)
          Positioned(
            left: points[index].dx - 36,
            top: points[index].dy - 21,
            child: _DestinationMapNode(
              destination: r1ExpeditionDestinations[index],
              completed: completedCounts[index],
              accessible: accessible[index],
              onTap: () => onSelect(index + 1),
            ),
          ),
      ],
    );
  }
}

class _DestinationMapNode extends StatelessWidget {
  const _DestinationMapNode({
    required this.destination,
    required this.completed,
    required this.accessible,
    required this.onTap,
  });

  final ExpeditionDestination destination;
  final int completed;
  final bool accessible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${destination.title}, $completed / 10 완료, '
        '${accessible ? '탐험 가능' : '미탐험 장소 미리 보기'}',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('expedition-destination-${destination.number}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 72,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          decoration: BoxDecoration(
            color: completed == 10
                ? _teal
                : accessible
                ? _paper
                : const Color(0xFFE4ECE6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40183D35),
                blurRadius: 9,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                destination.shortTitle,
                maxLines: 1,
                style: TextStyle(
                  color: completed == 10 ? Colors.white : _ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                accessible ? '$completed / 10' : '안개 너머',
                maxLines: 1,
                style: TextStyle(
                  color: completed == 10 ? Colors.white70 : _muted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Positions correspond to the six landmarks in the expedition background.
/// Minimum margins protect the labels on a 680x300 landscape viewport.
List<Offset> expeditionDestinationPoints(Size size) => [
  for (final point in const [
    Offset(.12, .72),
    Offset(.18, .42),
    Offset(.43, .43),
    Offset(.68, .61),
    Offset(.72, .31),
    Offset(.91, .12),
  ])
    Offset(
      (point.dx * size.width).clamp(40, size.width - 40),
      (point.dy * size.height).clamp(46, size.height - 35),
    ),
];

/// Two winding rows keep all ten chapter stages visible on short landscape
/// screens. The points also drive the painted path and node hit areas.
List<Offset> expeditionTrailPoints(Size size) => [
  for (var i = 0; i < 5; i++)
    Offset(size.width * (.075 + i * .2125), size.height * .40),
  for (var i = 0; i < 5; i++)
    Offset(size.width * (.925 - i * .2125), size.height * .80),
];

class _ExpeditionTrailPainter extends CustomPainter {
  _ExpeditionTrailPainter({required this.points, required this.completed});

  final List<Offset> points;
  final List<bool> completed;

  @override
  void paint(Canvas canvas, Size size) {
    for (
      var index = 0;
      index < math.min(points.length, completed.length) - 1;
      index++
    ) {
      final path = Path()..moveTo(points[index].dx, points[index].dy);
      final next = points[index + 1];
      if (index == 4) {
        path.cubicTo(
          size.width * .98,
          points[index].dy,
          size.width * .98,
          next.dy,
          next.dx,
          next.dy,
        );
      } else {
        path.cubicTo(
          (points[index].dx + next.dx) / 2,
          points[index].dy - size.height * .07,
          (points[index].dx + next.dx) / 2,
          next.dy + size.height * .07,
          next.dx,
          next.dy,
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 11
          ..color = const Color(0xADFFF9E8),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 5
          ..color = completed[index]
              ? const Color(0xFFE2B85B)
              : const Color(0xB39BAC91),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ExpeditionTrailPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.completed != completed;
}

class _ExpeditionFogPainter extends CustomPainter {
  _ExpeditionFogPainter({required this.points, required this.accessible});

  final List<Offset> points;
  final List<bool> accessible;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.height * .54, size.width * .16);
    for (var index = 0; index < points.length; index++) {
      if (accessible[index]) continue;
      final bounds = Rect.fromCircle(center: points[index], radius: radius);
      canvas.drawOval(
        bounds,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xDDDDE8E4), Color(0xA6DFE8E2), Color(0x00DFE8E2)],
            stops: [0, .5, 1],
          ).createShader(bounds),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ExpeditionFogPainter oldDelegate) =>
      points != oldDelegate.points || accessible != oldDelegate.accessible;
}
