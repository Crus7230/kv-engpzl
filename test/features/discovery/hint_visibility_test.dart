import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/discovery/domain/discovery_models.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_screen.dart';
import 'package:kvm/features/discovery/presentation/engine_discovery_puzzle_view_model.dart';
import 'package:kvm/features/discovery/presentation/stage_session_controller.dart';
import 'package:kvm/features/progress/data/progress_repository.dart';

void main() {
  for (final size in [const Size(800, 360), const Size(680, 300)]) {
    for (final mathHint in [false, true]) {
      testWidgets(
        'hint toggles at $size after ${mathHint ? 'last math' : 'board'} hint',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final model = EngineDiscoveryPuzzleViewModel(
            stage: initialCampaign.stageById('r01-c01-s02')!,
            rulesVersion: 5,
            boardSeed: 42,
            boardConfig: DiscoveryBoardConfig.compactPhone,
          );
          addTearDown(model.dispose);
          if (mathHint) {
            for (final step in model.referencePath) {
              model.selectGem(
                step.from.row * model.boardColumns + step.from.column,
              );
              model.selectGem(
                step.to.row * model.boardColumns + step.to.column,
              );
            }
            for (var i = 0; i < 3; i++) model.revealHint();
          }
          await tester.pumpWidget(
            MaterialApp(home: DiscoveryPuzzleScreen(viewModel: model)),
          );
          await tester.pumpAndSettle();
          if (!mathHint) {
            await tester.tap(find.byTooltip('힌트 보기'));
            await tester.pumpAndSettle();
          }
          expect(model.isHintVisible, isTrue);
          final before = model.exportSession();
          final evidence = model.attemptMetrics;
          await tester.tap(find.byTooltip('힌트 닫기'));
          await tester.pumpAndSettle();
          expect(model.isHintVisible, isFalse);
          expect(find.byTooltip('힌트 보기'), findsOneWidget);
          expect(model.exportSession()['boardState'], before['boardState']);
          expect(
            model.exportSession()['answerTokenIds'],
            before['answerTokenIds'],
          );
          expect(
            model.attemptMetrics.highestMathHintTierUsed,
            evidence.highestMathHintTierUsed,
          );
          expect(
            model.attemptMetrics.usedDirectPathHint,
            evidence.usedDirectPathHint,
          );
          await tester.tap(find.byTooltip('힌트 보기'));
          await tester.pumpAndSettle();
          expect(model.isHintVisible, isTrue);
          if (mathHint) expect(model.exportSession()['hintLevel'], 3);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  test(
    'restored hint can close and checkpoint keeps assistance evidence',
    () async {
      final store = MemoryKeyValueSaveStore();
      final stage = initialCampaign.stageById('r01-c01-s02')!;
      final source = EngineDiscoveryPuzzleViewModel(
        stage: stage,
        rulesVersion: 5,
        boardSeed: 42,
        boardConfig: DiscoveryBoardConfig.compactPhone,
      );
      addTearDown(source.dispose);
      source.revealHint();
      final controller = StageSessionController(
        repository: ProgressRepository(store),
        stage: stage,
        boardConfig: DiscoveryBoardConfig.compactPhone,
        savedSession: {...source.exportSession(), 'attemptId': 'hint-restore'},
        newSessionRulesVersion: 5,
        onContinue: () {},
        onSaveError: (error) => fail('$error'),
      );
      addTearDown(controller.dispose);
      expect(controller.isHintVisible, isTrue);
      controller.hideHint();
      await controller.flush();
      final checkpoint = (await ProgressRepository(
        store,
      ).load()).activeSession!;
      expect(checkpoint['usedDirectPathHint'], isTrue);
      final resumed = EngineDiscoveryPuzzleViewModel(
        stage: stage,
        rulesVersion: 5,
        boardSeed: 42,
        boardConfig: DiscoveryBoardConfig.compactPhone,
      );
      addTearDown(resumed.dispose);
      resumed.restoreSession(checkpoint);
      expect(resumed.isHintVisible, isFalse);
      expect(resumed.attemptMetrics.usedDirectPathHint, isTrue);
    },
  );
}
