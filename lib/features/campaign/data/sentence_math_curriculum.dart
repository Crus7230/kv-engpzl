import '../domain/sentence_math_plan.dart';

typedef _CoreGoal = ({SentenceMathFocus focus, String goal});

/// The same interpretation route spans all regions. C04-C06 inherit the actual
/// source concept; they are not a second monotonically harder math curriculum.
SentenceMathPlan sentenceMathPlanFor({
  required int regionNumber,
  required int chapterNumber,
  String? sourceStageId,
}) {
  final source = sourceStageId == null
      ? null
      : RegExp(r'^r(\d{2})-c(\d{2})-s(\d{2})$').firstMatch(sourceStageId);
  if (sourceStageId != null && source == null) {
    throw ArgumentError('Invalid sentence curriculum source ID.');
  }
  final sourceRegion = source == null
      ? regionNumber
      : int.parse(source.group(1)!);
  final sourceChapter = source == null
      ? chapterNumber
      : int.parse(source.group(2)!);
  final sourceStageNumber = source == null ? 1 : int.parse(source.group(3)!);
  if (regionNumber < 1 ||
      regionNumber > _coreGoals.length ||
      chapterNumber < 1 ||
      chapterNumber > 6 ||
      sourceRegion < 1 ||
      sourceRegion > regionNumber ||
      sourceChapter < 1 ||
      sourceChapter > 3 ||
      sourceStageNumber < 1 ||
      sourceStageNumber > 10) {
    throw ArgumentError('Invalid sentence curriculum location/source.');
  }
  if ((chapterNumber >= 4) != (sourceStageId != null)) {
    throw ArgumentError('Spiral sentence plans require a source slot.');
  }
  final goal = _coreGoals[sourceRegion - 1][sourceChapter - 1];
  return SentenceMathPlan(
    regionNumber: regionNumber,
    chapterNumber: chapterNumber,
    focus: goal.focus,
    phase: switch (chapterNumber) {
      4 => SentenceMathChapterPhase.retrieval,
      5 => SentenceMathChapterPhase.familiarMathNewBoard,
      6 => SentenceMathChapterPhase.integratedTransfer,
      _ => SentenceMathChapterPhase.conceptDevelopment,
    },
    authoringGoal: goal.goal,
    bridgeGoal: _bridges[regionNumber - 1],
    sourceStageId: sourceStageId,
  );
}

const List<String> _bridges = [
  '보이는 수량을 짚고 무엇을 구해야 하는지 먼저 말합니다.',
  '평원의 덧셈·곱셈 관계를 반복되는 변화와 규칙의 식으로 연결합니다.',
  '묶기·나누기를 단위 환산과 단위당 양의 관계로 연결합니다.',
  '현재 양·변화량·전체의 관계를 거꾸로 읽어 모르는 양을 찾습니다.',
  '묶음과 관계식을 경계의 길이·덮는 면·공간 배치에 연결합니다.',
  '같은 묶음·단위당 양·부분과 전체를 비율과 자료 해석에 연결합니다.',
  '이전 여섯 리전에서 배운 관계 중 필요한 것을 선택해 근거를 설명합니다.',
];

const List<List<_CoreGoal>> _coreGoals = [
  [
    (
      focus: SentenceMathFocus.quantityRelationships,
      goal: '모으기·남기기·차이·처음 양을 구분하고 구할 대상을 식으로 나타냅니다.',
    ),
    (
      focus: SentenceMathFocus.groupsAndShares,
      goal: '묶음 수·묶음당 양·전체를 구분하고 공평한 나눔과 몇 묶음인지 구분합니다.',
    ),
    (
      focus: SentenceMathFocus.operationOrder,
      goal: '문장의 각 조건을 부분식으로 만들고 먼저 계산할 묶음을 괄호로 나타냅니다.',
    ),
  ],
  [
    (
      focus: SentenceMathFocus.constantPatterns,
      goal: '여러 항의 변화를 비교해 일정한 차이·배수 규칙을 찾고 다음 항의 식을 만듭니다.',
    ),
    (
      focus: SentenceMathFocus.alternatingPatterns,
      goal: '교대·반복 순서를 확인하고 현재 항에 적용할 규칙과 두 단계 변화를 구분합니다.',
    ),
    (
      focus: SentenceMathFocus.ruleInputOutput,
      goal: '입력·출력 사례로 규칙을 검증하고 출력이나 입력을 구하는 부분식으로 바꿉니다.',
    ),
  ],
  [
    (
      focus: SentenceMathFocus.commonUnits,
      goal: '시간·길이의 기준 단위를 확인하고 혼합 단위를 한 단위로 맞춘 뒤 계산합니다.',
    ),
    (
      focus: SentenceMathFocus.massAndCapacity,
      goal: '무게·들이의 단위와 전체·사용량·묶음당 양을 구분해 환산과 계산을 연결합니다.',
    ),
    (
      focus: SentenceMathFocus.distanceSpeedTime,
      goal: '거리·시간·단위 시간당 거리 중 구할 양을 정하고 단위를 맞춰 관계식을 만듭니다.',
    ),
  ],
  [
    (
      focus: SentenceMathFocus.inverseRelationships,
      goal: '전체·차이·변화량을 읽고 결과가 아닌 처음 양이나 부분을 반대 연산으로 구합니다.',
    ),
    (
      focus: SentenceMathFocus.unknownGroups,
      goal: '묶음과 덧붙이거나 덜어 낸 양을 분리하고 거꾸로 풀어 미지량을 구하는 식을 만듭니다.',
    ),
    (
      focus: SentenceMathFocus.equalRelationships,
      goal: '양쪽 값이 같다는 조건을 해석하고 알려진 쪽의 부분식에서 모르는 양을 구합니다.',
    ),
  ],
  [
    (
      focus: SentenceMathFocus.perimeter,
      goal: '경계의 변과 같은 길이의 반복을 읽어 둘레 또는 빠진 변을 구하는 식을 만듭니다.',
    ),
    (
      focus: SentenceMathFocus.area,
      goal: '길이와 넓이를 구분하고 덮는 면을 분해·결합하는 부분식으로 나타냅니다.',
    ),
    (
      focus: SentenceMathFocus.spatialRelationships,
      goal: '배치·이동 조건에서 필요한 길이·면·개수 정보를 골라 공간 관계를 식으로 만듭니다.',
    ),
  ],
  [
    (
      focus: SentenceMathFocus.equivalentRatios,
      goal: '기준량과 비교량을 정하고 같은 비를 유지하는 묶음·나눔 관계를 식으로 만듭니다.',
    ),
    (
      focus: SentenceMathFocus.percentages,
      goal: '전체를 기준으로 비율·부분·전체 중 구할 대상을 구분하고 백분율 관계로 연결합니다.',
    ),
    (
      focus: SentenceMathFocus.dataRelationships,
      goal: '표의 항목·단위·기준을 읽고 비교·평균·비율에 필요한 자료만 골라 식으로 만듭니다.',
    ),
  ],
  [
    (
      focus: SentenceMathFocus.arithmeticPatternMeasurement,
      goal: '계산·규칙·측정의 표현을 오가며 같은 관계를 다른 상황의 식으로 옮깁니다.',
    ),
    (
      focus: SentenceMathFocus.relationshipAndSpace,
      goal: '미지량·공간·비율의 조건을 분리해 배운 관계를 선택하고 부분식을 연결합니다.',
    ),
    (
      focus: SentenceMathFocus.integratedEvidence,
      goal: '복합 자료에서 구할 대상과 필요한 조건을 선택하고 완성한 식이 뜻하는 관계를 설명합니다.',
    ),
  ],
];
