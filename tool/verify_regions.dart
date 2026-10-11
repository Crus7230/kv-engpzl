import 'dart:io';

import '../lib/features/campaign/data/initial_campaign.dart';
import '../lib/features/campaign/data/legacy_region_catalog.dart';
import '../lib/features/campaign/domain/campaign_models.dart';
import '../lib/features/campaign/domain/campaign_validator.dart';
import '../lib/features/puzzle/data/sample_puzzles.dart';

void main() {
  _verifyLegacyCatalog();
  _verifyRegionalCampaign();
  _expect(
    initialCampaign.stages.every((stage) => stage.skillId.trim().isNotEmpty),
    'every compatibility stage should expose a stable skill ID',
  );
  stdout.writeln(
    'Region verification passed: 7 legacy regions, normalized hotspots, '
    'regional hierarchy, and curriculum skill IDs.',
  );
}

void _verifyLegacyCatalog() {
  _expect(legacyRegionCatalog.length == 7, 'seven legacy regions are required');
  final regionIds = <String>{};
  final legacyIds = <String>{};
  final assetKeys = <String>{};
  for (var index = 0; index < legacyRegionCatalog.length; index += 1) {
    final region = legacyRegionCatalog[index];
    final expectedPrerequisite = index == 0
        ? null
        : legacyRegionCatalog[index - 1].id;
    _expect(region.number == index + 1, '${region.id} order mismatch');
    _expect(
      region.prerequisiteRegionId == expectedPrerequisite,
      '${region.id} prerequisite mismatch',
    );
    final regionNumber = (index + 1).toString().padLeft(2, '0');
    _expect(
      region.accessGateStageId == 'r$regionNumber-c03-s10' &&
          region.finalStageId == 'r$regionNumber-c06-s10',
      '${region.id} must separate core access from mastery completion',
    );
    _expect(regionIds.add(region.id), '${region.id} is duplicated');
    _expect(legacyIds.add(region.legacyId), '${region.legacyId} is duplicated');
    _expect(
      region.hotspot.hasNormalizedValues &&
          region.hotspot.left >= 0 &&
          region.hotspot.top >= 0 &&
          region.hotspot.right <= 1 &&
          region.hotspot.bottom <= 1 &&
          region.hotspot.contains(
            x: region.hotspot.centerX,
            y: region.hotspot.centerY,
          ),
      '${region.id} hotspot must be selectable inside the normalized map',
    );
    _expect(
      region.visualAssets.values.every(
        (key) => key.isNotEmpty && assetKeys.add(key),
      ),
      '${region.id} visual keys must be non-empty and globally unique',
    );
    _expect(
      region.featuredCharacterIds.isNotEmpty &&
          region.featuredCharacterIds.toSet().length ==
              region.featuredCharacterIds.length &&
          region.featuredCharacterIds.every(_isLegacyCharacterId),
      '${region.id} featured character IDs are invalid',
    );
    _expect(
      legacyRegionById(region.id) == region &&
          legacyRegionById(region.legacyId) == region,
      '${region.id} lookup should accept renewal and legacy IDs',
    );
  }
  _expect(
    {
          for (final region in legacyRegionCatalog)
            ...region.featuredCharacterIds,
        }.length ==
        26,
    'all 26 legacy characters should be assigned to at least one region',
  );
}

void _verifyRegionalCampaign() {
  const validator = CampaignValidator();
  final prototypeMetadata = RegionMetadata(
    id: 'region-prototype',
    legacyId: 'T_PROTOTYPE',
    number: 1,
    title: '프로토타입 지역',
    description: '리전 계층 검증용 지역입니다.',
    prerequisiteRegionId: null,
    finalStageId: verticalSliceStage.id,
    featuredCharacterIds: const ['CHAR_A'],
    visualAssets: const RegionVisualAssetKeys(
      worldOverlay: 'prototype.world-overlay',
      regionBackground: 'prototype.region-background',
      mapMarker: 'prototype.map-marker',
      completionBadge: 'prototype.completion-badge',
    ),
    hotspot: const NormalizedMapHotspot(
      centerX: 0.5,
      centerY: 0.5,
      width: 0.2,
      height: 0.2,
    ),
  );
  final regionalCampaign = CampaignDefinition.regional(
    id: 'regional-prototype',
    version: 1,
    regions: [prototypeMetadata.bindChapters(prototypeCampaign.chapters)],
  );
  final report = validator.validate(
    campaign: regionalCampaign,
    puzzles: samplePuzzles,
    knownCharacterIds: const ['CHAR_A'],
  );
  _expect(
    report.isValid && report.warnings.isEmpty,
    'regional prototype should be valid: '
    '${report.errors.map((issue) => issue.message).join(' | ')}',
  );
  _expect(
    regionalCampaign.regions.single.stages.single == verticalSliceStage &&
        regionalCampaign.chapters.single == prototypeCampaign.chapters.single &&
        regionalCampaign.stages.single == verticalSliceStage &&
        regionalCampaign.regionById('region-prototype') ==
            regionalCampaign.regions.single &&
        regionalCampaign.regionById('T_PROTOTYPE') ==
            regionalCampaign.regions.single &&
        regionalCampaign.regions.single.stageById(verticalSliceStage.id) ==
            verticalSliceStage &&
        regionalCampaign.regions.single.isFinalStage(verticalSliceStage.id) &&
        regionalCampaign.regions.single.isAccessGateStage(
          verticalSliceStage.id,
        ),
    'flattened chapter and stage compatibility views should be preserved',
  );

  final invalidMetadata = RegionMetadata(
    id: 'region-invalid',
    legacyId: 'T_INVALID',
    number: 2,
    title: '잘못된 지역',
    description: 'validator failure fixture',
    prerequisiteRegionId: 'missing-region',
    finalStageId: 'missing-stage',
    featuredCharacterIds: const ['CHAR_UNKNOWN'],
    visualAssets: const RegionVisualAssetKeys(
      worldOverlay: '',
      regionBackground: 'invalid.region-background',
      mapMarker: 'invalid.map-marker',
      completionBadge: 'invalid.completion-badge',
    ),
    hotspot: const NormalizedMapHotspot(
      centerX: 1.1,
      centerY: 0.5,
      width: 0.2,
      height: 0.2,
    ),
  );
  final invalidReport = validator.validate(
    campaign: CampaignDefinition.regional(
      id: 'invalid-regional-prototype',
      version: 1,
      regions: [invalidMetadata.bindChapters(prototypeCampaign.chapters)],
    ),
    puzzles: samplePuzzles,
    knownCharacterIds: const ['CHAR_A'],
  );
  const expectedCodes = {
    CampaignIssueCode.invalidRegionOrder,
    CampaignIssueCode.invalidRegionPrerequisite,
    CampaignIssueCode.invalidRegionFinalStage,
    CampaignIssueCode.invalidRegionAccessGate,
    CampaignIssueCode.invalidRegionHotspot,
    CampaignIssueCode.invalidRegionAssetKey,
    CampaignIssueCode.unknownFeaturedCharacterId,
  };
  final actualCodes = invalidReport.errors.map((issue) => issue.code).toSet();
  _expect(
    actualCodes.containsAll(expectedCodes),
    'invalid regional metadata should be rejected by every region guard',
  );
}

bool _isLegacyCharacterId(String id) {
  if (!RegExp(r'^CHAR_[A-Z]$').hasMatch(id)) {
    return false;
  }
  return id.codeUnitAt(id.length - 1) >= 'A'.codeUnitAt(0) &&
      id.codeUnitAt(id.length - 1) <= 'Z'.codeUnitAt(0);
}

void _expect(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}
