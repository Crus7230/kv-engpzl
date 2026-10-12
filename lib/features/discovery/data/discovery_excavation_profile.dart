import '../../campaign/domain/campaign_models.dart';
import '../domain/discovery_models.dart';

/// Delivery lessons use source-linked, already familiar mathematics. The
/// immutable v3 campaign/fixtures remain available for checkpoint replay.
class DiscoveryExcavationProfile {
  const DiscoveryExcavationProfile({
    this.ice = false,
    this.falling = false,
    this.colorGoals = const {},
    this.dense = false,
  });

  final bool ice;
  final bool falling;
  final Map<String, int> colorGoals;
  final bool dense;
  bool get isActive => ice || falling || colorGoals.isNotEmpty;

  static DiscoveryExcavationProfile forStage(StageDefinition stage) {
    if (!stage.id.startsWith('r01-') && !stage.id.startsWith('r02-')) {
      return const DiscoveryExcavationProfile();
    }
    final chapter = int.parse(stage.chapterId.substring(5));
    if (chapter < 4 || chapter == 4 && stage.number < 2) {
      return const DiscoveryExcavationProfile();
    }
    if (chapter == 4) {
      return DiscoveryExcavationProfile(
        ice: true,
        falling: stage.number >= 4 && stage.number < 8,
        colorGoals: stage.number >= 8 ? const {'B': 9} : const {},
        dense: true,
      );
    }
    return DiscoveryExcavationProfile(
      ice: true,
      falling: true,
      colorGoals: chapter == 5 ? const {'B': 12} : const {'B': 20, 'E': 12},
      dense: true,
    );
  }

  static DiscoveryBoardConfig boardFor(
    StageDefinition stage,
    double width,
    double height,
  ) {
    if (forStage(stage).dense) {
      return width >= 800 && height >= 360
          ? DiscoveryBoardConfig.densePhone
          : DiscoveryBoardConfig.standardPhone;
    }
    return width < 720 || height < 400
        ? DiscoveryBoardConfig.compactPhone
        : DiscoveryBoardConfig.standardPhone;
  }

  static BoardLayoutVariant variantFor(
    StageDefinition stage,
    DiscoveryBoardConfig config,
  ) {
    final base = stage.boardVariants.supports(config)
        ? stage.boardVariants.variantFor(config)
        : stage.boardVariants.variants.last;
    if (config.rows != config.columns ||
        config.rows < 5 ||
        config.rows > 7 ||
        config.rows == 7 && !forStage(stage).dense) {
      throw ArgumentError('Unsupported excavation board dimensions.');
    }
    return BoardLayoutVariant(
      config: config,
      fixtureId:
          '${base.fixtureId}-${config.rows}x${config.columns}-excavation4',
      seed: base.seed,
      // Like v3, construction replays the complete route before returning it.
      // This is not a claim that the regression suite or human tuning ran.
      isVerified: base.isVerified,
    );
  }
}
