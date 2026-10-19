import 'dart:io';

import '../lib/features/discovery/domain/discovery_engine.dart';
import '../lib/features/discovery/domain/discovery_hint_solver.dart';
import '../lib/features/discovery/domain/discovery_models.dart';
import '../lib/features/discovery/domain/discovery_piece_source.dart';
import '../lib/features/discovery/domain/discovery_power_resolver.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

DiscoveryBoard board({
  List<String> rows = const ['ABACD', 'AABDE', 'BCDEA', 'CDEAB', 'DEABC'],
  Map<DiscoveryPosition, DiscoveryLinePower> powers = const {},
  Map<DiscoveryPosition, int> blockers = const {},
  int layers = 1,
}) => DiscoveryBoard.fromRows(
  [
    for (var r = 0; r < rows.length; r++)
      [
        for (var c = 0; c < rows[r].length; c++)
          DiscoveryPiece(
            id: '$r-$c',
            kind: DiscoveryPieceKind.gem,
            label: rows[r][c],
            matchKey: rows[r][c],
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
  sealLayers: {const DiscoveryPosition(4, 4): layers},
  blockerLayers: blockers,
);

DiscoveryEngine engine(DiscoveryBoard initial, {bool enabled = true}) =>
    DiscoveryEngine(
      initialBoard: initial,
      requiredTargetIds: const ['target'],
      moves: 20,
      enableSeekerPowers: enabled,
      refillSource: SeededGemPieceSource(
        seed: 9,
        gemKeys: const ['A', 'B', 'C', 'D', 'E'],
      ),
    );

void main() {
  const from = DiscoveryPosition(0, 1), to = DiscoveryPosition(0, 2);
  final original = board();
  final before = original.visiblePieces.map((p) => p.id).join(',');
  check(discoverySquareMatches(original).isEmpty, 'No square before a move');
  final old = engine(original, enabled: false);
  check(
    !old.swap(from, to).isAccepted && old.state.movesRemaining == 20,
    'Legacy rules reject square-only swaps without consuming a move',
  );
  final live = engine(original);
  final turn = live.swap(from, to);
  check(
    turn.isAccepted && turn.state.movesRemaining == 19,
    'Square consumes one legal move',
  );
  check(
    turn.cascades.first.createdPowers.length == 1 &&
        turn.cascades.first.createdPowers.single.direction ==
            DiscoveryLinePower.seeker,
    'Square creates exactly one seeker',
  );
  check(
    turn.cascades.first.clearedPieces.length == 4,
    'The four square carriers clear',
  );
  check(
    turn.cascades.first.activatedPowers.isEmpty,
    'New seeker does not auto-fire in creation cascade',
  );
  check(
    original.visiblePieces.map((p) => p.id).join(',') == before,
    'Resolver never mutates original board',
  );
  check(
    DiscoveryBoardHintSolver.legalSwaps(
      original,
      includeSquares: true,
    ).any((m) => m.from == from && m.to == to),
    'Solver discovers square-only moves',
  );
  check(
    !DiscoveryBoardHintSolver.legalSwaps(
      original,
    ).any((m) => m.from == from && m.to == to),
    'Legacy solver remains unchanged',
  );
  final tokens = DiscoveryBoard.fromCells([
    for (final row in original.cells)
      [
        for (final cell in row)
          cell.piece!.matchKey == 'A'
              ? cell.withPiece(
                  DiscoveryPiece.numberToken(
                    id: 'number-${cell.piece!.id}',
                    label: '2',
                  ),
                )
              : cell,
      ],
  ]);
  check(
    !DiscoveryBoardHintSolver.legalSwaps(
      tokens,
      includeSquares: true,
    ).any((m) => m.from == from && m.to == to),
    'Math tokens never masquerade as a gem square in the solver',
  );
  const origin = DiscoveryPosition(0, 0),
      partner = DiscoveryPosition(0, 1),
      target = DiscoveryPosition(4, 4);
  final special = board(powers: {origin: DiscoveryLinePower.seeker}, layers: 2);
  const resolver = DiscoveryPowerResolver(
    enableLines: false,
    enableSeeker: true,
  );
  final hit = resolver.resolve(special, {origin}, const []);
  check(
    hit.activations.single.direction == DiscoveryLinePower.seeker &&
        hit.activations.single.targetPosition == target,
    'Seeker prioritizes buried math fragment',
  );
  check(
    hit.hits.length == 2 &&
        hit.hits.contains(origin) &&
        hit.hits.contains(target),
    'A lone seeker consumes itself and hits exactly one other cell',
  );
  final hitAgain = resolver.resolve(special, {origin}, const []);
  check(
    hitAgain.hits.toString() == hit.hits.toString(),
    'Same board produces same guided target without RNG',
  );
  final used = engine(special).swap(origin, partner);
  check(
    used.isAccepted &&
        used.cascades.first.sealHits.single.layersAfter == 1 &&
        used.cascades.first.discoveredTargets.isEmpty,
    'Seeker respects a two-layer seal',
  );
  final blocked = board(
    rows: const ['AAACD', 'AABDE', 'BCDEA', 'CDEAB', 'DEABC'],
    blockers: {const DiscoveryPosition(1, 1): 1},
  );
  check(
    discoverySquareMatches(blocked).isEmpty,
    'Blockers cannot participate in a square',
  );
  const comboResolver = DiscoveryPowerResolver(
    enableLines: true,
    enableBurst: true,
    enableColor: true,
    enableCombinations: true,
    enableSeeker: true,
  );
  final pair = board(
    powers: {
      origin: DiscoveryLinePower.seeker,
      partner: DiscoveryLinePower.seeker,
    },
  );
  final combo = comboResolver.resolve(
    pair,
    {origin, partner},
    const [],
    from: origin,
    to: partner,
  );
  check(
    combo.activations.single.combination ==
            DiscoveryPowerCombination.seekerPair &&
        combo.hits.length == 4,
    'Two seekers consume two carriers and target two distinct cells',
  );
  final color = board(
    powers: {
      origin: DiscoveryLinePower.color,
      partner: DiscoveryLinePower.seeker,
    },
  );
  final converted = comboResolver.resolve(
    color,
    {origin, partner},
    const [],
    from: origin,
    to: partner,
  );
  check(
    converted.activations.first.combination ==
            DiscoveryPowerCombination.colorSeeker &&
        converted.hits.contains(target),
    'Color-seeker combination preserves guided targeting',
  );
  stdout.writeln(
    'PASS: square creation/legacy isolation/one guided hit/seal durability/solver/determinism/blocked cells/special combinations.',
  );
}
