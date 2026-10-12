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
    this.regionNumber = 1,
  });

  final int number;
  final String title;
  final String shortTitle;
  final String description;
  final List<String> milestones;
  final int regionNumber;

  String get chapterId =>
      'r${regionNumber.toString().padLeft(2, '0')}-c${number.toString().padLeft(2, '0')}';
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

const r2ExpeditionDestinations = <ExpeditionDestination>[
  ExpeditionDestination(
    regionNumber: 2,
    number: 1,
    title: '발자국의 숲 입구',
    shortTitle: '숲 입구',
    description: '일정한 간격의 흔적을 따라 Bravo와 Foxtrot를 찾아요.',
    milestones: ['발자국 조사', '숲 표지판 연결', '반복 무늬 쉼터', 'Bravo · Foxtrot 구조길 개방'],
  ),
  ExpeditionDestination(
    regionNumber: 2,
    number: 2,
    title: '교대 덩굴길',
    shortTitle: '덩굴길',
    description: '두 배 성장과 교대하는 차례를 구별하며 나아가요.',
    milestones: ['성장 흔적 기록', '교대 신호 해독', '덩굴 사이 통로', '두 단계 성장길 개방'],
  ),
  ExpeditionDestination(
    regionNumber: 2,
    number: 3,
    title: '규칙의 고목',
    shortTitle: '고목',
    description: '입력과 출력의 관계로 고목 수문을 열고 Romeo를 구해요.',
    milestones: ['기계 기록 발견', '장치 순서 연결', '고목 계단 연결', 'Romeo 구조 · 숲 수문 개방'],
  ),
  ExpeditionDestination(
    regionNumber: 2,
    number: 4,
    title: '되돌아오는 숲길',
    shortTitle: '기억길',
    description: '탐험 일지에서 익숙한 규칙을 다시 꺼내 샛길을 찾아요.',
    milestones: ['기억 일지 발견', '옛 표식 연결', '파워 조합 쉼터', '기억의 샛길 완성'],
  ),
  ExpeditionDestination(
    regionNumber: 2,
    number: 5,
    title: '덩굴과 꽃의 미로',
    shortTitle: '미로',
    description: '익숙한 수학으로 단단한 덩굴을 공략해 November를 구해요.',
    milestones: ['공방 보급길', '미로 단서 연결', '단단한 덩굴 제거', 'November 구조길 개방'],
  ),
  ExpeditionDestination(
    regionNumber: 2,
    number: 6,
    title: '숲과 평원의 교차로',
    shortTitle: '교차로',
    description: '평원과 숲에서 배운 관계로 전망대 신호를 완성해요.',
    milestones: ['평원 보급 연결', '협곡 방향 조사', '탐험대 야영지', '숲 전망대 신호 완성'],
  ),
];

List<ExpeditionDestination> expeditionDestinationsForRegion(int regionNumber) =>
    regionNumber == 2 ? r2ExpeditionDestinations : r1ExpeditionDestinations;

String expeditionRegionTitle(int number) =>
    number == 2 ? '규칙과 패턴의 숲' : '계산의 평원';

int expeditionRegionNumber(String? regionId) =>
    regionId == 'region-02-pattern' ? 2 : 1;

ExpeditionDestination expeditionDestinationForChapter(
  int chapter, {
  int regionNumber = 1,
}) => expeditionDestinationsForRegion(regionNumber)[(chapter - 1).clamp(0, 5)];

String expeditionMilestoneTitle(RestorationNode? node) {
  if (node == null || node.chapterNumber < 1) return '첫 탐험길 발견';
  final destination = expeditionDestinationForChapter(
    node.chapterNumber,
    regionNumber: expeditionRegionNumber(node.regionId),
  );
  final index = const [2, 4, 7, 10].indexOf(node.milestone);
  return destination.milestones[index < 0 ? 0 : index];
}

String expeditionDecorationLabel(String id) => switch (id) {
  'stone-path' => '돌 표식',
  'herbs' => '허브 쉼터',
  _ => '들꽃 표식',
};
