import '../domain/discovery_models.dart';

/// Deterministic three-step board used by the first discovery tutorial.
///
/// Keeping this fixture outside the Flutter adapter lets the same board and
/// refill sequence be exercised by the pure Dart verifier.
class DiscoveryTutorialFixture {
  const DiscoveryTutorialFixture._();

  static const steps = [
    (
      from: DiscoveryPosition(0, 1),
      to: DiscoveryPosition(1, 1),
      targetId: 'p1-times',
    ),
    (
      from: DiscoveryPosition(2, 1),
      to: DiscoveryPosition(3, 1),
      targetId: 'p1-plus',
    ),
    (
      from: DiscoveryPosition(3, 3),
      to: DiscoveryPosition(3, 4),
      targetId: 'p1-n2',
    ),
  ];

  static const List<List<String>> _gemKeys = [
    ['A', 'B', 'A', 'C', 'D', 'E', 'B'],
    ['B', 'A', 'B', 'D', 'E', 'C', 'D'],
    ['C', 'D', 'C', 'E', 'A', 'B', 'E'],
    ['D', 'C', 'D', 'A', 'B', 'C', 'A'],
    ['E', 'C', 'E', 'B', 'A', 'D', 'B'],
    ['C', 'E', 'A', 'C', 'D', 'E', 'C'],
  ];

  static const List<String> _refillKeys = [
    'A',
    'B',
    'C',
    'B',
    'C',
    'D',
    'A',
    'B',
    'C',
    'B',
    'C',
    'D',
    'A',
    'B',
    'C',
  ];

  static bool supports(DiscoveryBoardConfig config) =>
      config.rows >= 5 &&
      config.columns >= 5 &&
      config.rows <= _gemKeys.length &&
      config.columns <= _gemKeys.first.length;

  static DiscoveryBoard build({
    required DiscoveryBoardConfig config,
    required DiscoveryPiece timesTarget,
    required DiscoveryPiece plusTarget,
    required DiscoveryPiece twoTarget,
  }) {
    if (!supports(config)) {
      throw ArgumentError.value(
        config,
        'config',
        'The tutorial fixture supports boards from 5x5 to 6x7.',
      );
    }
    return DiscoveryBoard.fromRows(
      [
        for (var row = 0; row < config.rows; row += 1)
          [
            for (var column = 0; column < config.columns; column += 1)
              DiscoveryPiece.gem(
                id: 'initial-$row-$column',
                gemKey: _gemKeys[row][column],
              ),
          ],
      ],
      config: config,
      buriedTargets: {
        const DiscoveryPosition(0, 0): timesTarget,
        const DiscoveryPosition(2, 0): plusTarget,
        const DiscoveryPosition(4, 4): twoTarget,
      },
    );
  }

  static List<DiscoveryPiece> refillPieces({
    String idPrefix = 'controlled',
  }) => [
    for (var index = 0; index < _refillKeys.length; index += 1)
      DiscoveryPiece.gem(id: '$idPrefix-$index', gemKey: _refillKeys[index]),
  ];
}
