/// A presentation definition for a region's restoration scene.
///
/// Restoration does not grant campaign access or learning evidence. Those
/// decisions remain the responsibility of the campaign completion service.
class GardenDefinition {
  GardenDefinition({
    required this.id,
    required this.regionId,
    required this.title,
    required this.backgroundAsset,
    required Iterable<RestorationNode> restorationNodes,
    required Iterable<String> featuredCharacterIds,
    Iterable<GardenProjectScene> projectScenes = const [],
  }) : restorationNodes = List.unmodifiable(restorationNodes),
       featuredCharacterIds = List.unmodifiable(featuredCharacterIds),
       projectScenes = List.unmodifiable(projectScenes);

  final String id;
  final String regionId;
  final String title;
  final String? backgroundAsset;
  final List<RestorationNode> restorationNodes;
  final List<String> featuredCharacterIds;
  final List<GardenProjectScene> projectScenes;

  GardenProjectScene? sceneByChapterId(String chapterId) {
    for (final scene in projectScenes) {
      if (scene.chapterId == chapterId) return scene;
    }
    return null;
  }

  RestorationNode? nodeById(String nodeId) {
    for (final node in restorationNodes) {
      if (node.id == nodeId) return node;
    }
    return null;
  }
}

class RestorationNode {
  const RestorationNode({
    required this.id,
    required this.regionId,
    required this.chapterId,
    required this.requiredStageId,
    required this.title,
    required this.chapterNumber,
    required this.milestone,
    this.decorationIds = gardenDecorationIds,
    this.sceneId,
    this.characterId,
    this.storyText,
  });

  final String id;
  final String regionId;
  final String? chapterId;
  final String requiredStageId;
  final String title;
  final int chapterNumber;
  final int milestone;
  final List<String> decorationIds;
  final String? sceneId;
  final String? characterId;
  final String? storyText;

  /// Preserve the story keys already written by the first Renewal slice.
  String get storyId =>
      id == 'r01-demo-meadow' ? 'r01-demo-story' : '$id-story';
}

/// A chapter's restoration project. Existing background art is composited with
/// scene-specific environment layers rather than requiring six bitmap packs.
class GardenProjectScene {
  const GardenProjectScene({
    required this.id,
    required this.chapterId,
    required this.title,
    required this.description,
    required this.environmentLayerId,
    required this.characterId,
  });
  final String id;
  final String chapterId;
  final String title;
  final String description;
  final String environmentLayerId;
  final String characterId;
}

class GardenCharacterStory {
  const GardenCharacterStory({
    required this.id,
    required this.characterId,
    required this.title,
    required this.text,
    this.requiredStageId,
  });
  final String id;
  final String characterId;
  final String title;
  final String text;
  final String? requiredStageId;
}

const gardenDecorationIds = ['wildflowers', 'stone-path', 'herbs'];

String gardenDecorationLabel(String id) => switch (id) {
  'stone-path' => '작은 돌길',
  'herbs' => '향기로운 허브',
  _ => '들꽃 화단',
};
