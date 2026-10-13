import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/app/math_adventure_app.dart';
import 'package:kvm/core/audio/audio_controller.dart';
import 'package:kvm/core/audio/audio_settings.dart';
import 'package:kvm/core/branding/adventure_intro_screen.dart';
import 'package:kvm/core/layout/landscape_game_viewport.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/companions/presentation/companion_screens.dart';
import 'package:kvm/features/garden/data/garden_catalog.dart';
import 'package:kvm/features/garden/presentation/adventure_collection_screens.dart';
import 'package:kvm/features/garden/presentation/collection_storybook_art.dart';
import 'package:kvm/features/garden/presentation/garden_screens.dart';
import 'package:kvm/features/progress/domain/adventure_collection_service.dart';
import 'package:kvm/features/progress/progress.dart';

class _SilentAudioBackend implements AudioBackend {
  @override
  bool get mediaAvailable => false;
  @override
  bool get supportsDownload => false;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> downloadAssets() async {}
  @override
  Future<void> setMusic({
    required String? assetPath,
    required double volume,
    required bool active,
  }) async {}
  @override
  Future<void> playEffect(PuzzleSound sound, double volume) async {}
  @override
  void unlock() {}
  @override
  Future<void> suspend() async {}
  @override
  Future<void> dispose() async {}
}

SaveEnvelopeV1 _player() => SaveEnvelopeV1.initial().copyWith(
  playerCharacterId: 'CHAR_D',
  starterCharacterId: 'CHAR_D',
  onboardingCompleted: true,
  unlockedCharacterIds: const ['CHAR_D'],
);

void _viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _host(Widget child, double scale, {bool reduceMotion = false}) =>
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduceMotion,
        ),
        child: LandscapeGameViewport(child: child!),
      ),
      home: child,
    );

double _opacity(WidgetTester tester, String part) =>
    tester.widget<Opacity>(find.byKey(ValueKey('intro-$part-reveal'))).opacity;

void main() {
  testWidgets('storybook seed grows once, replays on selection, and settles', (
    tester,
  ) async {
    _viewport(tester, const Size(680, 300));
    Widget scene(String seed) => _host(
      Center(
        child: SizedBox(
          width: 140,
          height: 100,
          child: SeedGardenArt(seedId: seed, growth: 3, ready: true),
        ),
      ),
      1,
    );
    SeedGardenPainter painter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<SeedGardenPainter>()
        .single;

    await tester.pumpWidget(scene('first'));
    await tester.pump();
    expect(painter().progress, 0);
    await tester.pump(const Duration(milliseconds: 600));
    expect(painter().progress, inExclusiveRange(0, 1));
    final halfway = painter().progress;
    await tester.pumpWidget(scene('first'));
    expect(painter().progress, halfway);
    expect(await tester.pumpAndSettle(), lessThan(30));
    expect(painter().progress, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(scene('second'));
    expect(painter().progress, 0);
    await tester.pumpAndSettle();
    expect(painter().progress, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('storybook art is static with reduced motion', (tester) async {
    _viewport(tester, const Size(680, 300));
    await tester.pumpWidget(
      _host(
        const Center(
          child: SizedBox(
            width: 260,
            height: 90,
            child: PassportMapArt(
              chapterId: 'r01-c01',
              region: 1,
              chapter: 1,
              completed: 10,
              total: 10,
              earned: true,
              discovered: [true, true, true, true],
              recorded: [true, true, false, false],
            ),
          ),
        ),
        1.3,
        reduceMotion: true,
      ),
    );
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<PassportMapPainter>()
        .single;
    expect(painter.progress, 1);
    expect(await tester.pumpAndSettle(), lessThan(5));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('legacy intro reveal order survives status updates and settles', (
    tester,
  ) async {
    _viewport(tester, const Size(680, 300));
    await tester.pumpWidget(
      _host(const AdventureIntroScreen(status: '준비 중'), 1),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(_opacity(tester, 'logo'), greaterThan(0));
    expect(_opacity(tester, 'title'), 0);
    await tester.pump(const Duration(milliseconds: 600));
    expect(_opacity(tester, 'title'), greaterThan(0));
    expect(_opacity(tester, 'status'), 0);
    final titleOpacity = _opacity(tester, 'title');
    await tester.pumpWidget(
      _host(const AdventureIntroScreen(status: '다음 준비'), 1),
    );
    expect(_opacity(tester, 'title'), titleOpacity);
    await tester.pumpAndSettle();
    for (final part in ['logo', 'title', 'tagline', 'status']) {
      expect(_opacity(tester, part), 1);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'reduced motion reveals intro immediately without an ongoing ticker',
    (tester) async {
      _viewport(tester, const Size(680, 300));
      await tester.pumpWidget(
        _host(
          const AdventureIntroScreen(status: '준비'),
          1.3,
          reduceMotion: true,
        ),
      );
      for (final part in ['logo', 'title', 'tagline', 'status']) {
        expect(_opacity(tester, part), 1);
      }
      expect(await tester.pumpAndSettle(), lessThan(5));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final size in const [Size(680, 300), Size(800, 360), Size(900, 700)]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('seed collection and passport fit $size text $scale', (
        tester,
      ) async {
        _viewport(tester, size);
        final save = _player().copyWith(
          completedStageIds: initialCampaign.regions.first.chapters.first.stages
              .map((stage) => stage.id),
          unlockedStageIds: const ['r01-c01-s01', 'r01-c02-s01'],
          dailyReviewActions: const {'2026-10-12': 1},
        );
        const service = AdventureCollectionService();
        final now = DateTime(2026, 10, 13);
        var taps = 0;
        await tester.pumpWidget(
          _host(
            MemorySeedsScreen(
              collection: service.memorySeeds(save, initialCampaign, now: now),
              onBack: () {},
              onReview: () => taps++,
              onExplore: () {},
            ),
            scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('seed-garden-art')), findsOneWidget);
        expect(find.byKey(const ValueKey('petal-garland-art')), findsOneWidget);
        final play = find.byKey(const ValueKey('memory-seed-play'));
        await tester.tap(play);
        expect(taps, 1);
        expect(tester.getRect(play).height, greaterThanOrEqualTo(40));
        expect(tester.takeException(), isNull);
        final seeds = service
            .memorySeeds(save, initialCampaign, now: now)
            .seeds;
        for (final seed in seeds) {
          final seedTile = find.byKey(ValueKey('memory-seed-${seed.skillId}'));
          await tester.scrollUntilVisible(
            seedTile,
            70,
            scrollable: find.descendant(
              of: find.byKey(const ValueKey('memory-seed-collection')),
              matching: find.byType(Scrollable),
            ),
          );
          await Scrollable.ensureVisible(
            tester.element(seedTile),
            alignment: .5,
          );
          await tester.pumpAndSettle();
          await tester.tap(seedTile);
          await tester.pumpAndSettle();
          expect(
            tester.widget<SeedGardenArt>(find.byType(SeedGardenArt)).seedId,
            seed.skillId,
          );
          expect(tester.takeException(), isNull);
        }

        await tester.pumpWidget(
          _host(
            ExpeditionTracesScreen(
              journal: service.journal(
                save,
                initialCampaign,
                gardenDefinitions,
                now: now,
              ),
              onBack: () {},
              onRegion: (_) => taps++,
              onRestore: (_) {},
              onCompanions: () {},
            ),
            scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('passport-map-art')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('expedition-passport')),
          findsOneWidget,
        );
        final explore = find.byKey(const ValueKey('passport-explore'));
        await tester.ensureVisible(explore);
        await tester.pumpAndSettle();
        await tester.tap(explore);
        expect(taps, 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets(
    'both menus open before a reward exists and companions return to passport',
    (tester) async {
      _viewport(tester, const Size(800, 360));
      final store = MemoryKeyValueSaveStore();
      final audio = AudioController(_SilentAudioBackend());
      await tester.pumpWidget(
        MathAdventureApp(
          repository: ProgressRepository(store, initialFactory: _player),
          audioController: audio,
          assetBundle: rootBundle,
          now: () => DateTime(2026, 10, 13),
        ),
      );
      await tester.pumpAndSettle();
      final world = tester.widget<WorldMapScreen>(find.byType(WorldMapScreen));
      expect(world.onReview, isNotNull);
      expect(world.onTraces, isNotNull);
      world.onReview!();
      await tester.pumpAndSettle();
      expect(find.byType(MemorySeedsScreen), findsOneWidget);
      expect(
        find.byType(CampaignRegionGardenScreen, skipOffstage: false),
        findsNothing,
      );
      tester.widget<MemorySeedsScreen>(find.byType(MemorySeedsScreen)).onBack();
      await tester.pumpAndSettle();
      tester.widget<WorldMapScreen>(find.byType(WorldMapScreen)).onTraces!();
      await tester.pumpAndSettle();
      expect(find.byType(ExpeditionTracesScreen), findsOneWidget);
      tester
          .widget<ExpeditionTracesScreen>(find.byType(ExpeditionTracesScreen))
          .onCompanions();
      await tester.pumpAndSettle();
      final companions = tester.widget<CompanionCollectionScreen>(
        find.byType(CompanionCollectionScreen),
      );
      companions.onBack();
      await tester.pumpAndSettle();
      expect(find.byType(ExpeditionTracesScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await audio.dispose();
    },
  );

  testWidgets(
    'an open map tooltip cannot survive a menu resize with stale constraints',
    (tester) async {
      _viewport(tester, const Size(900, 700));
      final audio = AudioController(_SilentAudioBackend());
      await tester.pumpWidget(
        MathAdventureApp(
          repository: ProgressRepository(
            MemoryKeyValueSaveStore(),
            initialFactory: _player,
          ),
          audioController: audio,
          assetBundle: rootBundle,
        ),
      );
      await tester.pumpAndSettle();
      final tooltip = find.descendant(
        of: find.byKey(const ValueKey('world-traces')),
        matching: find.byType(Tooltip),
      );
      tester.state<TooltipState>(tooltip).ensureTooltipVisible();
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(800, 360);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.widget<WorldMapScreen>(find.byType(WorldMapScreen)).onTraces!();
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(680, 300);
      await tester.pumpAndSettle();
      expect(find.byType(ExpeditionTracesScreen), findsOneWidget);
      tester
          .widget<ExpeditionTracesScreen>(find.byType(ExpeditionTracesScreen))
          .onBack();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await audio.dispose();
    },
  );

  testWidgets(
    'passport restoration returns to its journal without duplicate rewards',
    (tester) async {
      _viewport(tester, const Size(800, 360));
      final node = gardenDefinitions.first.restorationNodes.first;
      final receipt = CompletionReceipt(
        attemptId: 'passport-restoration',
        stageId: node.requiredStageId,
        stars: 1,
        firstCompletion: true,
        supportReviewNeeded: false,
        unlockedRestorationNodeIds: [node.id],
      );
      final store = MemoryKeyValueSaveStore();
      final repository = ProgressRepository(
        store,
        initialFactory: () => _player().copyWith(
          completedStageIds: const ['r01-c01-s01', 'r01-c01-s02'],
          rewardLedger: {receipt.attemptId: receipt},
        ),
      );
      final audio = AudioController(_SilentAudioBackend());
      await tester.pumpWidget(
        MathAdventureApp(
          repository: repository,
          assetBundle: rootBundle,
          audioController: audio,
          now: () => DateTime(2026, 10, 13),
        ),
      );
      await tester.pumpAndSettle();
      final before = await repository.load();
      tester.widget<WorldMapScreen>(find.byType(WorldMapScreen)).onTraces!();
      await tester.pumpAndSettle();
      tester
          .widget<ExpeditionTracesScreen>(find.byType(ExpeditionTracesScreen))
          .onRestore(node.id);
      await tester.pumpAndSettle();
      tester
          .widget<RestorationRevealScreen>(find.byType(RestorationRevealScreen))
          .onFinish();
      await tester.pumpAndSettle();
      expect(find.byType(ExpeditionTracesScreen), findsOneWidget);
      final after = await repository.load();
      expect(after.restoredNodeIds, contains(node.id));
      expect(after.completedStageIds, before.completedStageIds);
      expect(after.rewardLedger.keys, before.rewardLedger.keys);
      expect(after.dailyActions, before.dailyActions);
      expect(after.masteryStates, before.masteryStates);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await audio.dispose();
    },
  );
}
