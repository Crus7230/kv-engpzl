import 'dart:io';

import '../lib/features/campaign/domain/board_mechanic_models.dart';

void main() {
  final baseline = _plan('baseline', BoardMechanicRole.baseline, [
    _binding(SingleLayerSealRule(sealCount: 3), 'seal.rune'),
  ]);
  final layeredIntroduction =
      _plan('layered-introduction', BoardMechanicRole.introduce, [
        _binding(SingleLayerSealRule(sealCount: 2), 'seal.rune'),
        _binding(LayeredSealRule(sealCount: 1, layers: 2), 'seal.layered-rune'),
      ]);
  final layeredGuided = _plan('layered-guided', BoardMechanicRole.guided, [
    _binding(LayeredSealRule(sealCount: 2, layers: 2), 'seal.layered-rune'),
  ]);
  final lineIntroduction = _plan(
    'line-introduction',
    BoardMechanicRole.introduce,
    [_binding(LinePowerRule(requiredActivations: 1), 'power.sun-line')],
  );
  final validMix = _plan('known-mechanic-mix', BoardMechanicRole.mixed, [
    _binding(LayeredSealRule(sealCount: 1, layers: 2), 'seal.layered-rune'),
    _binding(LinePowerRule(requiredActivations: 1), 'power.sun-line'),
  ]);

  const sequenceValidator = BoardMechanicSequenceValidator();
  _expect(
    sequenceValidator.validate([
      baseline,
      layeredIntroduction,
      layeredGuided,
      lineIntroduction,
      validMix,
    ]).isEmpty,
    'individually introduced mechanics should be allowed to mix later',
  );

  final prematureMix = _plan('premature-mix', BoardMechanicRole.mixed, [
    _binding(
      AdjacentHitBlockerRule(blockerCount: 2, durability: 1),
      'blocker.forest-vine',
    ),
    _binding(LinePowerRule(requiredActivations: 1), 'power.sun-line'),
  ]);
  final prematureIssues = sequenceValidator.validate([baseline, prematureMix]);
  _expect(
    prematureIssues.length == 1 &&
        prematureIssues.single.code ==
            BoardMechanicSequenceIssueCode.mixedBeforeSoloIntroduction &&
        prematureIssues.single.mechanicIds.length == 2,
    'a combination must be rejected until each mechanic has a solo introduction',
  );

  _expectThrows(
    () => _plan('two-at-once', BoardMechanicRole.introduce, [
      _binding(LayeredSealRule(sealCount: 1, layers: 2), 'seal.layered-rune'),
      _binding(LinePowerRule(requiredActivations: 1), 'power.sun-line'),
    ]),
    'an introduction stage must contain exactly one advanced mechanic',
  );

  final capabilities = currentDiscoveryBoardMechanics;
  _expect(
    capabilities.capabilityFor(BoardMechanicId.singleLayerSeal).supportState ==
        BoardMechanicSupportState.supported,
    'the single-layer core remains supported',
  );
  for (final mechanicId in const [
    BoardMechanicId.layeredSeal,
    BoardMechanicId.linePower,
  ]) {
    _expect(
      capabilities.capabilityFor(mechanicId).supportState ==
          BoardMechanicSupportState.supported,
      '${mechanicId.name} has executable paired fixtures',
    );
  }
  _expect(
    capabilities
            .capabilityFor(BoardMechanicId.adjacentHitBlocker)
            .supportState ==
        BoardMechanicSupportState.supported,
    'Adjacent-hit covers are implemented; fixed blockers remain planned.',
  );
  for (final mechanicId in const [
    BoardMechanicId.swapLock,
    BoardMechanicId.fixedBlocker,
    BoardMechanicId.portal,
    BoardMechanicId.conveyor,
  ]) {
    _expect(
      capabilities.capabilityFor(mechanicId).supportState ==
          BoardMechanicSupportState.planned,
      '${mechanicId.name} should remain planned',
    );
  }
  _expect(
    capabilities.supportsForPlay(baseline),
    'the current runtime should play the single-layer baseline',
  );
  _expect(
    capabilities.supportsForPlay(layeredIntroduction) &&
        capabilities.supportsForPlay(lineIntroduction) &&
        capabilities.supportsForPlay(validMix),
    'two-layer seals, four-match powers and their mix are executable',
  );
  _expect(
    !capabilities.supportsForPlay(
      _plan('three-layers', BoardMechanicRole.introduce, [
        _binding(LayeredSealRule(sealCount: 1, layers: 3), 'seal.three'),
      ]),
    ),
    'Unverified layer counts remain gated.',
  );

  final vinePlan = _plan('vine-skin', BoardMechanicRole.introduce, [
    _binding(
      AdjacentHitBlockerRule(blockerCount: 3, durability: 1),
      'blocker.forest-vine',
    ),
  ]);
  final coralPlan = _plan('coral-skin', BoardMechanicRole.introduce, [
    _binding(
      AdjacentHitBlockerRule(blockerCount: 3, durability: 1),
      'blocker.island-coral',
    ),
  ]);
  _expect(
    vinePlan.logicalSignature == coralPlan.logicalSignature,
    'regional skins must not change the logical mechanic signature',
  );

  _expectThrows(
    () => BoardMechanicBinding(
      rule: LayeredSealRule(sealCount: 1, layers: 2),
      skin: BoardMechanicSkin(
        key: 'wrong-skin',
        mechanicId: BoardMechanicId.linePower,
      ),
    ),
    'a skin must target the same mechanic as its rule',
  );

  stdout.writeln(
    'Board mechanic model verification passed: solo introduction order, '
    'skin separation, and supported/modelOnly/planned capabilities.',
  );
}

BoardMechanicPlan _plan(
  String id,
  BoardMechanicRole role,
  List<BoardMechanicBinding> bindings,
) => BoardMechanicPlan(id: id, role: role, bindings: bindings);

BoardMechanicBinding _binding(BoardMechanicRule rule, String skinKey) =>
    BoardMechanicBinding(
      rule: rule,
      skin: BoardMechanicSkin(key: skinKey, mechanicId: rule.mechanicId),
    );

void _expect(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}

void _expectThrows(void Function() action, String message) {
  try {
    action();
  } on ArgumentError {
    return;
  }
  throw StateError(message);
}
