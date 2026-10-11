import '../../campaign/data/regional_campaign.dart';
import '../domain/garden_models.dart';

/// All 168 nodes point to existing, stable campaign stage identifiers.
/// Defining a node does not make the associated planned content playable.
final List<GardenDefinition> gardenDefinitions = List.unmodifiable([
  for (final region in regionalCampaign.regions)
    GardenDefinition(
      id: 'garden-${region.id}',
      regionId: region.id,
      title: '${region.title}의 정원',
      backgroundAsset: region.number == 1 ? 'assets/legacy/plains.png' : null,
      featuredCharacterIds: region.featuredCharacterIds,
      projectScenes: region.number == 1 ? r1GardenProjectScenes : const [],
      restorationNodes: [
        for (final chapter in region.chapters)
          for (final milestone in const [2, 4, 7, 10])
            RestorationNode(
              id: '${chapter.id}-garden-${milestone.toString().padLeft(2, '0')}',
              regionId: region.id,
              chapterId: chapter.id,
              requiredStageId: chapter.stages
                  .singleWhere((stage) => stage.number == milestone)
                  .id,
              title: '${chapter.title} · ${_milestoneLabel(milestone)}',
              chapterNumber: chapter.number,
              milestone: milestone,
              sceneId: region.number == 1
                  ? r1GardenProjectScenes[chapter.number - 1].id
                  : null,
              characterId: region.number == 1
                  ? r1GardenProjectScenes[chapter.number - 1].characterId
                  : null,
              storyText: region.number == 1
                  ? _r1RestorationStory(chapter.number, milestone)
                  : null,
            ),
      ],
    ),
]);

/// A separate development reward; it never completes a campaign stage.
const RestorationNode demoRestorationNode = RestorationNode(
  id: 'r01-demo-meadow',
  regionId: 'region-01-calculation',
  chapterId: null,
  requiredStageId: 'prototype-bundle-add',
  title: '첫 번째 들꽃 화단',
  chapterNumber: 0,
  milestone: 1,
);

GardenDefinition? gardenDefinitionByRegionId(String regionId) {
  for (final definition in gardenDefinitions) {
    if (definition.regionId == regionId) return definition;
  }
  return null;
}

String _milestoneLabel(int milestone) => switch (milestone) {
  2 => '새싹 깨우기',
  4 => '길과 화단 돌보기',
  7 => '쉼터 되살리기',
  _ => '정원 풍경 완성하기',
};

const r1GardenProjectScenes = <GardenProjectScene>[
  GardenProjectScene(
    id: 'r01-scene-flowerbeds',
    chapterId: 'r01-c01',
    title: '첫 수확의 화단',
    description: '흩어진 꽃과 씨앗을 모아 정원의 입구를 되살립니다.',
    environmentLayerId: 'flowerbeds',
    characterId: 'CHAR_D',
  ),
  GardenProjectScene(
    id: 'r01-scene-orchard',
    chapterId: 'r01-c02',
    title: '묶음의 과수원',
    description: '같은 묶음의 관계를 찾아 나무와 수확 길을 정리합니다.',
    environmentLayerId: 'orchard',
    characterId: 'CHAR_J',
  ),
  GardenProjectScene(
    id: 'r01-scene-pond',
    chapterId: 'r01-c03',
    title: '균형의 연못',
    description: '연산 순서를 연결해 물길과 연못 주변을 완성합니다.',
    environmentLayerId: 'pond',
    characterId: 'CHAR_L',
  ),
  GardenProjectScene(
    id: 'r01-scene-memory-path',
    chapterId: 'r01-c04',
    title: '기억의 씨앗길',
    description: '다른 모습으로 돌아온 관계를 찾아 산책길을 가꿉니다.',
    environmentLayerId: 'memory-path',
    characterId: 'CHAR_D',
  ),
  GardenProjectScene(
    id: 'r01-scene-workshop',
    chapterId: 'r01-c05',
    title: '봉인 공방',
    description: '익숙한 수학과 새로운 봉인으로 정원 공방을 엽니다.',
    environmentLayerId: 'workshop',
    characterId: 'CHAR_J',
  ),
  GardenProjectScene(
    id: 'r01-scene-lookout',
    chapterId: 'r01-c06',
    title: '계산의 전망대',
    description: '배운 관계를 연결해 계산의 평원 전망대를 완성합니다.',
    environmentLayerId: 'lookout',
    characterId: 'CHAR_U',
  ),
];

const r1CharacterStories = <GardenCharacterStory>[
  GardenCharacterStory(
    id: 'r01-character-d-intro',
    characterId: 'CHAR_D',
    title: '작은 시작',
    text:
        'D는 비어 있는 화단에 첫 씨앗을 심습니다. '
        '한 번에 모든 길을 만들 필요는 없어요. 오늘 찾은 관계 하나가 시작이니까요.',
  ),
  GardenCharacterStory(
    id: 'r01-character-j-intro',
    characterId: 'CHAR_J',
    title: '정원에서 찾는 관계',
    text:
        'J는 퍼즐에서 찾은 숫자 조각을 나란히 놓습니다. '
        '조각을 많이 모으는 것만큼 중요한 건, 문장 속에서 어떻게 이어지는지 찾는 일이에요.',
  ),
  GardenCharacterStory(
    id: 'r01-character-l-intro',
    characterId: 'CHAR_L',
    requiredStageId: 'r01-c02-s10',
    title: '함께 만드는 물길',
    text:
        '과수원의 길이 이어지자 L이 평원에 합류합니다. '
        '같은 묶음을 보고, 남은 것을 세어 보세요. 서로 다른 계산도 하나의 물길로 이어질 수 있어요.',
  ),
  GardenCharacterStory(
    id: 'r01-character-u-intro',
    characterId: 'CHAR_U',
    requiredStageId: 'r01-c03-s10',
    title: '다시 돌아올 정원',
    text:
        '연못이 완성되자 U가 기억의 씨앗을 가져옵니다. '
        '같은 관계가 다른 문장으로 돌아오면 다시 찾아보세요. 잠깐 쉬었다 돌아와도 정원은 그대로 기다립니다.',
  ),
];

String _r1RestorationStory(int chapterNumber, int milestone) {
  final project = r1GardenProjectScenes[chapterNumber - 1];
  final progress = switch (milestone) {
    2 => '작은 새싹이 자리를 잡았습니다.',
    4 => '화단 사이에 걸을 수 있는 길이 이어졌습니다.',
    7 => '지나가던 친구도 쉬어 갈 자리가 생겼습니다.',
    _ => '이 구역의 풍경이 완성되었습니다.',
  };
  final next = milestone == 10
      ? '완성한 곳은 언제든 돌아와 다시 꾸밀 수 있어요.'
      : '다음 관계를 찾으면 이 풍경에 새로운 부분이 더해집니다.';
  return '${project.title}에 $progress $next';
}
