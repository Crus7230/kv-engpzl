import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/campaign/data/legacy_region_catalog.dart';
import 'package:kvm/features/companions/companions.dart';

// Frozen verbatim from kvm/data/CharacterData.kt, not Renewal-authored lore.
const _legacyFields = <List<String>>[
  [
    "CHAR_A",
    "Alpha",
    "ic_char_a",
    "ENFP",
    "피자 (조각을 나눠 먹는 게 좋아서)",
    "분수",
    "π ≈ 3.1415926535",
  ],
  [
    "CHAR_B",
    "Bravo",
    "ic_char_b",
    "ISTJ",
    "라면 (정해진 순서를 지키는 게 즐거워서)",
    "규칙 찾기",
    "2^10 = 1024",
  ],
  [
    "CHAR_C",
    "Charlie",
    "ic_char_c",
    "INTP",
    "초콜릿 (조각을 퍼즐처럼 나눠서)",
    "수학 퍼즐",
    "1+2+…+7 = 28",
  ],
  [
    "CHAR_D",
    "Delta",
    "ic_char_d",
    "ESFJ",
    "떡볶이 (친구와 나눠 먹는 재미)",
    "덧셈",
    "180×2 = 360 (원 한 바퀴)",
  ],
  [
    "CHAR_E",
    "Echo",
    "ic_char_e",
    "ENTJ",
    "햄버거 (층층이 쌓인 구조가 멋져서)",
    "도형 쌓기",
    "5^3 = 125",
  ],
  [
    "CHAR_F",
    "Foxtrot",
    "ic_char_f",
    "ISFP",
    "아이스크림 (맛 선택이 패턴 같아서)",
    "패턴",
    "1/8 = 0.125",
  ],
  [
    "CHAR_G",
    "Golf",
    "ic_char_g",
    "ESTP",
    "치킨 (뼈와 살 분리가 퍼즐 같아서)",
    "비교하기",
    "144+89 = 233 (피보나치)",
  ],
  [
    "CHAR_H",
    "Hotel",
    "ic_char_h",
    "INFJ",
    "샐러드 (재료 비율 맞추는 재미)",
    "비율",
    "1^3+5^3+3^3 = 153",
  ],
  [
    "CHAR_I",
    "India",
    "ic_char_i",
    "ENTP",
    "파스타 (끝없이 이어져 무한을 떠올려서)",
    "무한",
    "∞ (무한대)",
  ],
  [
    "CHAR_J",
    "Juliett",
    "ic_char_j",
    "ISFJ",
    "김밥 (규칙적으로 말린 모양이 좋아서)",
    "반복",
    "3^6 = 729",
  ],
  [
    "CHAR_K",
    "Kilo",
    "ic_char_k",
    "ESTJ",
    "돈가스 (정사각형 잘라 나누기 좋음)",
    "도형 자르기",
    "1+2+…+11 = 66",
  ],
  [
    "CHAR_L",
    "Lima",
    "ic_char_l",
    "ENFJ",
    "빵 (부드럽게 나눠 먹기 좋아서)",
    "나눗셈",
    "7×11×13 = 1001",
  ],
  [
    "CHAR_M",
    "Mike",
    "ic_char_m",
    "ISTP",
    "스시 (정갈한 배열이 마음에 들어서)",
    "대칭",
    "2^8 = 256",
  ],
  [
    "CHAR_N",
    "November",
    "ic_char_n",
    "INFP",
    "떡 (단순하지만 변형이 다양해서)",
    "도형 변형",
    "1+2+…+9 = 45",
  ],
  [
    "CHAR_O",
    "Oscar",
    "ic_char_o",
    "ENTJ",
    "케이크 (분수처럼 나눠 자르기 좋아서)",
    "분수",
    "4! = 24",
  ],
  [
    "CHAR_P",
    "Papa",
    "ic_char_p",
    "ESFP",
    "핫도그 (간단하지만 응용 다양)",
    "이야기 수학",
    "2^9 = 512",
  ],
  [
    "CHAR_Q",
    "Quebec",
    "ic_char_q",
    "ENFP",
    "타코 (접힌 모양이 원뿔 같아서)",
    "입체도형",
    "e ≈ 2.7182818284",
  ],
  [
    "CHAR_R",
    "Romeo",
    "ic_char_r",
    "INTJ",
    "초밥 (배치가 수열처럼 규칙적)",
    "수열",
    "√2 ≈ 1.4142135623",
  ],
  [
    "CHAR_S",
    "Sierra",
    "ic_char_s",
    "ISFP",
    "만두 (동그란 모양이 원 같아서)",
    "원",
    "1/7 = 0.1428571428…",
  ],
  [
    "CHAR_T",
    "Tango",
    "ic_char_t",
    "ESTP",
    "오므라이스 (안의 비밀 찾기 재미)",
    "문제 해결",
    "2^11 = 2048",
  ],
  [
    "CHAR_U",
    "Uniform",
    "ic_char_u",
    "INFP",
    "치즈 (길게 늘어나는 모습이 재미)",
    "곱셈",
    "24×60 = 1440 (하루의 분)",
  ],
  [
    "CHAR_V",
    "Victor",
    "ic_char_v",
    "INTP",
    "우동 (길게 이어지는 선이 그래프 같아)",
    "그래프",
    "√10 ≈ 3.1622776601",
  ],
  [
    "CHAR_W",
    "Whiskey",
    "ic_char_w",
    "ESFJ",
    "카레 (재료/양념 비율 맞추기)",
    "비율",
    "10^3+9^3 = 12^3+1^3 = 1729",
  ],
  [
    "CHAR_X",
    "X-ray",
    "ic_char_x",
    "INFJ",
    "팬케이크 (둥근 층이 겹쳐 보여서)",
    "원 넓이",
    "√2/2 ≈ 0.7071067812",
  ],
  [
    "CHAR_Y",
    "Yankee",
    "ic_char_y",
    "ISTJ",
    "스테이크 (정확히 나눠 써는 규칙성)",
    "규칙",
    "97 (소수)",
  ],
  [
    "CHAR_Z",
    "Zulu",
    "ic_char_z",
    "ENFP",
    "바나나 (부드러운 곡선이 좋아서)",
    "곡선",
    "2^20 = 1,048,576",
  ],
];

void main() {
  test('all 26 original profile fields are inherited verbatim', () {
    expect(companionProfiles, hasLength(26));
    for (var index = 0; index < _legacyFields.length; index++) {
      final p = companionProfiles[index];
      expect(
        [
          p.id,
          p.name,
          p.imageName,
          p.mbti,
          p.favoriteFood,
          p.favoriteMathField,
          p.favoriteNumber,
        ],
        _legacyFields[index],
        reason: p.id,
      );
      expect(p.legacyAsset, 'assets/legacy/char-${p.letter.toLowerCase()}.png');
    }
    expect(companionProfiles.map((p) => p.id).toSet(), hasLength(26));
    expect(companionProfileById('CHAR_UNKNOWN'), isNull);
  });

  test(
    'nonalphabetical recruitment preserves all original region allocations',
    () {
      expect(companionRecruitmentPlan, hasLength(26));
      expect(
        companionRecruitmentPlan.map((p) => p.characterId).toSet(),
        companionProfiles.map((p) => p.id).toSet(),
      );
      for (final region in legacyRegionCatalog) {
        final planned = companionRecruitmentPlan
            .where((p) => p.regionId == region.id)
            .toList();
        expect(
          planned.map((p) => p.characterId).toSet(),
          region.featuredCharacterIds.toSet(),
        );
        expect(
          planned.take(2).map((p) => p.requiredStageId),
          everyElement('r${region.number.toString().padLeft(2, '0')}-c01-s10'),
        );
        if (planned.length == 4)
          expect(
            planned[2].requiredStageId,
            'r${region.number.toString().padLeft(2, '0')}-c03-s10',
          );
        expect(
          planned.last.requiredStageId,
          'r${region.number.toString().padLeft(2, '0')}-c05-s10',
        );
        for (final p in planned) {
          expect(p.available, region.number <= 2);
          expect(p.arrivalStoryId, 'expedition-join-${p.characterId}');
        }
      }
      expect(companionRecruitmentPlan.take(4).map((p) => p.characterId), [
        'CHAR_D',
        'CHAR_J',
        'CHAR_L',
        'CHAR_U',
      ]);
      expect(
        companionRecruitmentPlan
            .where((p) => p.regionNumber == 2)
            .map((p) => p.characterId),
        ['CHAR_B', 'CHAR_F', 'CHAR_R', 'CHAR_N'],
      );
      expect(companionRecruitmentById('CHAR_UNKNOWN'), isNull);
    },
  );
}
