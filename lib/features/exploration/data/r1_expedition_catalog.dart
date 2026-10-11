import '../../garden/domain/garden_models.dart';

/// Presentation-only expedition names. Stable campaign and restoration IDs
/// remain unchanged, including source-linked review prerequisites.
class ExpeditionDestination {
  const ExpeditionDestination({
    required this.number,
    required this.title,
    required this.shortTitle,
    required this.description,
    required this.milestones,
  });

  final int number;
  final String title;
  final String shortTitle;
  final String description;
  final List<String> milestones;

  String get chapterId => 'r01-c${number.toString().padLeft(2, '0')}';
}

const r1ExpeditionDestinations = <ExpeditionDestination>[
  ExpeditionDestination(
    number: 1,
    title: '평원 입구',
    shortTitle: '입구',
    description: '흩어진 흔적을 모아 첫 탐험길을 찾아요.',
    milestones: ['길의 흔적 발견', '첫 이정표 연결', '갈림길 쉼터 발견', '평원 안쪽으로 이어지는 길'],
  ),
  ExpeditionDestination(
    number: 2,
    title: '수확길',
    shortTitle: '수확길',
    description: '묶음과 낱개의 관계를 찾아 과수원 너머로 나아가요.',
    milestones: ['수확 상자 정리', '과수원 길 연결', '끊어진 다리 연결', '물길로 이어지는 통로'],
  ),
  ExpeditionDestination(
    number: 3,
    title: '오래된 수문',
    shortTitle: '수문',
    description: '계산 순서를 연결해 잠든 물길을 열어요.',
    milestones: ['수문 단서 발견', '물길의 순서 확인', '수문 장치 연결', '평원 물길 개방'],
  ),
  ExpeditionDestination(
    number: 4,
    title: '기억의 흔적',
    shortTitle: '기억길',
    description: '지나온 관계를 다른 모습의 단서에서 다시 찾아요.',
    milestones: ['익숙한 흔적 재발견', '숨은 샛길 발견', '기억의 쉼터 연결', '돌아오는 길 완성'],
  ),
  ExpeditionDestination(
    number: 5,
    title: '봉인 공방',
    shortTitle: '공방',
    description: '새로운 봉인과 직선 파워로 공방의 단서를 찾아요.',
    milestones: ['공방 입구 조사', '겹친 봉인 해제', '공방 동력 연결', '새로운 탐험 도구 발견'],
  ),
  ExpeditionDestination(
    number: 6,
    title: '평원의 전망대',
    shortTitle: '전망대',
    description: '배운 관계를 연결해 다음 지역으로 이어지는 신호를 찾아요.',
    milestones: ['전망대 표식 발견', '언덕길 연결', '탐험대 야영지 발견', '다음 지역의 탐험 신호 발견'],
  ),
];

ExpeditionDestination expeditionDestinationForChapter(int chapter) =>
    r1ExpeditionDestinations[(chapter - 1).clamp(0, 5)];

String expeditionMilestoneTitle(RestorationNode? node) {
  if (node == null || node.chapterNumber < 1) return '첫 탐험길 발견';
  final destination = expeditionDestinationForChapter(node.chapterNumber);
  final index = const [2, 4, 7, 10].indexOf(node.milestone);
  return destination.milestones[index < 0 ? 0 : index];
}

String expeditionDecorationLabel(String id) => switch (id) {
  'stone-path' => '돌 표식',
  'herbs' => '허브 쉼터',
  _ => '들꽃 표식',
};
