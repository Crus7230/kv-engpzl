import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/discovery/domain/discovery_engine.dart';
import 'package:kvm/features/discovery/domain/discovery_hint_solver.dart';
import 'package:kvm/features/discovery/domain/discovery_models.dart';
import 'package:kvm/features/discovery/domain/discovery_piece_source.dart';

const _keys = ['A', 'B', 'C', 'D', 'E'];
const _rows = [
  ['A', 'A', 'B', 'A', 'C'],
  ['D', 'E', 'A', 'B', 'D'],
  ['B', 'C', 'D', 'E', 'A'],
  ['C', 'D', 'E', 'A', 'B'],
  ['E', 'B', 'C', 'D', 'E'],
];

DiscoveryBoard _board({bool transpose = false, int layers = 2}) =>
    DiscoveryBoard.fromRows(
      [
        for (var row = 0; row < 5; row++)
          [
            for (var column = 0; column < 5; column++)
              DiscoveryPiece.gem(
                id: '$row-$column',
                gemKey: transpose ? _rows[column][row] : _rows[row][column],
              ),
          ],
      ],
      buriedTargets: {
        const DiscoveryPosition(0, 0): const DiscoveryPiece.operatorToken(
          id: 'plus',
          label: '+',
        ),
      },
      sealLayers: {const DiscoveryPosition(0, 0): layers},
    );

DiscoveryEngine _engine({
  bool transpose = false,
  bool powers = true,
  int layers = 2,
}) => DiscoveryEngine(
  initialBoard: _board(transpose: transpose, layers: layers),
  requiredTargetIds: const ['plus'],
  moves: 10,
  enableLinePowers: powers,
  requiredLinePowerActivations: powers ? 1 : 0,
  refillSource: SeededGemPieceSource(seed: 1, gemKeys: _keys),
);

void main() {
  test('two layers stay fixed while gems fall and a hit removes only one', () {
    final engine = _engine(powers: false);
    final turn = engine.swap(
      const DiscoveryPosition(1, 2),
      const DiscoveryPosition(0, 2),
    );
    expect(turn.isAccepted, isTrue);
    expect(turn.newlyDiscoveredTargets, isEmpty);
    expect(turn.cascades.first.sealHits.single.layersBefore, 2);
    expect(turn.cascades.first.sealHits.single.layersAfter, 1);
    expect(
      engine.state.board.cellAt(const DiscoveryPosition(0, 0)).sealLayers,
      1,
    );
    expect(
      engine.state.board.cellAt(const DiscoveryPosition(0, 0)).buriedTarget!.id,
      'plus',
    );
    expect(engine.state.collectedTargets, isEmpty);
  });

  for (final transpose in [false, true]) {
    test(
      '${transpose ? 'column' : 'row'} power creation, movement and activation',
      () {
        final engine = _engine(transpose: transpose);
        final first = engine.swap(
          transpose
              ? const DiscoveryPosition(2, 1)
              : const DiscoveryPosition(1, 2),
          transpose
              ? const DiscoveryPosition(2, 0)
              : const DiscoveryPosition(0, 2),
        );
        expect(first.isAccepted, isTrue);
        expect(
          first.cascades.first.createdPowers.single.direction,
          transpose ? DiscoveryLinePower.column : DiscoveryLinePower.row,
        );
        expect(engine.state.linePowerActivations, 0);
        expect(engine.state.isCompleted, isFalse);
        final board = engine.state.board;
        final position = board.positions.firstWhere(
          (p) => board.pieceAt(p)!.linePower != null,
        );
        final neighbor = transpose
            ? DiscoveryPosition(
                position.row == 0 ? 1 : position.row - 1,
                position.column,
              )
            : DiscoveryPosition(
                position.row,
                position.column == 4 ? 3 : position.column + 1,
              );
        expect(
          DiscoveryBoardHintSolver.legalSwaps(board).any(
            (swap) =>
                swap.from == position && swap.to == neighbor ||
                swap.to == position && swap.from == neighbor,
          ),
          isTrue,
        );
        final second = engine.swap(position, neighbor);
        expect(second.isAccepted, isTrue);
        expect(second.cascades.first.activatedPowers, isNotEmpty);
        expect(
          second.cascades.first.clearedPieces.length,
          greaterThanOrEqualTo(5),
        );
        expect(engine.state.linePowerActivations, greaterThanOrEqualTo(1));
        expect(engine.state.collectedTargetIds, contains('plus'));
        expect(engine.state.isCompleted, isTrue);
        expect(engine.state.board.buriedTargets, isEmpty);
      },
    );
  }

  test('unsupported activation count cannot silently enable powers', () {
    expect(
      () => DiscoveryEngine(
        initialBoard: _board(),
        requiredTargetIds: const ['plus'],
        moves: 10,
        refillSource: SeededGemPieceSource(seed: 1),
        requiredLinePowerActivations: 1,
      ),
      throwsArgumentError,
    );
  });

  test(
    'chained row and column powers hit a crossing seal once per cascade',
    () {
      final board = DiscoveryBoard.fromRows(
        [
          for (var row = 0; row < 5; row++)
            [
              for (var column = 0; column < 5; column++)
                DiscoveryPiece(
                  id: '$row-$column',
                  kind: DiscoveryPieceKind.gem,
                  label: _rows[row][column],
                  matchKey: _rows[row][column],
                  linePower: row == 2 && column == 1
                      ? DiscoveryLinePower.row
                      : row == 2 && column == 4
                      ? DiscoveryLinePower.column
                      : null,
                ),
            ],
        ],
        buriedTargets: {
          const DiscoveryPosition(2, 4): const DiscoveryPiece.numberToken(
            id: 'two',
            label: '2',
          ),
        },
        sealLayers: {const DiscoveryPosition(2, 4): 2},
      );
      final engine = DiscoveryEngine(
        initialBoard: board,
        requiredTargetIds: const ['two'],
        moves: 10,
        enableLinePowers: true,
        refillSource: SeededGemPieceSource(seed: 1, gemKeys: _keys),
      );
      final turn = engine.swap(
        const DiscoveryPosition(2, 1),
        const DiscoveryPosition(2, 2),
      );
      expect(turn.isAccepted, isTrue);
      expect(turn.cascades.first.activatedPowers.length, 2);
      final hits = turn.cascades.first.sealHits.where(
        (hit) => hit.position == const DiscoveryPosition(2, 4),
      );
      expect(hits.length, 1);
      expect(hits.single.layersAfter, 1);
    },
  );

  test('single-layer legacy engine never creates a power on a four match', () {
    final engine = _engine(powers: false, layers: 1);
    final turn = engine.swap(
      const DiscoveryPosition(1, 2),
      const DiscoveryPosition(0, 2),
    );
    expect(turn.isAccepted, isTrue);
    expect(turn.cascades.expand((cascade) => cascade.createdPowers), isEmpty);
    expect(engine.state.isCompleted, isTrue);
  });
}
