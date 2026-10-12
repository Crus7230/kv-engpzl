import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/core/theme/app_theme.dart';
import 'package:kvm/features/companions/companions.dart';
import 'package:kvm/features/progress/progress.dart';

Widget _host(Widget child, double scale) => MaterialApp(
  theme: AppTheme.light(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: child,
);

void main() {
  for (final size in const [
    Size(680, 300),
    Size(720, 320),
    Size(800, 360),
    Size(960, 432),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('companion collection fits $size at $scale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final save = SaveEnvelopeV1(
          playerCharacterId: 'CHAR_A',
          onboardingCompleted: true,
          unlockedCharacterIds: [
            'CHAR_A',
            'CHAR_D',
            'CHAR_J',
            'CHAR_L',
            'CHAR_U',
          ],
          completedStageIds: ['r01-c01-s10', 'r01-c03-s10', 'r01-c05-s10'],
        );
        String? replayed;
        String? selectedPlayer;
        await tester.pumpWidget(
          _host(
            CompanionCollectionScreen(
              save: save,
              onBack: () {},
              onReplayArrival: (id) => replayed = id,
              onSelectPlayer: (id) => selectedPlayer = id,
            ),
            scale,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('companion-CHAR_D')));
        await tester.pumpAndSettle();
        expect(find.text('동료 도감'), findsOneWidget);
        expect(find.text('Delta'), findsWidgets);
        expect(find.text('ESFJ'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final changeAvatar = find.byKey(const Key('select-player-CHAR_D'));
        await tester.ensureVisible(changeAvatar);
        await tester.pumpAndSettle();
        await tester.tap(changeAvatar);
        expect(selectedPlayer, 'CHAR_D');
        expect(save.playerCharacterId, 'CHAR_A'); // Only the parent commits.
        await tester.ensureVisible(find.text('첫 만남 다시 보기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('첫 만남 다시 보기'));
        expect(replayed, 'CHAR_D');
        await tester.tap(find.text('전체'));
        await tester.pumpAndSettle();
        final roster = find.byKey(const Key('companion-roster'));
        await tester.scrollUntilVisible(
          find.byKey(const Key('companion-CHAR_B')),
          60,
          scrollable: find
              .descendant(of: roster, matching: find.byType(Scrollable))
              .first,
        );
        await tester.ensureVisible(find.byKey(const Key('companion-CHAR_B')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('companion-CHAR_B')));
        await tester.pumpAndSettle();
        expect(find.text('R2 C01 완료 후 구조'), findsOneWidget);
        expect(find.text('ISTJ'), findsNothing);
        expect(find.byKey(const Key('select-player-CHAR_B')), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('D and J arrival fit $size at $scale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        for (final id in ['CHAR_D', 'CHAR_J']) {
          var continued = false;
          await tester.pumpWidget(
            _host(
              CompanionArrivalScreen(
                recruitment: companionRecruitmentById(id)!,
                onContinue: () => continued = true,
              ),
              scale,
            ),
          );
          await tester.pumpAndSettle();
          final button = find.byKey(const Key('companion-arrival-continue'));
          expect(tester.getRect(button).height, greaterThanOrEqualTo(48));
          expect(tester.getRect(button).bottom, lessThanOrEqualTo(size.height));
          await tester.tap(button);
          expect(continued, isTrue);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets(
    'selected player is never offered a rescue replay; saved errors allow retry',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(680, 300);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final save = SaveEnvelopeV1(
        playerCharacterId: 'CHAR_D',
        unlockedCharacterIds: ['CHAR_D'],
        completedStageIds: ['r01-c01-s10'],
      );
      await tester.pumpWidget(
        _host(
          CompanionCollectionScreen(
            save: save,
            onBack: () {},
            onReplayArrival: (_) {},
          ),
          1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('첫 만남 다시 보기'), findsNothing);
      await tester.pumpWidget(
        _host(
          CompanionArrivalScreen(
            recruitment: companionRecruitmentById('CHAR_J')!,
            saving: true,
            errorMessage: '저장하지 못했어요. 다시 시도해 주세요.',
            onContinue: () {},
          ),
          1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('companion-arrival-continue')),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('기록하는 중'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
