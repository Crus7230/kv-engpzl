import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/discovery/domain/discovery_models.dart';
import 'package:kvm/features/discovery/presentation/engine_discovery_puzzle_view_model.dart';
import 'package:kvm/features/discovery/presentation/stage_session_controller.dart';
import 'package:kvm/features/progress/progress.dart';

void main() {
  for (final version in [5, 6]) {
    for (final id in ['r01-c01-s02', 'r01-c04-s04', 'r02-c06-s10']) {
      test('v$version $id restores exact board, seed and expression', () {
        final stage = initialCampaign.stageById(id)!;
        final source = EngineDiscoveryPuzzleViewModel(
          stage: stage,
          rulesVersion: version,
          boardSeed: 42,
          boardConfig: DiscoveryBoardConfig.standardPhone,
        );
        addTearDown(source.dispose);
        final move = source.referencePath.first;
        source.selectGem(
          move.from.row * source.boardColumns + move.from.column,
        );
        source.selectGem(move.to.row * source.boardColumns + move.to.column);
        if (source.discoveredBlocks.isNotEmpty)
          source.addBlockToAnswer(source.discoveredBlocks.first.id);
        final saved = {...source.exportSession(), 'attemptId': 'v$version-$id'};
        final restored = StageSessionController(
          repository: ProgressRepository(MemoryKeyValueSaveStore()),
          stage: stage,
          boardConfig: DiscoveryBoardConfig.standardPhone,
          savedSession: saved,
          newSessionRulesVersion: 6,
          onContinue: () {},
          onSaveError: (e) => fail('$e'),
        );
        addTearDown(restored.dispose);
        expect(restored.rulesVersion, version);
        expect(restored.exportSession(), source.exportSession());
        expect(saved['fixtureId'], endsWith('-random$version'));
      });
    }
  }
}
