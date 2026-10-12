import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/discovery/domain/discovery_engine.dart';
import 'package:kvm/features/discovery/domain/discovery_hint_solver.dart';
import 'package:kvm/features/discovery/domain/discovery_models.dart';
import 'package:kvm/features/discovery/domain/discovery_piece_source.dart';
import 'package:kvm/features/discovery/domain/discovery_power_resolver.dart';

const _from = DiscoveryPosition(2, 1);
const _to = DiscoveryPosition(2, 2);
const _keys = ['A', 'B', 'C', 'D', 'E'];

DiscoveryBoard _board({
  Map<DiscoveryPosition, String> colors = const {},
  Map<DiscoveryPosition, DiscoveryLinePower> powers = const {},
  Map<DiscoveryPosition, int> blockers = const {},
  int targetLayers = 1000,
}) => DiscoveryBoard.fromRows(
  [
    for (var r = 0; r < 5; r++)
      [
        for (var c = 0; c < 5; c++)
          DiscoveryPiece(
            id: '$r-$c',
            kind: DiscoveryPieceKind.gem,
            label: colors[DiscoveryPosition(r, c)] ?? _keys[(r + c) % 5],
            matchKey: colors[DiscoveryPosition(r, c)] ?? _keys[(r + c) % 5],
            linePower: powers[DiscoveryPosition(r, c)],
          ),
      ],
  ],
  buriedTargets: {
    const DiscoveryPosition(4, 4): const DiscoveryPiece.numberToken(
      id: 'target',
      label: '2',
    ),
  },
  sealLayers: {const DiscoveryPosition(4, 4): targetLayers},
  blockerLayers: blockers,
);

DiscoveryEngine _engine(
  DiscoveryBoard board, {
  bool renewed = true,
  int blockerGoal = 0,
}) => DiscoveryEngine(
  initialBoard: board,
  requiredTargetIds: const ['target'],
  moves: 20,
  enableLinePowers: true,
  enableBurstPowers: renewed,
  enableColorPowers: renewed,
  enablePowerCombinations: renewed,
  requiredBlockerClears: blockerGoal,
  refillSource: SeededGemPieceSource(seed: 1, gemKeys: _keys),
);

void main() {
  const resolver = DiscoveryPowerResolver(
    enableBurst: true,
    enableColor: true,
    enableCombinations: true,
  );

  test('four straight gems create one directional power at the moved gem', () {
    final positions = {for (var c = 0; c < 4; c++) DiscoveryPosition(2, c)};
    final board = _board(
      colors: {
        for (final p in positions) p: 'A',
        const DiscoveryPosition(2, 4): 'B',
      },
    );
    final result = resolver.resolve(board, positions, const [_to]);
    expect(result.created[_to]!.linePower, DiscoveryLinePower.row);
    expect(result.created.length, 1);
  });

  test('five straight gems take priority over an intersecting T shape', () {
    final positions = {
      for (var c = 0; c < 5; c++) DiscoveryPosition(2, c),
      const DiscoveryPosition(1, 2),
      const DiscoveryPosition(3, 2),
    };
    final board = _board(colors: {for (final p in positions) p: 'A'});
    final result = resolver.resolve(board, positions, const [_to]);
    expect(result.created.length, 1);
    expect(result.created[_to]!.linePower, DiscoveryLinePower.color);
  });

  for (final shape in ['L', 'T']) {
    test('$shape match creates one area power', () {
      final positions = shape == 'T'
          ? {
              const DiscoveryPosition(2, 1),
              _to,
              const DiscoveryPosition(2, 3),
              const DiscoveryPosition(1, 2),
              const DiscoveryPosition(3, 2),
            }
          : {
              const DiscoveryPosition(1, 1),
              const DiscoveryPosition(1, 2),
              const DiscoveryPosition(1, 3),
              const DiscoveryPosition(2, 1),
              const DiscoveryPosition(3, 1),
            };
      final anchor = shape == 'T' ? _to : const DiscoveryPosition(1, 1);
      final result = resolver.resolve(
        _board(colors: {for (final p in positions) p: 'A'}),
        positions,
        [anchor],
      );
      expect(result.created[anchor]!.linePower, DiscoveryLinePower.burst);
      expect(result.created.length, 1);
    });
  }

  test('legacy five-match retains its old line-power rule', () {
    final board = _board(
      colors: {
        for (var c = 0; c < 5; c++) DiscoveryPosition(0, c): c == 2 ? 'B' : 'A',
        const DiscoveryPosition(1, 2): 'A',
      },
    );
    final turn = _engine(
      board,
      renewed: false,
    ).swap(const DiscoveryPosition(1, 2), const DiscoveryPosition(0, 2));
    expect(turn.isAccepted, isTrue);
    expect(
      turn.cascades.first.createdPowers.single.direction,
      DiscoveryLinePower.row,
    );
    final upgraded = _engine(
      board,
    ).swap(const DiscoveryPosition(1, 2), const DiscoveryPosition(0, 2));
    expect(
      upgraded.cascades.first.createdPowers.single.direction,
      DiscoveryLinePower.color,
    );
  });

  const combinations = [
    (
      DiscoveryLinePower.row,
      DiscoveryLinePower.column,
      DiscoveryPowerCombination.lineLine,
    ),
    (
      DiscoveryLinePower.row,
      DiscoveryLinePower.burst,
      DiscoveryPowerCombination.lineBurst,
    ),
    (
      DiscoveryLinePower.burst,
      DiscoveryLinePower.burst,
      DiscoveryPowerCombination.burstBurst,
    ),
    (DiscoveryLinePower.color, null, DiscoveryPowerCombination.colorGem),
    (
      DiscoveryLinePower.color,
      DiscoveryLinePower.row,
      DiscoveryPowerCombination.colorLine,
    ),
    (
      DiscoveryLinePower.color,
      DiscoveryLinePower.burst,
      DiscoveryPowerCombination.colorBurst,
    ),
    (
      DiscoveryLinePower.color,
      DiscoveryLinePower.color,
      DiscoveryPowerCombination.colorColor,
    ),
  ];
  for (final (first, second, combination) in combinations) {
    test('${combination.name}: bounded, unique hits and one pair event', () {
      final board = _board(
        powers: {_from: first, if (second != null) _to: second},
      );
      final result = resolver.resolve(
        board,
        {_from, _to},
        const [],
        from: _from,
        to: _to,
      );
      expect(
        result.activations.where((p) => p.combination == combination).length,
        1,
      );
      expect(result.hits.every(board.contains), isTrue);
      expect(
        result.activations.expand((p) => p.affectedPositions).toSet(),
        result.hits,
      );
      expect(result.hits, containsAll([_from, _to]));
      if (combination == DiscoveryPowerCombination.lineLine) {
        expect(result.hits.length, 9);
        expect(result.hits.every((p) => p.row == 2 || p.column == 2), isTrue);
      }
      if (combination == DiscoveryPowerCombination.lineBurst)
        expect(result.hits.length, 21);
      if (combination == DiscoveryPowerCombination.burstBurst ||
          combination == DiscoveryPowerCombination.colorColor)
        expect(result.hits.length, 25);
      final engine = _engine(board);
      final turn = engine.swap(_from, _to);
      expect(turn.isAccepted, isTrue);
      expect(
        turn.cascades.first.activatedPowers
            .where((p) => p.combination == combination)
            .length,
        1,
      );
      expect(
        engine.state.combinationActivations,
        combination == DiscoveryPowerCombination.colorGem ? 0 : 1,
      );
    });
  }

  test('area power at the edge stays inside the board', () {
    const corner = DiscoveryPosition(0, 0);
    final board = _board(powers: {corner: DiscoveryLinePower.burst});
    final result = resolver.resolve(board, {corner}, const []);
    expect(result.hits.length, 4);
    expect(result.activations.single.affectedPositions.toSet(), result.hits);
  });

  test(
    'color conversion events include the partner footprint and chain effects',
    () {
      final board = _board(
        powers: {_from: DiscoveryLinePower.color, _to: DiscoveryLinePower.row},
      );
      final result = resolver.resolve(
        board,
        {_from, _to},
        const [],
        from: _from,
        to: _to,
      );
      expect(
        result.hits,
        containsAll([for (var c = 0; c < 5; c++) DiscoveryPosition(2, c)]),
      );
      expect(
        result.activations.where((p) => p.combination == null),
        isNotEmpty,
      );
    },
  );

  test('power footprints damage each two-layer seal only once per cascade', () {
    final board = _board(
      powers: {_from: DiscoveryLinePower.color, _to: DiscoveryLinePower.color},
      targetLayers: 2,
    );
    final turn = _engine(board).swap(_from, _to);
    final first = turn.cascades.first;
    expect(first.sealHits.single.layersBefore, 2);
    expect(first.sealHits.single.layersAfter, 1);
    expect(first.discoveredTargets, isEmpty);
  });

  test(
    'later cascades cannot mutate a previously returned state counter map',
    () {
      final counts = {DiscoveryLinePower.burst: 1};
      final state = DiscoveryGameState(
        board: _board(),
        movesRemaining: 1,
        requiredTargetIds: const ['target'],
        collectedTargets: const [],
        hasAvailableMove: true,
        powerActivations: counts,
      );
      counts[DiscoveryLinePower.burst] = 99;
      expect(state.powerActivations[DiscoveryLinePower.burst], 1);
      expect(
        () => state.powerActivations[DiscoveryLinePower.burst] = 2,
        throwsUnsupportedError,
      );
    },
  );

  test('a chained power is activated once even at intersecting footprints', () {
    const third = DiscoveryPosition(2, 4);
    final board = _board(
      powers: {
        _from: DiscoveryLinePower.row,
        _to: DiscoveryLinePower.column,
        third: DiscoveryLinePower.burst,
      },
    );
    final result = resolver.resolve(
      board,
      {_from, _to},
      const [],
      from: _from,
      to: _to,
    );
    expect(result.activations.where((p) => p.position == third).length, 1);
  });

  test('covered gems cannot swap and hints do not propose them', () {
    final board = _board(
      blockers: {_to: 2},
      powers: {_from: DiscoveryLinePower.row},
    );
    final engine = _engine(board, blockerGoal: 1);
    final turn = engine.swap(_from, _to);
    expect(turn.status, DiscoverySwapStatus.blocked);
    expect(engine.state.movesRemaining, 20);
    expect(engine.state.board.pieceAt(_to), board.pieceAt(_to));
    expect(
      DiscoveryBoardHintSolver.legalSwaps(
        board,
      ).any((move) => move.from == _to || move.to == _to),
      isFalse,
    );
  });

  test('multiple adjacent clear cells damage a cover once per cascade', () {
    const cover = DiscoveryPosition(1, 1);
    final board = _board(
      colors: {
        const DiscoveryPosition(2, 0): 'A',
        const DiscoveryPosition(2, 1): 'A',
        const DiscoveryPosition(2, 2): 'B',
        const DiscoveryPosition(2, 3): 'C',
        const DiscoveryPosition(3, 2): 'A',
      },
      blockers: {cover: 2},
    );
    final turn = _engine(board).swap(const DiscoveryPosition(3, 2), _to);
    expect(turn.isAccepted, isTrue);
    final step = turn.cascades.first;
    final hit = step.blockerHits.singleWhere((hit) => hit.position == cover);
    expect((hit.layersBefore, hit.layersAfter), (2, 1));
    expect(step.boardAfterFall.pieceAt(cover), board.pieceAt(cover));
    expect(step.boardAfterFall.cellAt(cover).blockerLayers, 1);
  });

  test('covers divide gravity into independent column segments', () {
    const cover = DiscoveryPosition(2, 2);
    final board = _board(
      blockers: {cover: 2},
      powers: {const DiscoveryPosition(0, 0): DiscoveryLinePower.row},
    );
    final turn = _engine(
      board,
    ).swap(const DiscoveryPosition(0, 0), const DiscoveryPosition(0, 1));
    final fall = turn.cascades.first.boardAfterFall;
    expect(fall.pieceAt(cover), board.pieceAt(cover));
    expect(
      fall.pieceAt(const DiscoveryPosition(3, 2)),
      board.pieceAt(const DiscoveryPosition(3, 2)),
    );
    expect(
      fall.pieceAt(const DiscoveryPosition(4, 2)),
      board.pieceAt(const DiscoveryPosition(4, 2)),
    );
  });

  test('all tokens alone cannot bypass a required cover', () {
    final engine = DiscoveryEngine(
      initialBoard: _board(blockers: {_to: 1}),
      requiredTargetIds: const [],
      moves: 10,
      requiredBlockerClears: 1,
      refillSource: SeededGemPieceSource(seed: 1, gemKeys: _keys),
    );
    expect(engine.state.isCompleted, isFalse);
  });
}
