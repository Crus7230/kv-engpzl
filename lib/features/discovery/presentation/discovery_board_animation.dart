import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/audio/audio_scope.dart';
import '../../../core/audio/audio_settings.dart';
import 'discovery_board_motion.dart';
import 'discovery_puzzle_view_model.dart';

/// A transient UI lock. It never becomes part of a session checkpoint.
class DiscoveryBoardInteractionLock extends ChangeNotifier {
  bool _busy = false;
  bool _disposed = false;
  Object? _owner;
  final Set<String> _pendingTokenIds = {};

  bool get busy => _busy;
  bool isPending(String id) => _pendingTokenIds.contains(id);

  void begin(DiscoveryBoardTurnMotion turn, Object owner) {
    if (_disposed) return;
    _owner = owner;
    _busy = true;
    _pendingTokenIds
      ..clear()
      ..addAll([
        for (final cascade in turn.cascades)
          for (final discovery in cascade.discoveries) discovery.block.id,
      ]);
    notifyListeners();
  }

  void reveal(Iterable<String> ids, Object owner) {
    if (_disposed || !identical(_owner, owner)) return;
    var changed = false;
    for (final id in ids) {
      changed = _pendingTokenIds.remove(id) || changed;
    }
    if (changed) notifyListeners();
  }

  void finish(Object? owner, {bool deferNotification = false}) {
    if (_disposed || owner == null || !identical(_owner, owner)) return;
    if (!_busy && _pendingTokenIds.isEmpty) return;
    _owner = null;
    _busy = false;
    _pendingTokenIds.clear();
    if (deferNotification) {
      // Dependency changes and subtree teardown can occur during a build.
      // This callback only notifies; it cannot release a newer playback owner.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed && _owner == null) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class DiscoveryMotionScope
    extends InheritedNotifier<DiscoveryBoardInteractionLock> {
  const DiscoveryMotionScope({
    required DiscoveryBoardInteractionLock lock,
    required super.child,
    super.key,
  }) : super(notifier: lock);

  static DiscoveryBoardInteractionLock of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DiscoveryMotionScope>()!
      .notifier!;
}

/// Keeps the existing grid as the tap/semantics surface and paints actual gem
/// motion above it. Only this board listens to the animation controller.
class DiscoveryAnimatedGemBoard extends StatefulWidget {
  const DiscoveryAnimatedGemBoard({
    required this.viewModel,
    required this.lock,
    required this.columns,
    required this.spacing,
    required this.gemBuilder,
    required this.child,
    super.key,
  });

  final DiscoveryPuzzleViewModel viewModel;
  final DiscoveryBoardInteractionLock lock;
  final int columns;
  final double spacing;
  final Widget Function(DiscoveryGemCell cell) gemBuilder;
  final Widget child;

  @override
  State<DiscoveryAnimatedGemBoard> createState() =>
      _DiscoveryAnimatedGemBoardState();
}

class _DiscoveryAnimatedGemBoardState extends State<DiscoveryAnimatedGemBoard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  int _seenRevision = 0;
  bool _disableAnimations = false;
  List<DiscoveryMotionPhase> _phases = const [];
  List<DiscoveryMotionDiscoveryWindow> _discoveryWindows = const [];
  int _durationMilliseconds = 0;
  final Set<String> _revealedIds = {};
  Object? _playbackOwner;
  final Set<int> _soundedPhases = {};
  bool _skipTurnSounds = false;

  bool get _playing => _phases.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(vsync: this)
      ..addListener(_revealArrivals)
      ..addStatusListener(_onStatus);
    _attachModel();
  }

  void _attachModel() {
    final model = widget.viewModel;
    _seenRevision = model is DiscoveryBoardMotionSource
        ? (model as DiscoveryBoardMotionSource).boardMotionRevision
        : 0;
    model.addListener(_onModelChange);
  }

  @override
  void didUpdateWidget(covariant DiscoveryAnimatedGemBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.viewModel, widget.viewModel)) {
      oldWidget.viewModel.removeListener(_onModelChange);
      _cancel(deferNotification: true);
      _attachModel();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (_disableAnimations && _playing) _cancel(deferNotification: true);
  }

  void _onModelChange() {
    final model = widget.viewModel;
    if (model is! DiscoveryBoardMotionSource) return;
    final source = model as DiscoveryBoardMotionSource;
    if (_seenRevision == source.boardMotionRevision) return;
    _seenRevision = source.boardMotionRevision;
    _cancel();
    final turn = source.boardTurnMotion;
    if (turn == null || !mounted) return;
    _skipTurnSounds = false;
    _soundedPhases.clear();
    if (_disableAnimations) {
      AudioScope.play(context, PuzzleSound.swap);
      if (turn.cascades.isNotEmpty)
        AudioScope.play(
          context,
          turn.cascades.any((cascade) => cascade.activatedPowers.isNotEmpty)
              ? PuzzleSound.special
              : PuzzleSound.pop,
        );
      if (turn.cascades.any((cascade) => cascade.discoveries.isNotEmpty))
        AudioScope.maybeOf(context)?.haptic(PuzzleHaptic.fragment);
      return;
    }
    final timeline = discoveryMotionTimeline(turn, columns: widget.columns);
    _phases = timeline.phases;
    _discoveryWindows = timeline.discoveries;
    _durationMilliseconds = timeline.duration.inMilliseconds;
    _revealedIds.clear();
    _playbackOwner = Object();
    widget.lock.begin(turn, _playbackOwner!);
    _controller.duration = Duration(milliseconds: _durationMilliseconds);
    _controller.forward(from: 0);
    _soundPhases(0);
    setState(() {});
  }

  void _revealArrivals() {
    if (!_playing) return;
    final elapsed = _controller.value * _durationMilliseconds;
    _soundPhases(elapsed);
    for (final window in _discoveryWindows) {
      if (elapsed < window.end.inMilliseconds) continue;
      final arrivals = <String>[
        for (final discovery in window.cascade.discoveries)
          if (_revealedIds.add(discovery.block.id)) discovery.block.id,
      ];
      if (arrivals.isNotEmpty) {
        widget.lock.reveal(arrivals, _playbackOwner!);
        if (!_skipTurnSounds)
          AudioScope.maybeOf(context)?.haptic(PuzzleHaptic.fragment);
      }
    }
  }

  void _soundPhases(double elapsed) {
    var start = 0;
    PuzzleSound? cue;
    for (var i = 0; i < _phases.length; i++) {
      final phase = _phases[i];
      if (elapsed >= start && _soundedPhases.add(i)) {
        cue = switch (phase.kind) {
          DiscoveryMotionPhaseKind.swap => PuzzleSound.swap,
          DiscoveryMotionPhaseKind.powerSweep => PuzzleSound.special,
          DiscoveryMotionPhaseKind.clear => PuzzleSound.pop,
          _ => cue,
        };
      }
      start += phase.duration.inMilliseconds;
    }
    // A skipped frame emits at most one cue, never a burst of stale sounds.
    if (cue != null && !_skipTurnSounds) AudioScope.play(context, cue);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _skipTurnSounds = true;
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_playing) return;
    _phases = const [];
    _discoveryWindows = const [];
    widget.lock.finish(_playbackOwner);
    _playbackOwner = null;
    if (mounted) setState(() {});
  }

  void _cancel({bool deferNotification = false}) {
    _controller.stop();
    _phases = const [];
    _discoveryWindows = const [];
    _revealedIds.clear();
    widget.lock.finish(_playbackOwner, deferNotification: deferNotification);
    _playbackOwner = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.viewModel.removeListener(_onModelChange);
    _cancel(deferNotification: true);
    _controller.dispose();
    // Screen teardown drops its transient lock; no deferred state mutation.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AnimatedBuilder(
          animation: _controller,
          child: widget.child,
          builder: (context, child) {
            if (!_playing) return child!;
            final turnElapsed = _controller.value * _durationMilliseconds;
            var elapsed = turnElapsed;
            var phase = _phases.last;
            for (final candidate in _phases) {
              phase = candidate;
              if (elapsed <= candidate.duration.inMilliseconds) break;
              elapsed -= candidate.duration.inMilliseconds;
            }
            final progress = (elapsed / phase.duration.inMilliseconds).clamp(
              0.0,
              1.0,
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: ExcludeSemantics(
                    child: Opacity(opacity: 0, child: child),
                  ),
                ),
                IgnorePointer(
                  child: ExcludeSemantics(
                    child: _MotionFrame(
                      phase: phase,
                      progress: progress,
                      columns: widget.columns,
                      spacing: widget.spacing,
                      gemBuilder: widget.gemBuilder,
                      discoveries: [
                        for (final window in _discoveryWindows)
                          if (window.isActiveAt(turnElapsed))
                            for (
                              var order = 0;
                              order < window.cascade.discoveries.length;
                              order++
                            )
                              _ActiveDiscovery(
                                discovery: window.cascade.discoveries[order],
                                order: order,
                                progress: window.progressAt(turnElapsed),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActiveDiscovery {
  const _ActiveDiscovery({
    required this.discovery,
    required this.order,
    required this.progress,
  });

  final DiscoveryMotionDiscovery discovery;
  final int order;
  final double progress;
}

class _MotionFrame extends StatelessWidget {
  const _MotionFrame({
    required this.phase,
    required this.progress,
    required this.columns,
    required this.spacing,
    required this.gemBuilder,
    required this.discoveries,
  });

  final DiscoveryMotionPhase phase;
  final double progress;
  final int columns;
  final double spacing;
  final Widget Function(DiscoveryGemCell cell) gemBuilder;
  final List<_ActiveDiscovery> discoveries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final stride = extent + spacing;
        Offset point(int index) =>
            Offset((index % columns) * stride, (index ~/ columns) * stride);
        final beforeIndices = <String, int>{
          for (var index = 0; index < phase.before.length; index++)
            if (phase.before[index].gem != null)
              phase.before[index].gem!.id: index,
        };
        final clearing = phase.kind == DiscoveryMotionPhaseKind.clear;
        final refillDepthByColumn = <int, int>{};
        final settling =
            phase.kind == DiscoveryMotionPhaseKind.settle ||
            phase.kind == DiscoveryMotionPhaseKind.fall ||
            phase.kind == DiscoveryMotionPhaseKind.refill;
        if (settling) {
          for (var index = 0; index < phase.after.length; index++) {
            final gem = phase.after[index].gem;
            if (gem != null && !beforeIndices.containsKey(gem.id)) {
              final column = index % columns;
              refillDepthByColumn[column] =
                  (refillDepthByColumn[column] ?? 0) + 1;
            }
          }
        }
        final moving =
            phase.kind == DiscoveryMotionPhaseKind.swap ||
            phase.kind == DiscoveryMotionPhaseKind.returnSwap ||
            phase.kind == DiscoveryMotionPhaseKind.settle ||
            phase.kind == DiscoveryMotionPhaseKind.fall ||
            phase.kind == DiscoveryMotionPhaseKind.refill;
        final cells = clearing ? phase.before : phase.after;
        final clearIndices = phase.cascade?.clearedIndices.toSet() ?? <int>{};
        var longestFall = stride;
        if (settling) {
          for (var index = 0; index < cells.length; index++) {
            final gem = cells[index].gem;
            if (gem == null) continue;
            final sourceIndex = beforeIndices[gem.id];
            final source = sourceIndex == null
                ? point(index) -
                      Offset(
                        0,
                        stride * (refillDepthByColumn[index % columns] ?? 1),
                      )
                : point(sourceIndex);
            longestFall = math.max(longestFall, point(index).dy - source.dy);
          }
        }
        final seals = clearing && progress < .65 ? phase.before : phase.after;
        return Stack(
          fit: StackFit.expand,
          children: [
            for (var index = 0; index < cells.length; index++)
              Positioned(
                left: point(index).dx,
                top: point(index).dy,
                width: extent,
                height: extent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF242144),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            for (var index = 0; index < cells.length; index++)
              if (cells[index].gem case final gem?)
                _gem(
                  gem,
                  index,
                  moving: moving,
                  clearing: clearing && clearIndices.contains(index),
                  beforeIndices: beforeIndices,
                  refillDepth: refillDepthByColumn[index % columns] ?? 1,
                  settling: settling,
                  longestFall: longestFall,
                  extent: extent,
                  stride: stride,
                  point: point,
                ),
            if (clearing && progress >= .5)
              for (final power in phase.cascade!.createdPowers)
                if (phase.after[power.index].gem case final gem?)
                  _createdPowerGem(gem, power.index, extent, point),
            for (var index = 0; index < seals.length; index++)
              if (seals[index].blockerLayers > 0)
                Positioned(
                  left: point(index).dx,
                  top: point(index).dy,
                  width: extent,
                  height: extent,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xED596474),
                      border: Border.all(
                        color: const Color(0xFFBAC8D5),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.terrain_rounded,
                      color: Colors.white,
                      size: extent * .58,
                    ),
                  ),
                ),
            for (var index = 0; index < seals.length; index++)
              if (seals[index].sealKind != null && seals[index].iceLayers == 0)
                Positioned(
                  left: point(index).dx,
                  top: point(index).dy,
                  width: extent,
                  height: extent,
                  child: _FixedSeal(
                    cell: seals[index],
                    hit:
                        clearing &&
                        phase.cascade!.sealHits.any(
                          (hit) => hit.index == index,
                        ),
                    progress: progress,
                  ),
                ),
            Positioned.fill(
              child: CustomPaint(
                painter: _BoardEffectPainter(
                  phase: phase,
                  progress: progress,
                  columns: columns,
                  stride: stride,
                  extent: extent,
                  discoveries: discoveries,
                ),
              ),
            ),
            if (clearing && phase.cascade!.index > 0)
              Positioned(
                top: 4,
                left: 0,
                right: 0,
                child: Center(
                  child: _EffectLabel(
                    label: '${phase.cascade!.index + 1} 연쇄',
                    opacity: math.sin(progress * math.pi),
                  ),
                ),
              ),
            for (final flight in discoveries)
              _discovery(
                flight.discovery,
                flight.order,
                flight.progress,
                constraints.biggest,
                extent,
                point,
              ),
          ],
        );
      },
    );
  }

  Widget _createdPowerGem(
    DiscoveryGemCell gem,
    int index,
    double extent,
    Offset Function(int) point,
  ) {
    final birth = ((progress - .5) / .5).clamp(0.0, 1.0);
    final scale = Curves.easeOutCubic.transform(birth);
    final position = point(index);
    // The newly authored ID grows at its after-clear coordinate before
    // gravity moves that same ID; the old ID retains its normal clear effect.
    return Positioned(
      key: ValueKey('motion-gem-${gem.id}'),
      left: position.dx,
      top: position.dy,
      width: extent,
      height: extent,
      child: Transform.scale(
        key: ValueKey('power-birth-${gem.id}'),
        scale: scale,
        child: Opacity(
          opacity: (scale * 1.6).clamp(0.0, 1.0),
          child: gemBuilder(
            DiscoveryGemCell(
              id: gem.id,
              kind: gem.kind,
              linePowerKind: gem.linePowerKind,
            ),
          ),
        ),
      ),
    );
  }

  Widget _gem(
    DiscoveryGemCell gem,
    int index, {
    required bool moving,
    required bool clearing,
    required Map<String, int> beforeIndices,
    required int refillDepth,
    required bool settling,
    required double longestFall,
    required double extent,
    required double stride,
    required Offset Function(int) point,
  }) {
    final destination = point(index);
    final sourceIndex = beforeIndices[gem.id];
    // New refill gems enter from above their own column; existing IDs follow
    // gravity exactly, including cells that carry newly created line powers.
    final source = sourceIndex == null
        ? destination - Offset(0, stride * refillDepth)
        : point(sourceIndex);
    var position = destination;
    var scaleX = 1.0;
    var scaleY = 1.0;
    var opacity = 1.0;
    if (moving && source != destination) {
      if (settling) {
        final distance = math.max(0.0, destination.dy - source.dy);
        final delay = columns <= 1
            ? 0.0
            : index % columns / (columns - 1) * .07;
        final span =
            .58 + .30 * math.sqrt((distance / longestFall).clamp(0, 1));
        final local = ((progress - delay) / span).clamp(0.0, 1.0);
        final falling = (local / .82).clamp(0.0, 1.0);
        position = Offset.lerp(source, destination, falling * falling)!;
        if (local >= .82) {
          final landing = ((local - .82) / .18).clamp(0.0, 1.0);
          final impact = math.sin(landing * math.pi);
          // One small recoil stays within the cell; distant drops land later.
          position -= Offset(0, extent * .045 * impact);
          scaleX += .09 * impact;
          scaleY -= .11 * impact;
        }
      } else {
        final curve = Curves.easeInOutCubic.transform(progress);
        position = Offset.lerp(source, destination, curve)!;
        final lift = math.sin(progress * math.pi);
        scaleX += .035 * lift;
        scaleY += .035 * lift;
      }
    }
    if (clearing) {
      final anticipation = (progress / .22).clamp(0.0, 1.0);
      final pop = ((progress - .22) / .78).clamp(0.0, 1.0);
      final scale = pop == 0
          ? 1 - .075 * math.sin(anticipation * math.pi / 2)
          : pop < .20
          ? .925 + .22 * Curves.easeOutCubic.transform(pop / .20)
          : 1.145 * (1 - Curves.easeInCubic.transform((pop - .20) / .80));
      scaleX = scale;
      scaleY = scale;
      opacity = pop < .16 ? 1 : (1 - (pop - .16) / .84).clamp(0.0, 1.0);
    }
    return Positioned(
      key: ValueKey('motion-gem-${gem.id}'),
      left: position.dx,
      top: position.dy,
      width: extent,
      height: extent,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scaleX: scaleX,
          scaleY: scaleY,
          alignment: settling ? Alignment.bottomCenter : Alignment.center,
          child: gemBuilder(
            DiscoveryGemCell(
              id: gem.id,
              kind: gem.kind,
              linePowerKind: gem.linePowerKind,
            ),
          ),
        ),
      ),
    );
  }

  Widget _discovery(
    DiscoveryMotionDiscovery discovery,
    int order,
    double progress,
    Size boardSize,
    double extent,
    Offset Function(int) point,
  ) {
    final delay = (order * .055).clamp(0.0, .22);
    final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
    final curve = Curves.easeInOutCubic.transform(t);
    final origin = point(discovery.index);
    final target = Offset(boardSize.width - extent - 4, 4);
    // Top-row tokens arc into the board. Other tokens rise toward the
    // collection cue, with the whole card kept inside the clipped board.
    final arcDirection = discovery.index ~/ columns == 0 ? 1.0 : -1.0;
    final trajectory =
        Offset.lerp(origin, target, curve)! +
        Offset(0, math.sin(t * math.pi) * extent * .8 * arcDirection);
    final position = Offset(
      trajectory.dx.clamp(0.0, math.max(0.0, boardSize.width - extent)),
      trajectory.dy.clamp(0.0, math.max(0.0, boardSize.height - extent)),
    );
    return Positioned(
      key: ValueKey('discovery-flight-${discovery.block.id}'),
      left: position.dx,
      top: position.dy,
      width: extent,
      height: extent,
      child: Opacity(
        opacity: (t < .75 ? 1.0 : (1 - t) / .25).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: .75 + .25 * math.sin(t * math.pi),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: discovery.block.kind == DiscoveryEquationBlockKind.number
                  ? AppColors.number
                  : discovery.block.kind ==
                        DiscoveryEquationBlockKind.parenthesis
                  ? AppColors.parenthesis
                  : AppColors.operator,
              border: Border.all(color: const Color(0xFFFFDC85), width: 2),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(color: Color(0x66FFD16C), blurRadius: 10),
              ],
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    discovery.block.label,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: extent * .46,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FixedSeal extends StatelessWidget {
  const _FixedSeal({
    required this.cell,
    required this.hit,
    required this.progress,
  });

  final DiscoveryMotionCell cell;
  final bool hit;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (cell.sealLayers > 1)
          Positioned(
            left: 2,
            bottom: 2,
            child: _EffectLabel(label: '${cell.sealLayers}', opacity: 1),
          ),
        Positioned(
          right: 2,
          bottom: 2,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF202744),
              border: Border.all(
                color: hit
                    ? Color.lerp(
                        Colors.white,
                        const Color(0xFFFFDC85),
                        math.sin(progress * math.pi),
                      )!
                    : Colors.white,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              switch (cell.sealKind!) {
                DiscoverySealKind.number => Icons.pin_rounded,
                DiscoverySealKind.operatorSymbol => Icons.calculate_rounded,
                DiscoverySealKind.parenthesis => Icons.data_object_rounded,
              },
              size: 12,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _EffectLabel extends StatelessWidget {
  const _EffectLabel({required this.label, required this.opacity});

  final String label;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xEF202744),
          border: Border.all(color: const Color(0xFFFFDC85)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFE8B1),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardEffectPainter extends CustomPainter {
  const _BoardEffectPainter({
    required this.phase,
    required this.progress,
    required this.columns,
    required this.stride,
    required this.extent,
    required this.discoveries,
  });

  final DiscoveryMotionPhase phase;
  final double progress;
  final int columns;
  final double stride;
  final double extent;
  final List<_ActiveDiscovery> discoveries;

  Offset center(int index) => Offset(
    index % columns * stride + extent / 2,
    index ~/ columns * stride + extent / 2,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final cascade = phase.cascade;
    final paint = Paint()..isAntiAlias = true;
    final pulse = math.sin(progress * math.pi);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (cascade != null && phase.kind == DiscoveryMotionPhaseKind.powerSweep) {
      for (final power in cascade.activatedPowers) {
        final origin = center(power.index);
        if (power.isCombination ||
            power.direction == DiscoveryLinePowerKind.burst ||
            power.direction == DiscoveryLinePowerKind.color) {
          final sweep = Curves.easeOutCubic.transform(progress);
          final color = power.direction == DiscoveryLinePowerKind.color
              ? const Color(0xFFA3E8FF)
              : const Color(0xFFFFDC85);
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = extent * .055
            ..color = color.withValues(alpha: .85 * pulse);
          if (power.direction != DiscoveryLinePowerKind.color) {
            canvas.drawCircle(
              origin,
              extent * (power.isCombination ? 2.6 : 1.5) * sweep,
              paint,
            );
          }
          for (final index in power.affectedIndices) {
            final target = center(index);
            if (power.direction == DiscoveryLinePowerKind.color) {
              canvas.drawLine(
                origin,
                Offset.lerp(origin, target, sweep)!,
                paint,
              );
            }
            paint
              ..style = PaintingStyle.fill
              ..color = color.withValues(alpha: .28 * pulse);
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: target,
                  width: extent * .86,
                  height: extent * .86,
                ),
                const Radius.circular(6),
              ),
              paint,
            );
            paint
              ..style = PaintingStyle.stroke
              ..color = color.withValues(alpha: .85 * pulse);
          }
          paint.style = PaintingStyle.fill;
          continue;
        }
        final horizontal = power.direction == DiscoveryLinePowerKind.row;
        final start = horizontal ? Offset(0, origin.dy) : Offset(origin.dx, 0);
        final finish = horizontal
            ? Offset(size.width, origin.dy)
            : Offset(origin.dx, size.height);
        final sweep = Curves.easeOutCubic.transform(progress);
        final firstHead = Offset.lerp(origin, start, sweep)!;
        final lastHead = Offset.lerp(origin, finish, sweep)!;
        final color = _gemColor(phase.before[power.index].gem?.kind);
        paint
          ..color = color.withValues(alpha: .42 * pulse)
          ..strokeWidth = extent * .32
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(firstHead, lastHead, paint);
        paint
          ..color = Colors.white.withValues(alpha: .86 * pulse)
          ..strokeWidth = extent * .085;
        canvas.drawLine(firstHead, lastHead, paint);
        for (final head in [firstHead, lastHead]) {
          paint.color = Colors.white.withValues(alpha: .70 * pulse);
          canvas.drawCircle(head, extent * .11, paint);
        }
      }
    } else if (cascade != null &&
        phase.kind == DiscoveryMotionPhaseKind.clear) {
      final burst = ((progress - .22) / .78).clamp(0.0, 1.0);
      final fade = (1 - burst) * (1 - burst);
      for (final index in cascade.clearedIndices) {
        final origin = center(index);
        final color = _gemColor(phase.before[index].gem?.kind);
        if (burst <= 0) {
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = color.withValues(alpha: progress / .22 * .45);
          canvas.drawCircle(origin, extent * .34, paint);
          paint.style = PaintingStyle.fill;
          continue;
        }
        // Each match emits six deterministic shards in its own color.
        // Their radius and lifetime are bounded by this cell's clear phase.
        final flash = (1 - burst / .34).clamp(0.0, 1.0);
        paint.color = Colors.white.withValues(alpha: flash * .55);
        canvas.drawCircle(origin, extent * (.25 + burst * .18), paint);
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = extent * .035
          ..color = color.withValues(alpha: fade * .72);
        canvas.drawCircle(origin, extent * (.25 + burst * .34), paint);
        paint.style = PaintingStyle.fill;
        for (var particle = 0; particle < 6; particle++) {
          final angle = particle * math.pi / 3 + index * .47;
          final travel =
              extent * (.13 + .56 * Curves.easeOutQuad.transform(burst));
          final position =
              origin +
              Offset(math.cos(angle), math.sin(angle)) * travel +
              Offset(0, extent * .20 * burst * burst);
          final radius = extent * (.040 + particle % 2 * .012) * (1 - burst);
          paint.color = (particle.isEven ? color : Colors.white).withValues(
            alpha: fade * .90,
          );
          if (particle.isEven) {
            final shard = Path()
              ..moveTo(position.dx, position.dy - radius)
              ..lineTo(position.dx + radius * .7, position.dy)
              ..lineTo(position.dx, position.dy + radius)
              ..lineTo(position.dx - radius * .7, position.dy)
              ..close();
            canvas.drawPath(shard, paint);
          } else {
            canvas.drawCircle(position, radius * .7, paint);
          }
        }
      }
      for (final hit in [...cascade.sealHits, ...cascade.blockerHits]) {
        final origin = center(hit.index);
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = const Color(0xFFFFE4A3).withValues(alpha: pulse);
        canvas.drawCircle(origin, extent * (.2 + progress * .35), paint);
        final crack = Path()
          ..moveTo(origin.dx - extent * .18, origin.dy - extent * .28)
          ..lineTo(origin.dx + extent * .04, origin.dy - extent * .04)
          ..lineTo(origin.dx - extent * .07, origin.dy + extent * .08)
          ..lineTo(origin.dx + extent * .2, origin.dy + extent * .28);
        canvas.drawPath(crack, paint);
        if (hit.layersAfter == 0) {
          paint.color = const Color(0xFFFFD880).withValues(alpha: pulse * .4);
          canvas.drawCircle(origin, extent * .4, paint);
        }
        paint.style = PaintingStyle.fill;
      }
      for (final power in cascade.createdPowers) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFB6E5FF).withValues(alpha: pulse);
        canvas.drawCircle(
          center(power.index),
          extent * (.3 + progress * .16),
          paint,
        );
        paint.style = PaintingStyle.fill;
      }
    }
    for (final flight in discoveries) {
      final t = flight.progress;
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFDC85).withValues(alpha: (1 - t) * .75);
      canvas.drawCircle(
        center(flight.discovery.index),
        extent * (.2 + t * .35),
        paint,
      );
      paint.style = PaintingStyle.fill;
    }
    canvas.restore();
  }

  Color _gemColor(DiscoveryGemKind? kind) => switch (kind) {
    DiscoveryGemKind.berry => const Color(0xFFFF7C93),
    DiscoveryGemKind.ocean => const Color(0xFF6EB8FF),
    DiscoveryGemKind.citrus => const Color(0xFFFFB13D),
    DiscoveryGemKind.grape => const Color(0xFFA888F2),
    DiscoveryGemKind.leaf => const Color(0xFF69C79F),
    DiscoveryGemKind.sun => const Color(0xFFFFD84E),
    null => const Color(0xFFFFDC85),
  };

  @override
  bool shouldRepaint(covariant _BoardEffectPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.progress != progress ||
      oldDelegate.stride != stride ||
      oldDelegate.extent != extent ||
      oldDelegate.discoveries != discoveries;
}
