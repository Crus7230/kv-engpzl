import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/discovery/data/discovery_runtime_catalog.dart';
import 'package:kvm/features/discovery/domain/discovery_models.dart';
import 'package:kvm/features/discovery/presentation/engine_discovery_puzzle_view_model.dart';
import 'package:kvm/features/discovery/presentation/stage_session_controller.dart';
import 'package:kvm/features/progress/data/progress_repository.dart';

void _swap(EngineDiscoveryPuzzleViewModel model, DiscoveryTutorialStep step) {
  model.selectGem(step.from.row * model.boardColumns + step.from.column);
  model.selectGem(step.to.row * model.boardColumns + step.to.column);
}

void main() {
  test(
    'a versionless checkpoint selects v1 rules and preserves board and expression',
    () async {
      final stage = initialCampaign.stageById('r01-c01-s04')!;
      final old = EngineDiscoveryPuzzleViewModel(
        stage: stage,
        boardConfig: DiscoveryBoardConfig.compactPhone,
        rulesVersion: 1,
      );
      addTearDown(old.dispose);
      final variant = old.stage.boardVariants.variants.first;
      final runtime = legacyDiscoveryRuntimeCatalog.resolve(old.stage);
      _swap(old, runtime.referencePathFor!(variant).first);
      old.addBlockToAnswer(old.discoveredBlocks.first.id);
      final checkpoint = {
        ...old.exportSession(),
        'attemptId': 'old-rules-attempt',
      };
      expect(checkpoint.containsKey('rulesVersion'), isFalse);
      final repository = ProgressRepository(MemoryKeyValueSaveStore());
      final restored = StageSessionController(
        repository: repository,
        stage: stage,
        boardConfig: variant.config,
        savedSession: checkpoint,
        onContinue: () {},
        onSaveError: (error) => fail('$error'),
      );
      addTearDown(restored.dispose);
      expect(restored.rulesVersion, 1);
      expect(restored.exportSession(), old.exportSession());
      expect(restored.attemptId, 'old-rules-attempt');
      await restored.checkpoint();
      expect(
        (await repository.load()).activeSession!['boardState'],
        checkpoint['boardState'],
      );
    },
  );

  for (final id in [
    'r01-c02-s02',
    'r01-c02-s09',
    'r01-c02-s10',
    'r01-c04-s06',
  ]) {
    test(
      '$id v3 restores stationary covers, all power counters and the same attempt',
      () {
        final stage = initialCampaign.stageById(id)!;
        final source = EngineDiscoveryPuzzleViewModel(
          stage: stage,
          boardConfig: DiscoveryBoardConfig.compactPhone,
        );
        addTearDown(source.dispose);
        final runtime = discoveryRuntimeCatalog.resolve(stage);
        final variant = stage.boardVariants.variants.first;
        for (final step in runtime.referencePathFor!(variant))
          _swap(source, step);
        source.addBlockToAnswer(source.discoveredBlocks.first.id);
        final saved = {...source.exportSession(), 'attemptId': 'new-$id'};
        expect(saved['rulesVersion'], 3);
        final restored = StageSessionController(
          repository: ProgressRepository(MemoryKeyValueSaveStore()),
          stage: stage,
          boardConfig: variant.config,
          savedSession: saved,
          onContinue: () {},
          onSaveError: (_) {},
        );
        addTearDown(restored.dispose);
        expect(restored.exportSession(), source.exportSession());
        expect(restored.attemptId, 'new-$id');
      },
    );
  }

  test(
    'a future rules version is rejected without rewriting its save',
    () async {
      final repository = ProgressRepository(MemoryKeyValueSaveStore());
      final stage = initialCampaign.stageById('r01-c01-s01')!;
      final saved = {
        'rulesVersion': 999,
        'stageId': stage.id,
        'attemptId': 'future',
      };
      await repository.update((save) => save.copyWith(activeSession: saved));
      expect(
        () => StageSessionController(
          repository: repository,
          stage: stage,
          boardConfig: DiscoveryBoardConfig.compactPhone,
          savedSession: saved,
          onContinue: () {},
          onSaveError: (_) {},
        ),
        throwsFormatException,
      );
      expect((await repository.load()).activeSession, saved);
    },
  );
}
