import 'package:flutter/material.dart';

import '../../garden/domain/garden_models.dart';
import '../data/r1_expedition_catalog.dart';
import 'r1_expedition_screen.dart';

/// Reinterprets the existing stable restoration record as an expedition
/// discovery. Choosing a marker is cosmetic and cannot change campaign access.
class ExpeditionMilestoneScreen extends StatelessWidget {
  const ExpeditionMilestoneScreen({
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
  Widget build(BuildContext context) {
    final chapter = node?.chapterNumber ?? 1;
    final regionNumber = expeditionRegionNumber(node?.regionId);
    final destination = expeditionDestinationForChapter(
      chapter,
      regionNumber: regionNumber,
    );
    final title = expeditionMilestoneTitle(node);
    final choices = node?.decorationIds ?? gardenDecorationIds;
    final milestones = restoredNodeIds
        .where((id) => id.startsWith('${destination.chapterId}-garden-'))
        .length;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F3E9),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Center(
                child: Text(
                  alreadyRestored ? '탐험 흔적을 바꿔요' : '새로운 길을 발견했어요',
                  style: const TextStyle(
                    fontSize: 17,
                    color: Color(0xFF183F40),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Semantics(
                        image: true,
                        label:
                            '${destination.title}에서 $title. '
                            '${expeditionDecorationLabel(decorationId)}를 선택했습니다.',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ExpeditionEnvironmentArt(
                                regionNumber: regionNumber,
                                chapter: chapter,
                                milestones: milestones,
                                decorationId: decorationId,
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Color(0xCA173F3B),
                                    ],
                                    stops: [.35, 1],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 14,
                                right: 14,
                                bottom: 12,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      destination.title,
                                      style: const TextStyle(
                                        color: Color(0xFFF6CE72),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      title,
                                      maxLines: 2,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${regionNumber == 2 ? '숲' : '평원'}에서 $completedStageCount개의 관계를 발견했어요.',
                                      maxLines: 2,
                                      style: const TextStyle(
                                        color: Color(0xFFD9E9DD),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFCF1),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFD4DFD0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '여행의 흔적을 남겨요',
                                        style: TextStyle(
                                          color: Color(0xFF183F40),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        '이정표와 쉼터의 모습만 달라져요. '
                                        '언제든 무료로 바꿀 수 있어요.',
                                        style: TextStyle(
                                          color: Color(0xFF607374),
                                          fontSize: 12,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      for (final id in choices)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 5,
                                          ),
                                          child: Semantics(
                                            selected: decorationId == id,
                                            child: OutlinedButton.icon(
                                              key: ValueKey(
                                                'expedition-decoration-$id',
                                              ),
                                              onPressed: () =>
                                                  onChooseDecoration(id),
                                              style: OutlinedButton.styleFrom(
                                                backgroundColor:
                                                    decorationId == id
                                                    ? const Color(0xFFE2EDE3)
                                                    : Colors.transparent,
                                                foregroundColor: const Color(
                                                  0xFF256D66,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                    ),
                                                minimumSize: const Size(
                                                  double.infinity,
                                                  37,
                                                ),
                                              ),
                                              icon: Icon(
                                                decorationId == id
                                                    ? Icons.check_circle_rounded
                                                    : switch (id) {
                                                        'stone-path' =>
                                                          Icons
                                                              .signpost_outlined,
                                                        'herbs' =>
                                                          Icons.cabin_outlined,
                                                        _ =>
                                                          Icons
                                                              .local_florist_outlined,
                                                      },
                                                size: 18,
                                              ),
                                              label: Text(
                                                expeditionDecorationLabel(id),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        destination.description,
                                        style: const TextStyle(
                                          color: Color(0xFF607374),
                                          fontSize: 12,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: onFinish,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF256D66),
                                  minimumSize: const Size(0, 42),
                                ),
                                icon: const Icon(
                                  Icons.near_me_outlined,
                                  size: 18,
                                ),
                                label: const Text(
                                  '탐험을 계속하기',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
