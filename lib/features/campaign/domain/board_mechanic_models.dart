/// Stable gameplay identifiers. Visual themes belong to [BoardMechanicSkin]
/// and must not create a new mechanic ID.
enum BoardMechanicId {
  singleLayerSeal,
  layeredSeal,
  adjacentHitBlocker,
  linePower,
  swapLock,
  fixedBlocker,
  portal,
  conveyor,
}

/// The authoring purpose of the board mechanic in one stage.
enum BoardMechanicRole {
  baseline,
  introduce,
  guided,
  independent,
  review,
  mixed,
}

/// Readiness is deliberately stricter than the existence of a Dart type.
enum BoardMechanicSupportState {
  /// Domain engine, stage adapter, and verified fixture path can execute it.
  supported,

  /// Authoring data can represent it, but the current runtime cannot play it.
  modelOnly,

  /// The identifier is reserved, while full behavior contracts remain future work.
  planned,
}

/// A logical rule shared by every physical layout of the same stage.
///
/// Cell positions and regional art are intentionally absent. This lets 5x5 and
/// 6x6 fixtures use independent placements while retaining one rule signature.
sealed class BoardMechanicRule {
  const BoardMechanicRule();

  BoardMechanicId get mechanicId;
  int get affectedCellCount;
  int get requiredInteractionCount;

  /// Stable authoring signature. It excludes skin and fixture positions.
  String get logicalSignature;
}

/// The one-layer, match-on-cell reveal behavior implemented by the current
/// discovery runtime.
final class SingleLayerSealRule extends BoardMechanicRule {
  SingleLayerSealRule({required this.sealCount}) {
    _requirePositive(sealCount, 'sealCount');
  }

  final int sealCount;

  @override
  BoardMechanicId get mechanicId => BoardMechanicId.singleLayerSeal;

  @override
  int get affectedCellCount => sealCount;

  @override
  int get requiredInteractionCount => sealCount;

  @override
  String get logicalSignature => '${mechanicId.name}:$sealCount:1';
}

/// A stationary token seal that needs more than one match-on-cell hit.
final class LayeredSealRule extends BoardMechanicRule {
  LayeredSealRule({required this.sealCount, required this.layers}) {
    _requirePositive(sealCount, 'sealCount');
    if (layers < 2) {
      throw ArgumentError.value(
        layers,
        'layers',
        'A layered seal needs at least two layers.',
      );
    }
  }

  final int sealCount;
  final int layers;

  @override
  BoardMechanicId get mechanicId => BoardMechanicId.layeredSeal;

  @override
  int get affectedCellCount => sealCount;

  @override
  int get requiredInteractionCount => sealCount * layers;

  @override
  String get logicalSignature => '${mechanicId.name}:$sealCount:$layers';
}

/// A blocker damaged by a match on an orthogonally adjacent cell.
///
/// Dust, vines, rocks, and coral can all be skins of this same interaction.
final class AdjacentHitBlockerRule extends BoardMechanicRule {
  AdjacentHitBlockerRule({
    required this.blockerCount,
    required this.durability,
  }) {
    _requirePositive(blockerCount, 'blockerCount');
    _requirePositive(durability, 'durability');
  }

  final int blockerCount;
  final int durability;

  @override
  BoardMechanicId get mechanicId => BoardMechanicId.adjacentHitBlocker;

  @override
  int get affectedCellCount => blockerCount;

  @override
  int get requiredInteractionCount => blockerCount * durability;

  @override
  String get logicalSignature => '${mechanicId.name}:$blockerCount:$durability';
}

/// A line-clearing power piece created by a long straight match.
final class LinePowerRule extends BoardMechanicRule {
  LinePowerRule({
    required this.requiredActivations,
    this.creationMatchLength = 4,
  }) {
    _requirePositive(requiredActivations, 'requiredActivations');
    if (creationMatchLength < 4) {
      throw ArgumentError.value(
        creationMatchLength,
        'creationMatchLength',
        'A line power needs a match of at least four pieces.',
      );
    }
  }

  final int requiredActivations;
  final int creationMatchLength;

  @override
  BoardMechanicId get mechanicId => BoardMechanicId.linePower;

  @override
  int get affectedCellCount => 0;

  @override
  int get requiredInteractionCount => requiredActivations;

  @override
  String get logicalSignature =>
      '${mechanicId.name}:$requiredActivations:$creationMatchLength';
}

/// Reserved authoring model for pieces that cannot swap until unlocked.
final class SwapLockRule extends BoardMechanicRule {
  SwapLockRule({required this.lockCount, required this.unlockHits}) {
    _requirePositive(lockCount, 'lockCount');
    _requirePositive(unlockHits, 'unlockHits');
  }

  final int lockCount;
  final int unlockHits;

  @override
  BoardMechanicId get mechanicId => BoardMechanicId.swapLock;

  @override
  int get affectedCellCount => lockCount;

  @override
  int get requiredInteractionCount => lockCount * unlockHits;

  @override
  String get logicalSignature => '${mechanicId.name}:$lockCount:$unlockHits';
}

/// Reserved authoring model for cells that block swapping and gravity.
final class FixedBlockerRule extends BoardMechanicRule {
  FixedBlockerRule({required this.blockerCount, required this.durability}) {
    _requirePositive(blockerCount, 'blockerCount');
    _requirePositive(durability, 'durability');
  }

  final int blockerCount;
  final int durability;

  @override
  BoardMechanicId get mechanicId => BoardMechanicId.fixedBlocker;

  @override
  int get affectedCellCount => blockerCount;

  @override
  int get requiredInteractionCount => blockerCount * durability;

  @override
  String get logicalSignature => '${mechanicId.name}:$blockerCount:$durability';
}

/// Reserved authoring model for paired gravity exits and entrances.
final class PortalRule extends BoardMechanicRule {
  PortalRule({required this.pairCount}) {
    _requirePositive(pairCount, 'pairCount');
  }

  final int pairCount;

  @override
  BoardMechanicId get mechanicId => BoardMechanicId.portal;

  @override
  int get affectedCellCount => pairCount * 2;

  @override
  int get requiredInteractionCount => 0;

  @override
  String get logicalSignature => '${mechanicId.name}:$pairCount';
}

/// Reserved authoring model for a deterministic post-turn conveyor path.
final class ConveyorRule extends BoardMechanicRule {
  ConveyorRule({required this.pathCellCount, this.stepsPerAcceptedSwap = 1}) {
    if (pathCellCount < 2) {
      throw ArgumentError.value(
        pathCellCount,
        'pathCellCount',
        'A conveyor path needs at least two cells.',
      );
    }
    _requirePositive(stepsPerAcceptedSwap, 'stepsPerAcceptedSwap');
  }

  final int pathCellCount;
  final int stepsPerAcceptedSwap;

  @override
  BoardMechanicId get mechanicId => BoardMechanicId.conveyor;

  @override
  int get affectedCellCount => pathCellCount;

  @override
  int get requiredInteractionCount => 0;

  @override
  String get logicalSignature =>
      '${mechanicId.name}:$pathCellCount:$stepsPerAcceptedSwap';
}

/// Region-specific presentation for one stable gameplay mechanic.
final class BoardMechanicSkin {
  BoardMechanicSkin({required this.key, required this.mechanicId}) {
    if (key.trim().isEmpty) {
      throw ArgumentError.value(key, 'key', 'Skin key must not be empty.');
    }
  }

  final String key;
  final BoardMechanicId mechanicId;
}

/// Binds logical behavior to art without allowing art to alter the rule.
final class BoardMechanicBinding {
  BoardMechanicBinding({required this.rule, required this.skin}) {
    if (rule.mechanicId != skin.mechanicId) {
      throw ArgumentError(
        'Skin ${skin.key} targets ${skin.mechanicId.name}, but the rule is '
        '${rule.mechanicId.name}.',
      );
    }
  }

  final BoardMechanicRule rule;
  final BoardMechanicSkin skin;
}

/// Immutable logical mechanic plan for one stage.
///
/// [singleLayerSeal] is the baseline and does not count as a newly introduced
/// advanced mechanic. Introduction and practice plans contain exactly one
/// advanced mechanic; mixed plans contain at least two already introduced
/// advanced mechanics.
final class BoardMechanicPlan {
  BoardMechanicPlan({
    required this.id,
    required this.role,
    required Iterable<BoardMechanicBinding> bindings,
  }) : bindings = List.unmodifiable(bindings) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Plan ID must not be empty.');
    }
    if (this.bindings.isEmpty) {
      throw ArgumentError('A board mechanic plan needs at least one binding.');
    }

    final seen = <BoardMechanicId>{};
    for (final binding in this.bindings) {
      if (!seen.add(binding.rule.mechanicId)) {
        throw ArgumentError(
          'Plan $id repeats ${binding.rule.mechanicId.name}.',
        );
      }
    }

    final advancedCount = advancedMechanicIds.length;
    switch (role) {
      case BoardMechanicRole.baseline:
        if (advancedCount != 0 ||
            !mechanicIds.contains(BoardMechanicId.singleLayerSeal)) {
          throw ArgumentError(
            'A baseline plan may contain only the single-layer core mechanic.',
          );
        }
      case BoardMechanicRole.introduce:
      case BoardMechanicRole.guided:
      case BoardMechanicRole.independent:
      case BoardMechanicRole.review:
        if (advancedCount != 1) {
          throw ArgumentError(
            '${role.name} plan $id must contain exactly one advanced mechanic.',
          );
        }
      case BoardMechanicRole.mixed:
        if (advancedCount < 2) {
          throw ArgumentError(
            'Mixed plan $id needs at least two advanced mechanics.',
          );
        }
    }
  }

  final String id;
  final BoardMechanicRole role;
  final List<BoardMechanicBinding> bindings;

  late final Set<BoardMechanicId> mechanicIds = Set.unmodifiable(
    bindings.map((binding) => binding.rule.mechanicId),
  );

  late final Set<BoardMechanicId> advancedMechanicIds = Set.unmodifiable(
    mechanicIds.where((id) => id != BoardMechanicId.singleLayerSeal),
  );

  /// Comparable across screen-size fixtures because skin and positions are out.
  late final String logicalSignature =
      (bindings.toList()..sort(
            (left, right) => left.rule.mechanicId.index.compareTo(
              right.rule.mechanicId.index,
            ),
          ))
          .map((binding) => binding.rule.logicalSignature)
          .join('|');
}

enum BoardMechanicSequenceIssueCode {
  mechanicUsedBeforeIntroduction,
  mechanicReintroduced,
  mixedBeforeSoloIntroduction,
}

final class BoardMechanicSequenceIssue {
  const BoardMechanicSequenceIssue({
    required this.code,
    required this.planId,
    required this.mechanicIds,
  });

  final BoardMechanicSequenceIssueCode code;
  final String planId;
  final Set<BoardMechanicId> mechanicIds;
}

/// Checks authoring order across stages without coupling it to math content.
final class BoardMechanicSequenceValidator {
  const BoardMechanicSequenceValidator();

  List<BoardMechanicSequenceIssue> validate(Iterable<BoardMechanicPlan> plans) {
    final issues = <BoardMechanicSequenceIssue>[];
    final introduced = <BoardMechanicId>{};

    for (final plan in plans) {
      final advanced = plan.advancedMechanicIds;
      final unseen = advanced.difference(introduced);

      switch (plan.role) {
        case BoardMechanicRole.baseline:
          break;
        case BoardMechanicRole.introduce:
          final mechanic = advanced.single;
          if (!unseen.contains(mechanic)) {
            issues.add(
              BoardMechanicSequenceIssue(
                code: BoardMechanicSequenceIssueCode.mechanicReintroduced,
                planId: plan.id,
                mechanicIds: Set.unmodifiable({mechanic}),
              ),
            );
          } else {
            introduced.add(mechanic);
          }
        case BoardMechanicRole.mixed:
          if (unseen.isNotEmpty) {
            issues.add(
              BoardMechanicSequenceIssue(
                code:
                    BoardMechanicSequenceIssueCode.mixedBeforeSoloIntroduction,
                planId: plan.id,
                mechanicIds: Set.unmodifiable(unseen),
              ),
            );
          }
        case BoardMechanicRole.guided:
        case BoardMechanicRole.independent:
        case BoardMechanicRole.review:
          if (unseen.isNotEmpty) {
            issues.add(
              BoardMechanicSequenceIssue(
                code: BoardMechanicSequenceIssueCode
                    .mechanicUsedBeforeIntroduction,
                planId: plan.id,
                mechanicIds: Set.unmodifiable(unseen),
              ),
            );
          }
      }
    }
    return List.unmodifiable(issues);
  }
}

final class BoardMechanicCapability {
  BoardMechanicCapability({
    required this.mechanicId,
    required this.supportState,
    required this.note,
  }) {
    if (note.trim().isEmpty) {
      throw ArgumentError.value(note, 'note', 'Capability note is required.');
    }
  }

  final BoardMechanicId mechanicId;
  final BoardMechanicSupportState supportState;
  final String note;

  bool get isRuntimeSupported =>
      supportState == BoardMechanicSupportState.supported;
}

/// Complete capability declaration for a concrete engine/adapter version.
final class BoardMechanicCapabilityRegistry {
  BoardMechanicCapabilityRegistry({
    required this.runtimeId,
    required Iterable<BoardMechanicCapability> capabilities,
  }) : capabilities = List.unmodifiable(capabilities) {
    if (runtimeId.trim().isEmpty) {
      throw ArgumentError.value(
        runtimeId,
        'runtimeId',
        'Runtime ID must not be empty.',
      );
    }

    final byId = <BoardMechanicId, BoardMechanicCapability>{};
    for (final capability in this.capabilities) {
      if (byId.containsKey(capability.mechanicId)) {
        throw ArgumentError(
          'Capability ${capability.mechanicId.name} is duplicated.',
        );
      }
      byId[capability.mechanicId] = capability;
    }
    final missing = BoardMechanicId.values.where(
      (mechanicId) => !byId.containsKey(mechanicId),
    );
    if (missing.isNotEmpty) {
      throw ArgumentError(
        'Capability registry is missing: ${missing.map((id) => id.name).join(', ')}.',
      );
    }
    _byId = Map.unmodifiable(byId);
  }

  final String runtimeId;
  final List<BoardMechanicCapability> capabilities;
  late final Map<BoardMechanicId, BoardMechanicCapability> _byId;

  BoardMechanicCapability capabilityFor(BoardMechanicId mechanicId) =>
      _byId[mechanicId]!;

  bool supportsForPlay(BoardMechanicPlan plan) =>
      plan.mechanicIds.every(
        (mechanicId) => capabilityFor(mechanicId).isRuntimeSupported,
      ) &&
      plan.bindings.every(
        (binding) => switch (binding.rule) {
          LayeredSealRule rule => rule.layers == 2,
          LinePowerRule rule =>
            rule.creationMatchLength == 4 && rule.requiredActivations == 1,
          _ => true,
        },
      );

  List<BoardMechanicCapability> unavailableForPlay(BoardMechanicPlan plan) =>
      List.unmodifiable(
        plan.mechanicIds
            .map(capabilityFor)
            .where((capability) => !capability.isRuntimeSupported),
      );
}

/// Current runtime truth, not the regional campaign's design target.
///
/// The executable adapter supports stationary two-layer seals and four-match
/// line powers with paired 5x5/6x6 fixture paths. Other mechanics remain gated.
final BoardMechanicCapabilityRegistry
currentDiscoveryBoardMechanics = BoardMechanicCapabilityRegistry(
  runtimeId: 'discovery-seals-lines-v2',
  capabilities: [
    BoardMechanicCapability(
      mechanicId: BoardMechanicId.singleLayerSeal,
      supportState: BoardMechanicSupportState.supported,
      note: 'Implemented by the current match-on-cell buried-target flow.',
    ),
    BoardMechanicCapability(
      mechanicId: BoardMechanicId.layeredSeal,
      supportState: BoardMechanicSupportState.supported,
      note:
          'Two stationary layers, hit once per cascade; verified paired fixtures.',
    ),
    BoardMechanicCapability(
      mechanicId: BoardMechanicId.adjacentHitBlocker,
      supportState: BoardMechanicSupportState.modelOnly,
      note: 'Typed authoring rule exists; blocker topology is absent.',
    ),
    BoardMechanicCapability(
      mechanicId: BoardMechanicId.linePower,
      supportState: BoardMechanicSupportState.supported,
      note:
          'Four-match creation, adjacent-swap/chain activation, full-line hits.',
    ),
    BoardMechanicCapability(
      mechanicId: BoardMechanicId.swapLock,
      supportState: BoardMechanicSupportState.planned,
      note: 'Reserved for future swap-restriction behavior.',
    ),
    BoardMechanicCapability(
      mechanicId: BoardMechanicId.fixedBlocker,
      supportState: BoardMechanicSupportState.planned,
      note: 'Reserved for future gravity-blocking behavior.',
    ),
    BoardMechanicCapability(
      mechanicId: BoardMechanicId.portal,
      supportState: BoardMechanicSupportState.planned,
      note: 'Reserved for future paired gravity routing.',
    ),
    BoardMechanicCapability(
      mechanicId: BoardMechanicId.conveyor,
      supportState: BoardMechanicSupportState.planned,
      note: 'Reserved for future deterministic post-turn movement.',
    ),
  ],
);

void _requirePositive(int value, String name) {
  if (value < 1) {
    throw ArgumentError.value(value, name, 'Must be at least one.');
  }
}
