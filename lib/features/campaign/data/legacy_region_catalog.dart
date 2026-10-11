import '../domain/campaign_models.dart';

/// Renewal metadata for the seven territories inherited from the Android app.
///
/// This catalog deliberately contains no chapters or stages. Content authors
/// bind each entry with [RegionMetadata.bindChapters] after its 6x10 curriculum
/// has been authored.
final List<RegionMetadata> legacyRegionCatalog = List.unmodifiable([
  RegionMetadata(
    id: 'region-01-calculation',
    legacyId: 'T_CALCULATION',
    number: 1,
    title: '계산의 평원',
    description: '사칙연산과 연산 순서를 익히는 첫 번째 지역입니다.',
    prerequisiteRegionId: null,
    accessGateStageId: 'r01-c03-s10',
    finalStageId: 'r01-c06-s10',
    featuredCharacterIds: ['CHAR_D', 'CHAR_J', 'CHAR_L', 'CHAR_U'],
    visualAssets: const RegionVisualAssetKeys(
      worldOverlay: 'world.overlay.calculation',
      regionBackground: 'region.background.calculation',
      mapMarker: 'region.marker.calculation',
      completionBadge: 'badge.region.calculation',
    ),
    hotspot: const NormalizedMapHotspot(
      centerX: 0.22,
      centerY: 0.62,
      width: 0.20,
      height: 0.18,
    ),
  ),
  RegionMetadata(
    id: 'region-02-pattern',
    legacyId: 'T_PATTERN',
    number: 2,
    title: '규칙과 패턴의 숲',
    description: '수열과 반복 규칙을 관찰하고 표현하는 지역입니다.',
    prerequisiteRegionId: 'region-01-calculation',
    accessGateStageId: 'r02-c03-s10',
    finalStageId: 'r02-c06-s10',
    featuredCharacterIds: ['CHAR_B', 'CHAR_F', 'CHAR_N', 'CHAR_R'],
    visualAssets: const RegionVisualAssetKeys(
      worldOverlay: 'world.overlay.pattern',
      regionBackground: 'region.background.pattern',
      mapMarker: 'region.marker.pattern',
      completionBadge: 'badge.region.pattern',
    ),
    hotspot: const NormalizedMapHotspot(
      centerX: 0.17,
      centerY: 0.29,
      width: 0.20,
      height: 0.18,
    ),
  ),
  RegionMetadata(
    id: 'region-03-unit',
    legacyId: 'T_UNIT',
    number: 3,
    title: '단위와 측정의 협곡',
    description: '시간, 길이, 무게와 속력의 단위를 다루는 지역입니다.',
    prerequisiteRegionId: 'region-02-pattern',
    accessGateStageId: 'r03-c03-s10',
    finalStageId: 'r03-c06-s10',
    featuredCharacterIds: ['CHAR_G', 'CHAR_O', 'CHAR_P', 'CHAR_T'],
    visualAssets: const RegionVisualAssetKeys(
      worldOverlay: 'world.overlay.unit',
      regionBackground: 'region.background.unit',
      mapMarker: 'region.marker.unit',
      completionBadge: 'badge.region.unit',
    ),
    hotspot: const NormalizedMapHotspot(
      centerX: 0.45,
      centerY: 0.29,
      width: 0.20,
      height: 0.18,
    ),
  ),
  RegionMetadata(
    id: 'region-04-equation',
    legacyId: 'T_EQUATION',
    number: 4,
    title: '관계와 방정식의 산맥',
    description: '미지수와 여러 조건의 관계를 식으로 세우는 지역입니다.',
    prerequisiteRegionId: 'region-03-unit',
    accessGateStageId: 'r04-c03-s10',
    finalStageId: 'r04-c06-s10',
    featuredCharacterIds: ['CHAR_C', 'CHAR_S', 'CHAR_V', 'CHAR_Y'],
    visualAssets: const RegionVisualAssetKeys(
      worldOverlay: 'world.overlay.equation',
      regionBackground: 'region.background.equation',
      mapMarker: 'region.marker.equation',
      completionBadge: 'badge.region.equation',
    ),
    hotspot: const NormalizedMapHotspot(
      centerX: 0.83,
      centerY: 0.29,
      width: 0.20,
      height: 0.18,
    ),
  ),
  RegionMetadata(
    id: 'region-05-geometry',
    legacyId: 'T_GEOMETRY',
    number: 5,
    title: '도형과 공간의 섬',
    description: '둘레, 넓이, 분할과 공간 감각을 탐구하는 지역입니다.',
    prerequisiteRegionId: 'region-04-equation',
    accessGateStageId: 'r05-c03-s10',
    finalStageId: 'r05-c06-s10',
    featuredCharacterIds: ['CHAR_E', 'CHAR_K', 'CHAR_M', 'CHAR_X'],
    visualAssets: const RegionVisualAssetKeys(
      worldOverlay: 'world.overlay.geometry',
      regionBackground: 'region.background.geometry',
      mapMarker: 'region.marker.geometry',
      completionBadge: 'badge.region.geometry',
    ),
    hotspot: const NormalizedMapHotspot(
      centerX: 0.66,
      centerY: 0.32,
      width: 0.14,
      height: 0.17,
    ),
  ),
  RegionMetadata(
    id: 'region-06-ratio',
    legacyId: 'T_RATIO',
    number: 6,
    title: '비율과 분석의 바다',
    description: '분수, 비율, 백분율과 자료 해석을 연결하는 지역입니다.',
    prerequisiteRegionId: 'region-05-geometry',
    accessGateStageId: 'r06-c03-s10',
    finalStageId: 'r06-c06-s10',
    featuredCharacterIds: ['CHAR_A', 'CHAR_H', 'CHAR_W'],
    visualAssets: const RegionVisualAssetKeys(
      worldOverlay: 'world.overlay.ratio',
      regionBackground: 'region.background.ratio',
      mapMarker: 'region.marker.ratio',
      completionBadge: 'badge.region.ratio',
    ),
    hotspot: const NormalizedMapHotspot(
      centerX: 0.75,
      centerY: 0.69,
      width: 0.20,
      height: 0.18,
    ),
  ),
  RegionMetadata(
    id: 'region-07-wisdom',
    legacyId: 'T_WISDOM',
    number: 7,
    title: '지혜의 정상',
    description: '여섯 지역의 개념을 결합해 새로운 풀이를 만드는 최종 지역입니다.',
    prerequisiteRegionId: 'region-06-ratio',
    accessGateStageId: 'r07-c03-s10',
    finalStageId: 'r07-c06-s10',
    featuredCharacterIds: ['CHAR_I', 'CHAR_Q', 'CHAR_Z'],
    visualAssets: const RegionVisualAssetKeys(
      worldOverlay: 'world.overlay.wisdom',
      regionBackground: 'region.background.wisdom',
      mapMarker: 'region.marker.wisdom',
      completionBadge: 'badge.region.wisdom',
    ),
    hotspot: const NormalizedMapHotspot(
      centerX: 0.48,
      centerY: 0.53,
      width: 0.18,
      height: 0.17,
    ),
  ),
]);

RegionMetadata? legacyRegionById(String id) {
  for (final region in legacyRegionCatalog) {
    if (region.id == id || region.legacyId == id) {
      return region;
    }
  }
  return null;
}
