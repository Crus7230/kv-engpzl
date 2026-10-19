import 'dart:math' as math;

import 'discovery_puzzle_view_model.dart';

/// Optional presentation data. The game and its checkpoints already contain
/// the final state; playback never changes or delays that state.
abstract interface class DiscoveryBoardMotionSource {
  int get boardMotionRevision;
  DiscoveryBoardTurnMotion? get boardTurnMotion;
}

class DiscoveryMotionCell {
  const DiscoveryMotionCell({
    required this.gem,
    required this.sealKind,
    required this.sealLayers,
    this.blockerLayers = 0,
    this.iceLayers = 0,
  });

  final DiscoveryGemCell? gem;
  final DiscoverySealKind? sealKind;
  final int sealLayers;
  final int blockerLayers;
  final int iceLayers;
}

class DiscoveryMotionSealHit {
  const DiscoveryMotionSealHit({
    required this.index,
    required this.layersBefore,
    required this.layersAfter,
  });

  final int index;
  final int layersBefore;
  final int layersAfter;
}

class DiscoveryMotionPower {
  const DiscoveryMotionPower({
    required this.index,
    required this.direction,
    this.targetIndex,
    this.affectedIndices = const [],
    this.isCombination = false,
  });

  final int index;
  final DiscoveryLinePowerKind direction;
  final int? targetIndex;
  final List<int> affectedIndices;
  final bool isCombination;
}

class DiscoveryMotionDiscovery {
  const DiscoveryMotionDiscovery({required this.index, required this.block});

  final int index;
  final DiscoveryEquationBlock block;
}

class DiscoveryCascadeMotion {
  DiscoveryCascadeMotion({
    required this.index,
    required Iterable<int> clearedIndices,
    required Iterable<DiscoveryMotionCell> afterClear,
    required Iterable<DiscoveryMotionCell> afterFall,
    required Iterable<DiscoveryMotionCell> afterRefill,
    required Iterable<DiscoveryMotionSealHit> sealHits,
    required Iterable<DiscoveryMotionPower> createdPowers,
    required Iterable<DiscoveryMotionPower> activatedPowers,
    required Iterable<DiscoveryMotionDiscovery> discoveries,
    Iterable<DiscoveryMotionSealHit> blockerHits = const [],
  }) : clearedIndices = List.unmodifiable(clearedIndices),
       afterClear = List.unmodifiable(afterClear),
       afterFall = List.unmodifiable(afterFall),
       afterRefill = List.unmodifiable(afterRefill),
       sealHits = List.unmodifiable(sealHits),
       createdPowers = List.unmodifiable(createdPowers),
       activatedPowers = List.unmodifiable(activatedPowers),
       discoveries = List.unmodifiable(discoveries),
       blockerHits = List.unmodifiable(blockerHits);

  final int index;
  final List<int> clearedIndices;
  final List<DiscoveryMotionCell> afterClear;
  final List<DiscoveryMotionCell> afterFall;
  final List<DiscoveryMotionCell> afterRefill;
  final List<DiscoveryMotionSealHit> sealHits;
  final List<DiscoveryMotionPower> createdPowers;
  final List<DiscoveryMotionPower> activatedPowers;
  final List<DiscoveryMotionDiscovery> discoveries;
  final List<DiscoveryMotionSealHit> blockerHits;
}

class DiscoveryBoardTurnMotion {
  DiscoveryBoardTurnMotion({
    required this.fromIndex,
    required this.toIndex,
    required this.accepted,
    required Iterable<DiscoveryMotionCell> beforeSwap,
    required Iterable<DiscoveryMotionCell> afterSwap,
    required Iterable<DiscoveryCascadeMotion> cascades,
  }) : beforeSwap = List.unmodifiable(beforeSwap),
       afterSwap = List.unmodifiable(afterSwap),
       cascades = List.unmodifiable(cascades);

  final int fromIndex;
  final int toIndex;
  final bool accepted;
  final List<DiscoveryMotionCell> beforeSwap;
  final List<DiscoveryMotionCell> afterSwap;
  final List<DiscoveryCascadeMotion> cascades;
}

enum DiscoveryMotionPhaseKind {
  swap,
  returnSwap,
  powerSweep,
  clear,
  settle,
  // Retained for source compatibility; the continuous timeline emits settle
  // and overlapping discovery windows instead of these sequential phases.
  fall,
  refill,
  discovery,
}

class DiscoveryMotionPhase {
  const DiscoveryMotionPhase({
    required this.kind,
    required this.before,
    required this.after,
    required this.duration,
    this.cascade,
  });

  final DiscoveryMotionPhaseKind kind;
  final List<DiscoveryMotionCell> before;
  final List<DiscoveryMotionCell> after;
  final Duration duration;
  final DiscoveryCascadeMotion? cascade;
}

/// An effect window runs independently of the current board phase. A discovery
/// can remain visible during the next cascade without delaying its clear.
class DiscoveryMotionDiscoveryWindow {
  const DiscoveryMotionDiscoveryWindow({
    required this.cascade,
    required this.start,
    required this.duration,
  });

  final DiscoveryCascadeMotion cascade;
  final Duration start;
  final Duration duration;

  Duration get end => start + duration;

  bool isActiveAt(double elapsedMilliseconds) =>
      elapsedMilliseconds >= start.inMilliseconds &&
      elapsedMilliseconds < end.inMilliseconds;

  bool hasArrivedAt(double elapsedMilliseconds) =>
      elapsedMilliseconds >= end.inMilliseconds;

  double progressAt(double elapsedMilliseconds) =>
      ((elapsedMilliseconds - start.inMilliseconds) / duration.inMilliseconds)
          .clamp(0.0, 1.0);
}

/// Board phases are contiguous. Discovery effects share the same finite clock
/// and end within the board timeline, so they add no interaction-lock tail.
class DiscoveryMotionTimeline {
  DiscoveryMotionTimeline({
    required Iterable<DiscoveryMotionPhase> phases,
    required Iterable<DiscoveryMotionDiscoveryWindow> discoveries,
  }) : phases = List.unmodifiable(phases),
       discoveries = List.unmodifiable(discoveries);

  final List<DiscoveryMotionPhase> phases;
  final List<DiscoveryMotionDiscoveryWindow> discoveries;
  late final Duration duration = Duration(
    milliseconds: phases.fold<int>(
      0,
      (total, phase) => total + phase.duration.inMilliseconds,
    ),
  );
}

/// One controller follows swap -> clear -> simultaneous fall/refill -> cascade.
/// IDs and seal coordinates come from the exact deterministic snapshots.
DiscoveryMotionTimeline discoveryMotionTimeline(
  DiscoveryBoardTurnMotion turn, {
  required int columns,
}) {
  if (columns <= 0 || turn.beforeSwap.length % columns != 0) {
    throw ArgumentError.value(columns, 'columns', 'Invalid board columns.');
  }
  final phases = <DiscoveryMotionPhase>[
    DiscoveryMotionPhase(
      kind: DiscoveryMotionPhaseKind.swap,
      before: turn.beforeSwap,
      after: turn.afterSwap,
      duration: const Duration(milliseconds: 160),
    ),
  ];
  if (!turn.accepted) {
    phases.add(
      DiscoveryMotionPhase(
        kind: DiscoveryMotionPhaseKind.returnSwap,
        before: turn.afterSwap,
        after: turn.beforeSwap,
        duration: const Duration(milliseconds: 150),
      ),
    );
    return DiscoveryMotionTimeline(phases: phases, discoveries: const []);
  }
  var before = turn.afterSwap;
  for (final cascade in turn.cascades) {
    if (cascade.activatedPowers.isNotEmpty) {
      phases.add(
        DiscoveryMotionPhase(
          kind: DiscoveryMotionPhaseKind.powerSweep,
          before: before,
          after: before,
          duration: Duration(
            milliseconds:
                cascade.activatedPowers.any(
                  (power) => power.direction == DiscoveryLinePowerKind.seeker,
                )
                ? 280
                : cascade.index == 0
                ? 105
                : 85,
          ),
          cascade: cascade,
        ),
      );
    }
    phases.addAll([
      DiscoveryMotionPhase(
        kind: DiscoveryMotionPhaseKind.clear,
        before: before,
        after: cascade.afterClear,
        duration: Duration(milliseconds: cascade.index == 0 ? 150 : 130),
        cascade: cascade,
      ),
      DiscoveryMotionPhase(
        kind: DiscoveryMotionPhaseKind.settle,
        before: cascade.afterClear,
        after: cascade.afterRefill,
        duration: _settleDuration(cascade, columns),
        cascade: cascade,
      ),
    ]);
    before = cascade.afterRefill;
  }
  // Keep the initial swap legible, then compress an unusually long cascade.
  // Effects use the same compression factor as the board, not extra waits.
  final tailMilliseconds = phases
      .skip(1)
      .fold<int>(0, (total, phase) => total + phase.duration.inMilliseconds);
  const tailBudget = 2840;
  final compression = tailMilliseconds > tailBudget
      ? tailBudget / tailMilliseconds
      : 1.0;
  final timedPhases = compression == 1
      ? phases
      : <DiscoveryMotionPhase>[
          phases.first,
          for (final phase in phases.skip(1))
            DiscoveryMotionPhase(
              kind: phase.kind,
              before: phase.before,
              after: phase.after,
              duration: Duration(
                milliseconds: (phase.duration.inMilliseconds * compression)
                    .floor()
                    .clamp(1, tailBudget),
              ),
              cascade: phase.cascade,
            ),
        ];
  final totalMilliseconds = timedPhases.fold<int>(
    0,
    (total, phase) => total + phase.duration.inMilliseconds,
  );
  final discoveries = <DiscoveryMotionDiscoveryWindow>[];
  var phaseStart = 0;
  for (final phase in timedPhases) {
    final cascade = phase.cascade;
    if (phase.kind == DiscoveryMotionPhaseKind.clear &&
        cascade != null &&
        cascade.discoveries.isNotEmpty) {
      // Launch when the seal breaks, while matched gems finish their pop.
      // Later windows may span the following clear, but never extend the turn.
      final start = phaseStart + (phase.duration.inMilliseconds * .4).round();
      final flightMilliseconds = (380 * compression).floor().clamp(1, 380);
      discoveries.add(
        DiscoveryMotionDiscoveryWindow(
          cascade: cascade,
          start: Duration(milliseconds: start),
          duration: Duration(
            milliseconds: math.min(
              flightMilliseconds,
              totalMilliseconds - start,
            ),
          ),
        ),
      );
    }
    phaseStart += phase.duration.inMilliseconds;
  }
  return DiscoveryMotionTimeline(phases: timedPhases, discoveries: discoveries);
}

Duration _settleDuration(DiscoveryCascadeMotion cascade, int columns) {
  final beforeIndices = <String, int>{
    for (var index = 0; index < cascade.afterClear.length; index++)
      if (cascade.afterClear[index].gem case final gem?) gem.id: index,
  };
  final refillDepths = List<int>.filled(columns, 0);
  for (var index = 0; index < cascade.afterRefill.length; index++) {
    final gem = cascade.afterRefill[index].gem;
    if (gem != null && !beforeIndices.containsKey(gem.id)) {
      refillDepths[index % columns] += 1;
    }
  }
  var longestDrop = 1;
  for (var index = 0; index < cascade.afterRefill.length; index++) {
    final gem = cascade.afterRefill[index].gem;
    if (gem == null) continue;
    final sourceIndex = beforeIndices[gem.id];
    final rows = sourceIndex == null
        ? refillDepths[index % columns]
        : (index ~/ columns - sourceIndex ~/ columns).abs();
    longestDrop = math.max(longestDrop, rows);
  }
  final baseMilliseconds = (260 + (longestDrop - 1) * 24).clamp(260, 380);
  return Duration(
    milliseconds: (baseMilliseconds * (cascade.index == 0 ? 1.0 : .86)).round(),
  );
}

/// Compatibility entry point for phase-only consumers. New playback should
/// use the full timeline and pass its actual columns; the square-board fallback
/// preserves older callers without inventing sequential discovery pauses.
List<DiscoveryMotionPhase> discoveryMotionPhases(
  DiscoveryBoardTurnMotion turn, {
  int? columns,
}) => discoveryMotionTimeline(
  turn,
  columns: columns ?? math.sqrt(turn.beforeSwap.length).round(),
).phases;
