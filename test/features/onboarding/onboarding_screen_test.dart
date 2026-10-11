import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/companions/data/companion_catalog.dart';
import 'package:kvm/features/onboarding/presentation/expedition_onboarding_screen.dart';
import 'package:kvm/features/progress/domain/progress_models.dart';

void _viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(680, 300);
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _show(
  WidgetTester tester, {
  required SaveEnvelopeV1 save,
  ValueChanged<String>? onChoosePlayer,
  VoidCallback? onStartTutorial,
  VoidCallback? onDepart,
  bool saving = false,
  String? errorMessage,
}) async {
  _viewport(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: ExpeditionOnboardingScreen(
        save: save,
        onChoosePlayer: onChoosePlayer ?? (_) {},
        onStartTutorial: onStartTutorial ?? () {},
        onDepart: onDepart ?? () {},
        saving: saving,
        errorMessage: errorMessage,
      ),
    ),
  );
  if (saving) {
    await tester.pump(const Duration(milliseconds: 200));
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('browses all 26 inherited profiles without granting companions', (
    tester,
  ) async {
    final save = SaveEnvelopeV1.initial();
    final before = save.toJson();
    final choices = <String>[];
    await _show(tester, save: save, onChoosePlayer: choices.add);
    expect(companionProfiles.length, 26);
    expect(find.text('26명 중 한 명을 선택해요'), findsOneWidget);
    expect(find.text('D · Delta'), findsOneWidget);
    expect(find.textContaining('ESFJ', findRichText: true), findsOneWidget);
    expect(find.textContaining('떡볶이', findRichText: true), findsOneWidget);
    expect(choices, isEmpty);

    final juliett = find.byKey(const ValueKey('onboarding-player-CHAR_J'));
    await tester.scrollUntilVisible(
      juliett,
      100,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('onboarding-player-grid')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(juliett);
    await tester.pumpAndSettle();
    expect(find.text('J · Juliett'), findsOneWidget);
    expect(find.textContaining('ISFJ', findRichText: true), findsOneWidget);
    expect(find.textContaining('김밥', findRichText: true), findsOneWidget);
    expect(choices, isEmpty);
    await tester.tap(find.byKey(const ValueKey('onboarding-primary-action')));
    expect(choices, ['CHAR_J']);
    expect(save.toJson(), before);
    expect(save.unlockedCharacterIds, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom player choice remains reachable at low height', (
    tester,
  ) async {
    final choices = <String>[];
    await _show(
      tester,
      save: SaveEnvelopeV1.initial(),
      onChoosePlayer: choices.add,
    );
    final zulu = find.byKey(const ValueKey('onboarding-player-CHAR_Z'));
    await tester.scrollUntilVisible(
      zulu,
      180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('onboarding-player-grid')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(zulu);
    await tester.pumpAndSettle();
    expect(find.text('Z · Zulu'), findsOneWidget);
    final button = find.byKey(const ValueKey('onboarding-primary-action'));
    expect(tester.getBottomRight(button).dy, lessThanOrEqualTo(300));
    await tester.tap(button);
    expect(choices, ['CHAR_Z']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chosen player starts real first-stage callback, not departure', (
    tester,
  ) async {
    var tutorialStarts = 0;
    var departures = 0;
    var playerChoices = 0;
    await _show(
      tester,
      save: SaveEnvelopeV1.initial().copyWith(playerCharacterId: 'CHAR_J'),
      onChoosePlayer: (_) => playerChoices++,
      onStartTutorial: () => tutorialStarts++,
      onDepart: () => departures++,
    );
    expect(find.text('첫 문제 풀어보기'), findsOneWidget);
    expect(find.text('1 · 이웃한 보석 교환'), findsOneWidget);
    expect(find.text('2 · 필요한 조각 발굴'), findsOneWidget);
    expect(find.text('3 · 문장을 식으로'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-player-grid')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('onboarding-primary-action')));
    expect(tutorialStarts, 1);
    expect(departures, 0);
    expect(playerChoices, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'active first puzzle is offered as resume without changing save',
    (tester) async {
      final save = SaveEnvelopeV1.initial().copyWith(
        playerCharacterId: 'CHAR_D',
        activeSession: {'stageId': 'r01-c01-s01', 'movesRemaining': 9},
      );
      final before = save.toJson();
      var resumes = 0;
      await _show(tester, save: save, onStartTutorial: () => resumes++);
      expect(find.text('첫 문제 이어서 풀기'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('onboarding-primary-action')));
      expect(resumes, 1);
      expect(save.toJson(), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'first-stage completion gates departure and keeps other records',
    (tester) async {
      final save = SaveEnvelopeV1.initial().copyWith(
        playerCharacterId: 'CHAR_A',
        completedStageIds: const ['r01-c01-s01'],
        bestStars: const {'r01-c01-s01': 3},
        unlockedCharacterIds: const ['CHAR_D'],
        restoredNodeIds: const ['existing-node'],
      );
      final before = save.toJson();
      var departures = 0;
      await _show(tester, save: save, onDepart: () => departures++);
      expect(find.text('계산의 평원으로 출발'), findsOneWidget);
      expect(find.text('첫 번째 관계를 찾았어요.'), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('onboarding-primary-action')));
      expect(departures, 1);
      expect(save.toJson(), before);
      expect(save.onboardingCompleted, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saving disables selection and the fixed action button', (
    tester,
  ) async {
    final choices = <String>[];
    await _show(
      tester,
      save: SaveEnvelopeV1.initial(),
      saving: true,
      onChoosePlayer: choices.add,
    );
    await tester.tap(find.byKey(const ValueKey('onboarding-player-CHAR_A')));
    await tester.pump();
    expect(find.text('D · Delta'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('onboarding-primary-action')),
    );
    expect(button.onPressed, isNull);
    expect(choices, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recoverable save error is visible without resetting progress', (
    tester,
  ) async {
    final save = SaveEnvelopeV1.initial().copyWith(playerCharacterId: 'CHAR_D');
    var retries = 0;
    await _show(
      tester,
      save: save,
      errorMessage: '저장하지 못했어요. 다시 시도해 주세요.',
      onStartTutorial: () => retries++,
    );
    expect(find.text('저장하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-primary-action')));
    expect(retries, 1);
    expect(save.playerCharacterId, 'CHAR_D');
    expect(tester.takeException(), isNull);
  });
}
