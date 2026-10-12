/// Original profile fields are inherited verbatim from CharacterData.kt.
/// Expedition roles belong to Renewal and never replace the original facts.
class CompanionProfile {
  const CompanionProfile({
    required this.id,
    required this.name,
    required this.imageName,
    required this.mbti,
    required this.favoriteFood,
    required this.favoriteMathField,
    required this.favoriteNumber,
  });

  final String id;
  final String name;
  final String imageName;
  final String mbti;
  final String favoriteFood;
  final String favoriteMathField;
  final String favoriteNumber;
  String get letter => id.substring('CHAR_'.length);

  String? get expeditionAsset => switch (id) {
    'CHAR_D' => 'assets/expedition/delta.png',
    'CHAR_J' => 'assets/expedition/juliett.png',
    _ => null,
  };

  String get legacyAsset => 'assets/legacy/char-${letter.toLowerCase()}.png';
}

/// The order follows each territory's exploration story, not the alphabet.
/// Future territories remain planned until their playable content is authored.
class CompanionRecruitment {
  const CompanionRecruitment({
    required this.characterId,
    required this.regionId,
    required this.regionNumber,
    required this.order,
    required this.expeditionRole,
    required this.location,
    required this.title,
    required this.story,
    required this.dialogue,
    this.requiredStageId,
    this.available = false,
  });

  final String characterId;
  final String regionId;
  final int regionNumber;
  final int order;
  final String expeditionRole;
  final String location;
  final String title;
  final String story;
  final String dialogue;
  final String? requiredStageId;
  final bool available;

  /// Separate from all existing garden and character-story keys.
  String get arrivalStoryId => 'expedition-join-$characterId';

  String get requirementLabel {
    if (!available) return 'R$regionNumber 탐험 · 업데이트 예정';
    if (requiredStageId == null) return '계산의 평원에서 처음 만나요';
    final chapter = int.tryParse(
      requiredStageId!.split('-c').last.split('-').first,
    );
    return 'R$regionNumber C${chapter?.toString().padLeft(2, '0') ?? '?'} 완료 후 구조';
  }
}
