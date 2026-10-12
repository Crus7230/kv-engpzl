import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../campaign/data/legacy_region_catalog.dart';
import '../../campaign/domain/campaign_models.dart';
import '../../campaign/domain/board_mechanic_models.dart';
import '../../puzzle/domain/puzzle.dart';
import '../../exploration/presentation/r1_expedition_screen.dart';
import '../../exploration/presentation/expedition_milestone_screen.dart';
import '../data/garden_catalog.dart';
import '../domain/garden_models.dart';
import 'garden_scene.dart';

export 'garden_scene.dart';

class WorldMapScreen extends StatelessWidget {
  const WorldMapScreen({
    required this.unlockedRegionIds,
    required this.restoredNodeIds,
    required this.totalStars,
    required this.weeklyActions,
    required this.onExplore,
    required this.onSelectRegion,
    required this.onSettings,
    this.availableRegionIds = const {
      'region-01-calculation',
      'region-02-pattern',
    },
    this.onReview,
    this.onRestore,
    this.statusMessage,
    this.reviewDetail,
    this.explorationDetail,
    this.onCompanions,
    super.key,
  });

  final Set<String> unlockedRegionIds;
  final Set<String> availableRegionIds;
  final Set<String> restoredNodeIds;
  final int totalStars;
  final int weeklyActions;
  final VoidCallback? onExplore;
  final VoidCallback? onReview;
  final VoidCallback? onRestore;
  final ValueChanged<String> onSelectRegion;
  final VoidCallback onSettings;
  final String? statusMessage;
  final String? reviewDetail;
  final String? explorationDetail;
  final VoidCallback? onCompanions;

  @override
  Widget build(BuildContext context) => _GardenFrame(
    title: '일곱 수식 대륙 · 모험 지도',
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SmallStat(
          icon: Icons.star_rounded,
          label: '$totalStars',
          semanticsLabel: '모은 성취 별 $totalStars개',
        ),
        const SizedBox(width: 6),
        if (onCompanions != null)
          TextButton.icon(
            key: const ValueKey('world-companions'),
            onPressed: onCompanions,
            icon: const Icon(Icons.groups_2_outlined, size: 20),
            label: const Text('동료', style: TextStyle(fontSize: 12)),
          ),
        IconButton(
          onPressed: onSettings,
                    tooltip: '음악·효과음 및 접근성 설정',
          icon: const Icon(Icons.tune_rounded, size: 22),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        children: [
          if (statusMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
              child: Text(
                statusMessage!,
                style: const TextStyle(color: GardenColors.ink, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final largeText =
                    MediaQuery.textScalerOf(context).scale(13) > 15;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _WorldMap(
                      unlockedRegionIds: unlockedRegionIds,
                      availableRegionIds: availableRegionIds,
                      restoredNodeIds: restoredNodeIds,
                      onSelectRegion: onSelectRegion,
                      showGuide: statusMessage == null,
                      // Only very short safe areas need a separate control gutter.
                      bottomClearance: constraints.maxHeight < 240 ? 54 : 0,
                    ),
                    Positioned(
                      left: 6,
                      bottom: 4,
                      child: SizedBox(
                        width: math.min(
                          constraints.maxWidth - 12,
                          largeText ? 414 : 366,
                        ),
                        height: 48,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _WorldMapAction(
                                key: const ValueKey('world-review'),
                                icon: Icons.spa_outlined,
                                title: '기억의 씨앗',
                                detail:
                                    reviewDetail ??
                                    (onReview == null
                                        ? '복습은 준비 중이에요'
                                        : '오늘 돌아온 개념 1개'),
                                onTap: onReview,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _WorldMapAction(
                                key: const ValueKey('world-explore'),
                                icon: Icons.explore_outlined,
                                title: '오늘의 탐험',
                                detail: explorationDetail ?? '한 문제로 시작하기',
                                onTap: onExplore,
                                highlighted: true,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _WorldMapAction(
                                key: const ValueKey('world-traces'),
                                icon: onCompanions == null
                                    ? Icons.local_florist_outlined
                                    : Icons.signpost_outlined,
                                title: onCompanions == null
                                    ? '정원 돌보기'
                                    : '탐험의 흔적',
                                detail: onRestore != null
                                    ? onCompanions == null
                                          ? '화단에 새 모습을 골라요'
                                          : '이정표와 쉼터에 흔적 남기기'
                                    : '이번 주 ${math.min(weeklyActions, 5)}/5번의 발걸음',
                                onTap: onRestore,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class RegionGardenScreen extends StatelessWidget {
  const RegionGardenScreen({
    required this.regionId,
    required this.restoredNodeIds,
    required this.decorationChoices,
    required this.onBack,
    required this.onPlay,
    required this.onRestore,
    required this.canRestore,
    required this.hasActiveSession,
    required this.demoCompleted,
    super.key,
  });

  final String regionId;
  final Set<String> restoredNodeIds;
  final Map<String, String> decorationChoices;
  final VoidCallback onBack;
  final VoidCallback onPlay;
  final VoidCallback onRestore;
  final bool canRestore;
  final bool hasActiveSession;
  final bool demoCompleted;

  @override
  Widget build(BuildContext context) {
    final region = legacyRegionById(regionId);
    final isFirstRegion = region?.number == 1;
    final restored = restoredNodeIds.contains(demoRestorationNode.id);
    return _GardenFrame(
      title: region?.title ?? '정원',
      onBack: onBack,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 6,
              child: isFirstRegion
                  ? GardenScene(
                      restored: restored,
                      decorationId:
                          decorationChoices[demoRestorationNode.id] ??
                          'wildflowers',
                    )
                  : _UnopenedGarden(
                      regionTitle: region?.title ?? '새로운 지역',
                      description: region?.description ?? '',
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: _PaperPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Eyebrow(isFirstRegion ? '첫 번째 정원' : '업데이트 예정'),
                            const SizedBox(height: 6),
                            Text(
                              isFirstRegion ? '묶음 속에서\n작은 변화를 찾아요' : '업데이트 예정',
                              style: const TextStyle(
                                color: GardenColors.ink,
                                fontSize: 18,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (isFirstRegion) ...[
                              _PathEntry(
                                icon: demoCompleted
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.extension_outlined,
                                title: '묶음과 낱개',
                                detail: '개발용 체험 · 4 × 3 + 2',
                                active: true,
                              ),
                              const SizedBox(height: 8),
                              _PathEntry(
                                icon: restored
                                    ? Icons.local_florist_rounded
                                    : Icons.grass_outlined,
                                title: '첫 번째 화단',
                                detail: restored
                                    ? gardenDecorationLabel(
                                        decorationChoices[demoRestorationNode
                                                .id] ??
                                            'wildflowers',
                                      )
                                    : canRestore
                                    ? '복원할 준비가 되었어요'
                                    : '체험을 마치면 열려요',
                                active: restored || canRestore,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                '정식 캠페인 문제는 차례로 준비합니다. 체험 결과는 캠페인 진도에 포함되지 않아요.',
                                style: TextStyle(
                                  color: GardenColors.muted,
                                  fontSize: 12,
                                  height: 1.45,
                                ),
                              ),
                            ] else
                              const Text(
                                '이 지역은 향후 업데이트로 열립니다. 지금은 계산의 평원에서 탐험과 복습을 이어가 주세요.',
                                style: TextStyle(
                                  color: GardenColors.muted,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isFirstRegion) ...[
                      FilledButton.icon(
                        onPressed: onPlay,
                        icon: Icon(
                          hasActiveSession
                              ? Icons.play_arrow_rounded
                              : Icons.extension_outlined,
                          size: 18,
                        ),
                        label: Text(hasActiveSession ? '이어서 탐험하기' : '체험 탐험하기'),
                      ),
                      const SizedBox(height: 5),
                      OutlinedButton.icon(
                        onPressed: canRestore || restored ? onRestore : null,
                        icon: const Icon(
                          Icons.local_florist_outlined,
                          size: 18,
                        ),
                        label: Text(restored ? '정원 장식 바꾸기' : '화단 복원하기'),
                      ),
                    ] else
                      OutlinedButton(
                        onPressed: onBack,
                        child: const Text('월드맵으로'),
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

/// Lists only authored content; future 420-slot planning is not exposed here.
class CampaignRegionGardenScreen extends StatelessWidget {
  const CampaignRegionGardenScreen({
    this.regionNumber = 1,
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
  final int regionNumber;
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
  final VoidCallback? onStories;
  final VoidCallback? onCompanions;
  final String? playerCharacterId;
  final Set<String> unlockedCharacterIds;
  @override
  Widget build(BuildContext context) => R1ExpeditionScreen(
    regionNumber: regionNumber,
    stages: stages,
    completedStageIds: completedStageIds,
    unlockedStageIds: unlockedStageIds,
    restoredNodeIds: restoredNodeIds,
    decorationChoices: decorationChoices,
    nextStageId: nextStageId,
    unlockedCharacterIds: unlockedCharacterIds,
    playerCharacterId: playerCharacterId,
    canEnterStage: canEnterStage,
    onStories: onStories,
    onCompanions: onCompanions,
    onBack: onBack,
    onPlay: onPlay,
    onSelectStage: onSelectStage,
    onRestore: onRestore,
    canRestore: canRestore,
    hasActiveSession: hasActiveSession,
  );
}

String _briefingRegionTitle(StageDefinition stage) {
  final prefix = RegExp(r'^r(\d{2})-').firstMatch(stage.chapterId);
  final regionNumber = prefix == null ? null : int.tryParse(prefix.group(1)!);
  return legacyRegionCatalog
          .where((region) => region.number == regionNumber)
          .firstOrNull
          ?.title ??
      '수식 모험';
}

class StageBriefingScreen extends StatelessWidget {
  const StageBriefingScreen({
    required this.onBack,
    required this.onStart,
    required this.resume,
    this.stage,
    this.isReview = false,
    this.playerCharacterId,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onStart;
  final bool resume;
  final StageDefinition? stage;
  final bool isReview;
  final String? playerCharacterId;

  @override
  Widget build(BuildContext context) => _GardenFrame(
    title: stage?.title ?? '묶음과 낱개',
    onBack: onBack,
    child: _TwoPane(
      leading:
          stage != null &&
              (stage!.chapterId.startsWith('r01-') ||
                  stage!.chapterId.startsWith('r02-'))
          ? ExpeditionTravelerScene(
              regionNumber: int.parse(stage!.chapterId.substring(1, 3)),
              chapter: int.tryParse(stage!.chapterId.split('-c').last) ?? 1,
              playerCharacterId: playerCharacterId,
            )
          : GardenScene(
              restored: false,
              project: gardenDefinitions.first.sceneByChapterId(
                stage?.chapterId ?? '',
              ),
            ),
      content: _PaperPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Eyebrow(
                      stage == null
                          ? '개발용 체험'
                          : isReview
                          ? '기억의 씨앗 · 복습'
                          : '${_briefingRegionTitle(stage!)} · 탐험 준비',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      stage?.conceptLabel ?? '한 문제로\n첫 화단을 깨워요',
                      style: const TextStyle(
                        color: GardenColors.ink,
                        fontSize: 23,
                        height: 1.16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '보석 두 개를 바꾸어 3개 이상 연결하세요. 봉인 아래 숫자와 기호를 찾고, 문장의 관계를 식으로 만들어 보세요.',
                      style: TextStyle(
                        color: GardenColors.muted,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (stage != null)
                      Text(
                        stage!.learningPlan.objective,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    if (stage?.sentenceMathPlan != null)
                      _Note(
                        icon: Icons.schema_outlined,
                        text: stage!.sentenceMathPlan!.phaseGoal,
                      ),
                    if (stage?.boardMechanicPlan.mechanicIds.contains(
                          BoardMechanicId.layeredSeal,
                        ) ??
                        false)
                      const _Note(
                        icon: Icons.layers_outlined,
                        text: '2층 봉인은 같은 칸을 두 번 맞혀 열어요. 남은 층수는 보석에 표시됩니다.',
                      ),
                    if (stage?.boardMechanicPlan.mechanicIds.contains(
                          BoardMechanicId.linePower,
                        ) ??
                        false)
                      const _Note(
                        icon: Icons.swap_horiz_rounded,
                        text:
                            '같은 보석 4개를 연결하면 직선 파워가 생겨요. 옆 보석과 바꾸면 화살표 방향의 줄을 타격합니다.',
                      ),
                    if (stage?.boardMechanicPlan.bindings.any(
                          (b) =>
                              b.rule is LinePowerRule &&
                              (b.rule as LinePowerRule).enableBurst,
                        ) ??
                        false)
                      const _Note(
                        icon: Icons.flare_rounded,
                        text: 'L/T형 매치는 범위 폭발을 만들어요. 인접 교환으로 주변 3×3을 타격합니다.',
                      ),
                    if (stage?.boardMechanicPlan.bindings.any(
                          (b) =>
                              b.rule is LinePowerRule &&
                              (b.rule as LinePowerRule).enableColor,
                        ) ??
                        false)
                      const _Note(
                        icon: Icons.palette_rounded,
                        text: '한 줄 5개 매치는 색상 파워를 만들어요. 바꾼 보석과 같은 색을 모두 타격합니다.',
                      ),
                    if (stage?.boardMechanicPlan.bindings.any(
                          (b) =>
                              b.rule is LinePowerRule &&
                              (b.rule as LinePowerRule).enableCombinations,
                        ) ??
                        false)
                      const _Note(
                        icon: Icons.auto_awesome_rounded,
                        text:
                            '특수 블록끼리 바꾸면 조합 효과가 나와요. 직선끼리는 십자, 폭발끼리는 5×5, 색상과 다른 특수 블록은 같은 색을 변환합니다.',
                      ),
                    if (stage?.matchDifficulty.obstacleCount != null &&
                        stage!.matchDifficulty.obstacleCount > 0)
                      const _Note(
                        icon: Icons.terrain_rounded,
                        text: '장애물은 교환과 낙하를 막아요. 옆에서 매치하거나 특수 블록으로 타격해 제거하세요.',
                      ),
                    if (stage?.boardMechanicPlan.bindings.any(
                          (b) =>
                              b.rule is AdjacentHitBlockerRule &&
                              (b.rule as AdjacentHitBlockerRule).durability ==
                                  2,
                        ) ??
                        false)
                      const _Note(
                        icon: Icons.forest_outlined,
                        text: '단단한 덩굴은 두 번 타격해야 제거돼요. 같은 연쇄 단계에서는 한 번만 손상됩니다.',
                      ),
                    _Note(
                      icon: resume
                          ? Icons.bookmark_outline_rounded
                          : Icons.lightbulb_outline_rounded,
                      text: resume
                          ? '발굴한 조각과 작성 중인 식이 저장되어 있어요.'
                          : '힌트와 무료 재도전을 언제든 사용할 수 있어요.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(resume ? '이어서 탐험하기' : '탐험 시작하기'),
            ),
          ],
        ),
      ),
    ),
  );
}

class StageResultScreen extends StatefulWidget {
  const StageResultScreen({
    required this.stars,
    required this.firstCompletion,
    required this.onContinue,
    required this.onBack,
    this.puzzle,
    this.stage,
    this.continueLabel,
    this.hasRestoration = false,
    super.key,
  });

  final int stars;
  final bool firstCompletion;
  final VoidCallback onContinue;
  final VoidCallback onBack;
  final Puzzle? puzzle;
  final StageDefinition? stage;
  final String? continueLabel;
  final bool hasRestoration;

  @override
  State<StageResultScreen> createState() => _StageResultScreenState();
}

class _StageResultScreenState extends State<StageResultScreen> {
  bool _showTransferAnswer = false;

  @override
  Widget build(BuildContext context) => _GardenFrame(
    title: '관계를 발견했어요',
    onBack: widget.onBack,
    child: _TwoPane(
      leading: _PaperPanel(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 2),
              _Eyebrow(
                widget.stage == null
                    ? '묶음과 낱개 · 체험 완료'
                    : '${widget.stage!.conceptLabel} · 완료',
              ),
              const SizedBox(height: 10),
              Semantics(
                label: '성취 별 ${widget.stars}개',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var index = 0; index < 3; index += 1)
                      Icon(
                        index < widget.stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: index < widget.stars
                            ? GardenColors.gold
                            : GardenColors.border,
                        size: 36,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.stage == null
                    ? '4 × 3 + 2 = 14'
                    : '${widget.stage!.answerExpression} = ${widget.puzzle!.target}',
                style: const TextStyle(
                  color: GardenColors.ink,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (widget.puzzle != null) ...[
                for (final step
                    in widget.puzzle!.learningSupport!.workedSolutionSteps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: _ExplanationStep(
                      number:
                          '${widget.puzzle!.learningSupport!.workedSolutionSteps.indexOf(step) + 1}',
                      title: step.expression,
                      body: step.explanation,
                    ),
                  ),
              ] else ...[
                const _ExplanationStep(
                  number: '1',
                  title: '같은 크기의 묶음을 먼저 세어요',
                  body: '한 상자에 4자루씩, 상자가 3개이니 4 × 3 = 12예요.',
                ),
                const SizedBox(height: 7),
                const _ExplanationStep(
                  number: '2',
                  title: '낱개를 더해 전체를 구해요',
                  body: '묶음 밖의 2개를 더하면 12 + 2 = 14예요.',
                ),
              ],
            ],
          ),
        ),
      ),
      content: _PaperPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Note(
                      icon: Icons.local_florist_outlined,
                      text: widget.stage != null
                          ? widget.hasRestoration
                                ? '복원 지점이 열렸어요. 원하는 모습을 골라 주세요.'
                                : '오늘의 발걸음을 기록했어요. 다음 문제나 복습으로 이어갈 수 있어요.'
                          : widget.firstCompletion
                          ? '첫 화단을 복원할 수 있어요. 마음에 드는 모습을 골라 주세요.'
                          : '다시 풀어도 별은 중복 지급되지 않아요. 정원 장식은 무료로 바꿀 수 있어요.',
                    ),
                    const SizedBox(height: 12),
                    const _Eyebrow('다른 상황에도 적용해 볼까요?'),
                    const SizedBox(height: 8),
                    Text(
                      widget.puzzle?.learningSupport?.transferPrompt.question ??
                          '3개씩 든 봉지가 5개, 낱개가 1개라면 모두 몇 개일까요?',
                      style: const TextStyle(
                        color: GardenColors.ink,
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _showTransferAnswer = !_showTransferAnswer;
                      }),
                      child: Text(
                        _showTransferAnswer ? '풀이 접기' : '생각한 뒤 풀이 확인',
                      ),
                    ),
                    if (_showTransferAnswer)
                      Text(
                        widget
                                .puzzle
                                ?.learningSupport
                                ?.transferPrompt
                                .expectedExpression ??
                            '3 × 5 + 1 = 16\n묶음 수가 달라져도 곱셈 후 낱개를 더하는 관계는 같아요.',
                        style: const TextStyle(
                          color: GardenColors.green,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: widget.onContinue,
              icon: const Icon(Icons.local_florist_outlined, size: 18),
              label: Text(
                widget.continueLabel ??
                    (widget.firstCompletion ? '첫 화단 복원하기' : '정원으로 돌아가기'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class RestorationRevealScreen extends StatelessWidget {
  const RestorationRevealScreen({
    required this.alreadyRestored,
    required this.decorationId,
    required this.onChooseDecoration,
    required this.onFinish,
    this.nodeTitle,
    this.restoredNodeIds = const {},
    this.completedStageCount = 0,
    this.node,
    this.unlockedCharacterIds = const {'CHAR_D', 'CHAR_J'},
    super.key,
  });

  final bool alreadyRestored;
  final String decorationId;
  final ValueChanged<String> onChooseDecoration;
  final VoidCallback onFinish;
  final String? nodeTitle;
  final Set<String> restoredNodeIds;
  final int completedStageCount;
  final RestorationNode? node;
  final Set<String> unlockedCharacterIds;

  @override
  Widget build(BuildContext context) => node != null
      ? ExpeditionMilestoneScreen(
          alreadyRestored: alreadyRestored,
          decorationId: decorationId,
          onChooseDecoration: onChooseDecoration,
          onFinish: onFinish,
          nodeTitle: nodeTitle,
          restoredNodeIds: restoredNodeIds,
          completedStageCount: completedStageCount,
          node: node,
          unlockedCharacterIds: unlockedCharacterIds,
        )
      : _GardenFrame(
          title: alreadyRestored
              ? '정원에 새 모습을 골라요'
              : nodeTitle == null
              ? '첫 번째 화단을 복원해요'
              : '정원의 한 곳을 복원해요',
          child: _TwoPane(
            leading: GardenScene(
              restored: true,
              decorationId: decorationId,
              restoredNodeIds: restoredNodeIds,
              completedStageCount: completedStageCount,
              project: gardenDefinitions.first.sceneByChapterId(
                node?.chapterId ?? '',
              ),
              unlockedCharacterIds: unlockedCharacterIds,
            ),
            content: _PaperPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Eyebrow(nodeTitle ?? '첫 번째 들꽃 화단'),
                          const SizedBox(height: 8),
                          const Text(
                            '어떤 정원이 좋을까요?',
                            style: TextStyle(
                              color: GardenColors.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '장식은 언제든 무료로 바꿀 수 있어요.',
                            style: TextStyle(
                              color: GardenColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (final id in gardenDecorationIds)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: _DecorationOption(
                                id: id,
                                selected: decorationId == id,
                                onTap: () => onChooseDecoration(id),
                              ),
                            ),
                          const SizedBox(height: 7),
                          Text(
                            node?.storyText ??
                                (nodeTitle == null
                                    ? 'Delta: “묶음과 낱개를 찾으니 꽃이 돌아왔네!”\nJuliett: “다음에는 어떤 관계가 숨겨져 있을까?”'
                                    : 'Delta: “관계를 하나씩 찾으니 정원이 살아나네.”\nJuliett: “내일 다시 떠올리면 더 단단해질 거야.”'),
                            style: const TextStyle(
                              color: GardenColors.muted,
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  FilledButton.icon(
                    onPressed: onFinish,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(alreadyRestored ? '이 모습으로 꾸미기' : '이 모습으로 복원하기'),
                  ),
                ],
              ),
            ),
          ),
        );
}

class _GardenFrame extends StatelessWidget {
  const _GardenFrame({
    required this.title,
    required this.child,
    this.onBack,
    this.trailing,
  });

  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final originalTheme = Theme.of(context);
    return Theme(
      data: originalTheme.copyWith(
        colorScheme: originalTheme.colorScheme.copyWith(
          primary: GardenColors.green,
          onPrimary: Colors.white,
          surface: GardenColors.paper,
          onSurface: GardenColors.ink,
          outline: GardenColors.border,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(40, 40),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            backgroundColor: GardenColors.green,
            foregroundColor: Colors.white,
            textStyle: originalTheme.textTheme.labelLarge?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(40, 38),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            foregroundColor: GardenColors.green,
            side: const BorderSide(color: GardenColors.border),
            textStyle: originalTheme.textTheme.labelLarge?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: GardenColors.cream,
        body: SafeArea(
          minimum: const EdgeInsets.all(2),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      if (onBack != null)
                        IconButton(
                          onPressed: onBack,
                          tooltip: '이전 화면',
                          icon: const Icon(Icons.arrow_back_rounded, size: 21),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(left: 4, right: 9),
                          child: Icon(
                            Icons.spa_outlined,
                            size: 22,
                            color: GardenColors.green,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            color: GardenColors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _TwoPane extends StatelessWidget {
  const _TwoPane({required this.leading, required this.content});

  final Widget leading;
  final Widget content;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 5, child: leading),
        const SizedBox(width: 10),
        Expanded(flex: 5, child: content),
      ],
    ),
  );
}

class _PaperPanel extends StatelessWidget {
  const _PaperPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: GardenColors.paper,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: GardenColors.border),
    ),
    child: child,
  );
}

class _WorldMap extends StatelessWidget {
  const _WorldMap({
    required this.unlockedRegionIds,
    required this.availableRegionIds,
    required this.restoredNodeIds,
    required this.onSelectRegion,
    required this.showGuide,
    required this.bottomClearance,
  });

  final Set<String> unlockedRegionIds;
  final Set<String> availableRegionIds;
  final Set<String> restoredNodeIds;
  final ValueChanged<String> onSelectRegion;
  final bool showGuide;
  final double bottomClearance;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: ColoredBox(
      color: const Color(0xFFD6E3CD),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const sourceSize = Size(6000, 2413);
          final destination = Size(
            constraints.maxWidth,
            math.max(0, constraints.maxHeight - bottomClearance),
          );
          final fitted = applyBoxFit(BoxFit.contain, sourceSize, destination);
          final imageRect = Alignment.center.inscribe(
            fitted.destination,
            Offset.zero & destination,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: imageRect,
                child: Image.asset(
                  'assets/legacy/world-map.png',
                  key: const ValueKey('world-map-artwork'),
                  cacheWidth:
                      (imageRect.width * MediaQuery.devicePixelRatioOf(context))
                          .ceil()
                          .clamp(1, 6000),
                  fit: BoxFit.fill,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: Color(0xFFD6E3CD)),
                ),
              ),
              for (final region in legacyRegionCatalog)
                Positioned(
                  left:
                      imageRect.left +
                      imageRect.width * region.hotspot.centerX -
                      45,
                  top:
                      imageRect.top +
                      imageRect.height * region.hotspot.centerY -
                      30,
                  width: 90,
                  height: 68,
                  child: _MapMarker(
                    key: ValueKey('world-region-${region.id}'),
                    number: region.number,
                    title: _regionShortTitle(region.number),
                    fullTitle: region.title,
                    available: availableRegionIds.contains(region.id),
                    unlocked:
                        availableRegionIds.contains(region.id) &&
                        unlockedRegionIds.contains(region.id),
                    restored:
                        region.number == 1 &&
                        restoredNodeIds.contains(demoRestorationNode.id),
                    onTap: () => onSelectRegion(region.id),
                  ),
                ),
              if (showGuide)
                Positioned(
                  top: 6,
                  right: 9,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: GardenColors.paper.withValues(alpha: .88),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      child: Text(
                        '지역을 눌러 탐험을 시작하세요',
                        style: TextStyle(fontSize: 10, color: GardenColors.ink),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.number,
    required this.title,
    required this.fullTitle,
    required this.unlocked,
    required this.available,
    required this.restored,
    required this.onTap,
    super.key,
  });

  final int number;
  final String title;
  final String fullTitle;
  final bool unlocked;
  final bool available;
  final bool restored;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '$fullTitle, ${!available
            ? '업데이트 예정'
            : unlocked
            ? '탐험 가능'
            : '앞 지역 완료 필요'}, 지역 보기',
    child: Tooltip(
      message:
          '$fullTitle · ${!available
              ? '업데이트 예정'
              : unlocked
              ? '탐험 가능'
              : '앞 지역 완료 필요'}',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ExcludeSemantics(
            child: Column(
              children: [
                Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                    color: unlocked ? GardenColors.green : GardenColors.paper,
                    shape: BoxShape.circle,
                    border: Border.all(color: GardenColors.paper, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Color(0x33000000), blurRadius: 5),
                    ],
                  ),
                  child: Center(
                    child: unlocked
                        ? restored
                              ? const Icon(
                                  Icons.local_florist_rounded,
                                  size: 17,
                                  color: Colors.white,
                                )
                              : Text(
                                  '$number',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                )
                        : Icon(
                            available
                                ? Icons.lock_outline_rounded
                                : Icons.schedule_rounded,
                            size: 15,
                            color: GardenColors.muted,
                          ),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: GardenColors.paper.withValues(alpha: .96),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: GardenColors.ink,
                    ),
                  ),
                ),
                if (!available) ...[
                  const SizedBox(height: 2),
                  const Text(
                    '업데이트 예정',
                    style: TextStyle(
                      fontSize: 9,
                      height: 1.2,
                      color: GardenColors.ink,
                      backgroundColor: GardenColors.paper,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _WorldMapAction extends StatelessWidget {
  const _WorldMapAction({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.highlighted = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final primary = highlighted && onTap != null;
    final foreground = primary
        ? Colors.white
        : onTap != null
        ? GardenColors.ink
        : GardenColors.muted;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '$title · $detail',
      child: Tooltip(
        message: detail,
        excludeFromSemantics: true,
        child: Material(
          color: primary ? GardenColors.green : GardenColors.paper,
          elevation: 3,
          shadowColor: const Color(0x44000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: primary ? GardenColors.green : GardenColors.border,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: primary
                          ? Colors.white
                          : onTap != null
                          ? GardenColors.green
                          : GardenColors.muted,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: foreground,
                        ),
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
}

class _PathEntry extends StatelessWidget {
  const _PathEntry({
    required this.icon,
    required this.title,
    required this.detail,
    required this.active,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool active;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        icon,
        color: active ? GardenColors.green : GardenColors.muted,
        size: 23,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: GardenColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            Text(
              detail,
              style: const TextStyle(
                color: GardenColors.muted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _UnopenedGarden extends StatelessWidget {
  const _UnopenedGarden({required this.regionTitle, required this.description});

  final String regionTitle;
  final String description;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFDEE8D4), Color(0xFF9AAF85)],
      ),
    ),
    child: Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.landscape_outlined,
              size: 54,
              color: GardenColors.green,
            ),
            const SizedBox(height: 12),
            Text(
              regionTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: GardenColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: GardenColors.ink,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DecorationOption extends StatelessWidget {
  const _DecorationOption({
    required this.id,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: gardenDecorationLabel(id),
    child: Material(
      color: selected ? const Color(0xFFE2EBD8) : GardenColors.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? GardenColors.green : GardenColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(
                switch (id) {
                  'stone-path' => Icons.route_outlined,
                  'herbs' => Icons.spa_outlined,
                  _ => Icons.local_florist_outlined,
                },
                size: 21,
                color: GardenColors.green,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  gardenDecorationLabel(id),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: GardenColors.ink,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: GardenColors.green,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ExplanationStep extends StatelessWidget {
  const _ExplanationStep({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CircleAvatar(
        radius: 12,
        backgroundColor: const Color(0xFFE3EAD8),
        child: Text(
          number,
          style: const TextStyle(fontSize: 12, color: GardenColors.green),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: GardenColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              body,
              style: const TextStyle(
                color: GardenColors.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFE9EDDE),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: GardenColors.green),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: GardenColors.ink,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: GardenColors.green,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
  );
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({
    required this.icon,
    required this.label,
    required this.semanticsLabel,
  });

  final IconData icon;
  final String label;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel,
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: GardenColors.gold, size: 22),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: GardenColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

String _regionShortTitle(int number) => switch (number) {
  1 => '계산의 평원',
  2 => '패턴의 숲',
  3 => '측정의 협곡',
  4 => '방정식의 산맥',
  5 => '공간의 섬',
  6 => '비율의 바다',
  _ => '지혜의 정상',
};
