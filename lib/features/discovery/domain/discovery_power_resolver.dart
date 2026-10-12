import 'discovery_models.dart';

typedef _PowerRun = ({
  List<DiscoveryPosition> positions,
  DiscoveryLinePower direction,
});

class DiscoveryPowerResolution {
  const DiscoveryPowerResolution(this.created, this.hits, this.activations);
  final Map<DiscoveryPosition, DiscoveryPiece> created;
  final Set<DiscoveryPosition> hits;
  final List<DiscoveryPowerEvent> activations;
}

/// Deterministic special-piece rules. Effects are bounded to this board, damage
/// a cell once per cascade, and never call RNG or change a math token.
class DiscoveryPowerResolver {
  const DiscoveryPowerResolver({
    this.enableBurst = false,
    this.enableColor = false,
    this.enableCombinations = false,
  });
  final bool enableBurst;
  final bool enableColor;
  final bool enableCombinations;

  DiscoveryPowerResolution resolve(
    DiscoveryBoard board,
    Set<DiscoveryPosition> naturalHits,
    List<DiscoveryPosition> preferred, {
    DiscoveryPosition? from,
    DiscoveryPosition? to,
  }) {
    final hits = {...naturalHits};
    final created = _create(board, preferred);
    final events = <DiscoveryPowerEvent>[];
    final processed = <DiscoveryPosition>{};
    final converted = <DiscoveryPosition, DiscoveryLinePower>{};
    void emit(
      DiscoveryPosition origin,
      DiscoveryLinePower kind,
      Iterable<DiscoveryPosition> cells, {
      DiscoveryPowerCombination? combination,
    }) {
      final affected = cells.where(board.contains).toSet().toList()
        ..sort(_order);
      hits.addAll(affected);
      events.add(
        DiscoveryPowerEvent(
          position: origin,
          direction: kind,
          combination: combination,
          affectedPositions: List.unmodifiable(affected),
        ),
      );
    }

    if (from != null && to != null) {
      final a = board.pieceAt(from)!.linePower;
      final b = board.pieceAt(to)!.linePower;
      if (a == DiscoveryLinePower.color || b == DiscoveryLinePower.color) {
        final origin = a == DiscoveryLinePower.color ? from : to;
        final partner = origin == from ? to : from;
        final partnerPower = board.pieceAt(partner)!.linePower;
        final color = board.pieceAt(partner)!.matchKey;
        if (partnerPower == DiscoveryLinePower.color && enableCombinations) {
          processed.addAll([from, to]);
          emit(
            origin,
            DiscoveryLinePower.color,
            board.positions,
            combination: DiscoveryPowerCombination.colorColor,
          );
        } else if (partnerPower != null && enableCombinations) {
          processed.addAll([from, to]);
          final colored = board.positions
              .where(
                (p) =>
                    board.pieceAt(p)?.matchKey == color &&
                    board.cellAt(p).blockerLayers == 0,
              )
              .toList();
          for (final p in colored) {
            if (p != from && p != to)
              converted[p] = partnerPower == DiscoveryLinePower.burst
                  ? DiscoveryLinePower.burst
                  : (p.row + p.column).isEven
                  ? DiscoveryLinePower.row
                  : DiscoveryLinePower.column;
          }
          final cells = <DiscoveryPosition>{from, to, ...colored};
          // Include the consumed partner's own footprint as well.
          cells.addAll(_footprint(board, partner, partnerPower));
          emit(
            origin,
            DiscoveryLinePower.color,
            cells,
            combination: partnerPower == DiscoveryLinePower.burst
                ? DiscoveryPowerCombination.colorBurst
                : DiscoveryPowerCombination.colorLine,
          );
        } else {
          processed.add(origin);
          emit(
            origin,
            DiscoveryLinePower.color,
            [
              origin,
              partner,
              ...board.positions.where(
                (p) => board.pieceAt(p)?.matchKey == color,
              ),
            ],
            combination: DiscoveryPowerCombination.colorGem,
          );
        }
      } else if (a != null && b != null && enableCombinations) {
        processed.addAll([from, to]);
        final bothBurst =
            a == DiscoveryLinePower.burst && b == DiscoveryLinePower.burst;
        final someBurst =
            a == DiscoveryLinePower.burst || b == DiscoveryLinePower.burst;
        emit(
          to,
          someBurst ? DiscoveryLinePower.burst : DiscoveryLinePower.row,
          bothBurst
              ? _square(to, 2)
              : someBurst
              ? _wideCross(board, to)
              : _cross(board, to),
          combination: bothBurst
              ? DiscoveryPowerCombination.burstBurst
              : someBurst
              ? DiscoveryPowerCombination.lineBurst
              : DiscoveryPowerCombination.lineLine,
        );
      }
      // A special can be exchanged with a normal gem without forming a 3-match.
      for (final p in [from, to]) {
        if (board.pieceAt(p)?.linePower != null) hits.add(p);
      }
    }
    while (true) {
      final pending =
          hits
              .where(
                (p) =>
                    !processed.contains(p) &&
                    board.cellAt(p).blockerLayers == 0 &&
                    (converted.containsKey(p) ||
                        board.pieceAt(p)?.linePower != null),
              )
              .toList()
            ..sort(_order);
      if (pending.isEmpty) break;
      for (final p in pending) {
        processed.add(p);
        final kind = converted[p] ?? board.pieceAt(p)!.linePower!;
        emit(p, kind, _footprint(board, p, kind));
      }
    }
    return DiscoveryPowerResolution(created, hits, events);
  }

  Map<DiscoveryPosition, DiscoveryPiece> _create(
    DiscoveryBoard board,
    List<DiscoveryPosition> preferred,
  ) {
    final runs = <_PowerRun>[];
    void inspect(List<DiscoveryPosition> line, DiscoveryLinePower direction) {
      var start = 0;
      for (var end = 1; end <= line.length; end++) {
        final key = board.matchKeyAt(line[end - 1]);
        final next = end < line.length ? board.matchKeyAt(line[end]) : null;
        if (key == null || key != next) {
          if (key != null && end - start >= 3) {
            runs.add((
              positions: line.sublist(start, end),
              direction: direction,
            ));
          }
          start = end;
        }
      }
    }

    for (var r = 0; r < board.rowCount; r++) {
      inspect([
        for (var c = 0; c < board.columnCount; c++) DiscoveryPosition(r, c),
      ], DiscoveryLinePower.row);
    }
    for (var c = 0; c < board.columnCount; c++) {
      inspect([
        for (var r = 0; r < board.rowCount; r++) DiscoveryPosition(r, c),
      ], DiscoveryLinePower.column);
    }
    final result = <DiscoveryPosition, DiscoveryPiece>{};
    while (runs.isNotEmpty) {
      final group = [runs.removeAt(0)];
      final cells = group.first.positions.toSet();
      var grew = true;
      while (grew) {
        grew = false;
        for (var i = runs.length - 1; i >= 0; i--) {
          if (runs[i].positions.any(cells.contains)) {
            final run = runs.removeAt(i);
            group.add(run);
            cells.addAll(run.positions);
            grew = true;
          }
        }
      }
      if (cells.any((p) => board.pieceAt(p)?.linePower != null)) continue;
      final five = group.where((run) => run.positions.length >= 5).firstOrNull;
      final four = group.where((run) => run.positions.length >= 4).firstOrNull;
      final crossing =
          group.any((r) => r.direction == DiscoveryLinePower.row) &&
          group.any((r) => r.direction == DiscoveryLinePower.column);
      final kind = enableColor && five != null
          ? DiscoveryLinePower.color
          : enableBurst && crossing
          ? DiscoveryLinePower.burst
          : four?.direction;
      if (kind == null) continue;
      final candidates =
          (kind == DiscoveryLinePower.color
                  ? five!.positions
                  : kind == DiscoveryLinePower.burst
                  ? cells.toList()
                  : four!.positions)
              .toList()
            ..sort(_order);
      final anchor =
          preferred.where(candidates.contains).firstOrNull ?? candidates.last;
      result[anchor] = board.pieceAt(anchor)!.withLinePower(kind);
    }
    return result;
  }

  Iterable<DiscoveryPosition> _footprint(
    DiscoveryBoard board,
    DiscoveryPosition p,
    DiscoveryLinePower kind,
  ) => switch (kind) {
    DiscoveryLinePower.row => [
      for (var c = 0; c < board.columnCount; c++) DiscoveryPosition(p.row, c),
    ],
    DiscoveryLinePower.column => [
      for (var r = 0; r < board.rowCount; r++) DiscoveryPosition(r, p.column),
    ],
    DiscoveryLinePower.burst => _square(p, 1),
    DiscoveryLinePower.color => [
      p,
      ...board.positions.where(
        (q) => board.pieceAt(q)?.matchKey == board.pieceAt(p)?.matchKey,
      ),
    ],
  };
  Iterable<DiscoveryPosition> _square(DiscoveryPosition p, int radius) sync* {
    for (var r = p.row - radius; r <= p.row + radius; r++) {
      for (var c = p.column - radius; c <= p.column + radius; c++)
        yield DiscoveryPosition(r, c);
    }
  }

  Iterable<DiscoveryPosition> _cross(
    DiscoveryBoard board,
    DiscoveryPosition p,
  ) => [
    for (var c = 0; c < board.columnCount; c++) DiscoveryPosition(p.row, c),
    for (var r = 0; r < board.rowCount; r++) DiscoveryPosition(r, p.column),
  ];
  Iterable<DiscoveryPosition> _wideCross(
    DiscoveryBoard board,
    DiscoveryPosition p,
  ) => [
    for (var r = p.row - 1; r <= p.row + 1; r++)
      for (var c = 0; c < board.columnCount; c++) DiscoveryPosition(r, c),
    for (var c = p.column - 1; c <= p.column + 1; c++)
      for (var r = 0; r < board.rowCount; r++) DiscoveryPosition(r, c),
  ];
  static int _order(DiscoveryPosition a, DiscoveryPosition b) =>
      a.row != b.row ? a.row.compareTo(b.row) : a.column.compareTo(b.column);
}
