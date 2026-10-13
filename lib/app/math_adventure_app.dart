import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/branding/garden_branding.dart';
import '../core/theme/app_theme.dart';
import '../core/layout/landscape_game_viewport.dart';
import '../core/assets/retained_asset_bundle.dart';
import '../core/audio/audio_backend.dart';
import '../core/audio/audio_controller.dart';
import '../core/audio/audio_options.dart';
import '../core/audio/audio_scope.dart';
import '../core/audio/audio_settings.dart';
import '../core/audio/puzzle_haptics.dart';
import '../core/updates/app_update_service.dart';
import '../core/updates/startup_update_gate.dart';
import '../features/campaign/data/initial_campaign.dart';
import '../features/campaign/domain/campaign_models.dart';
import '../features/campaign/data/legacy_region_catalog.dart';
import '../features/discovery/domain/discovery_models.dart';
import '../features/discovery/data/discovery_runtime_catalog.dart';
import '../features/discovery/data/discovery_challenge_profile.dart';
import '../features/discovery/data/random_discovery_fixture.dart';
import '../features/garden/data/garden_catalog.dart';
import '../features/garden/domain/garden_models.dart';
import '../features/discovery/presentation/discovery_puzzle_screen.dart';
import '../features/discovery/presentation/stage_session_controller.dart';
import '../features/garden/presentation/garden_screens.dart';
import '../features/garden/presentation/adventure_collection_screens.dart';
import '../features/progress/domain/adventure_collection_service.dart';
import '../features/companions/companions.dart';
import '../features/exploration/data/r1_expedition_catalog.dart';
import '../features/onboarding/presentation/expedition_onboarding_screen.dart';
import '../features/progress/progress.dart';

void runMathAdventureApp() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]),
  );
  runApp(const MathAdventureApp());
}

class MathAdventureApp extends StatefulWidget {
  const MathAdventureApp({
    this.repository,
    this.campaign,
    this.assetBundle,
    this.now,
    this.updateService,
    this.audioController,
    super.key,
  });
  final ProgressRepository? repository;
  final CampaignDefinition? campaign;
  final AssetBundle? assetBundle;
  final DateTime Function()? now;
  final AppUpdateService? updateService;
  final AudioController? audioController;
  @override
  State<MathAdventureApp> createState() => _MathAdventureAppState();
}

class _StartupIssueScreen extends StatelessWidget {
  const _StartupIssueScreen({
    required this.title,
    required this.detail,
    required this.retryLabel,
    required this.onRetry,
  });

  final String title;
  final String detail;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.canvasBottom,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const GardenBrandMark(size: 64),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(detail),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: onRetry, child: Text(retryLabel)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

enum RenewalRoute {
  worldMap,
  regionGarden,
  briefing,
  puzzle,
  result,
  restoration,
  onboarding,
  companions,
  companionArrival,
  memorySeeds,
  expeditionTraces,
}

class _MathAdventureAppState extends State<MathAdventureApp>
    with WidgetsBindingObserver {
  late final ProgressRepository _repository;
  late final AudioController _audio;
  bool _startupReady = false;
  bool _audioDecisionAsked = false;
  bool _foreground = true;
  SaveEnvelopeV1? _save;
  Object? _loadError;
  String? _statusMessage;
  String _regionId = 'region-01-calculation';
  RenewalRoute _route = RenewalRoute.worldMap;
  StageSessionController? _session;
  CompletionReceipt? _receipt;
  bool _busy = false;
  Timer? _restTimer;
  AssetBundle? _assetBundle;
  Object? _assetError;
  bool _preparingAssets = false;
  bool _loadingProgress = false;
  StageDefinition? _selectedStage;
  String? _reviewTicketId;
  bool _isDailyReview = false;
  String? _restorationNodeId;
  CompanionRecruitment? _arrival;
  bool _arrivalReplay = false;
  RenewalRoute _companionReturnRoute = RenewalRoute.worldMap;
  RenewalRoute _restorationReturnRoute = RenewalRoute.regionGarden;
  CampaignDefinition get _campaign => widget.campaign ?? initialCampaign;
  bool get _usesPrototype => identical(_campaign, prototypeCampaign);
  bool get _needsOnboarding => !_usesPrototype && !_save!.onboardingCompleted;
  DateTime get _now => widget.now?.call() ?? DateTime.now();
  StageDefinition get _stage =>
      _selectedStage ??
      (_usesPrototype
          ? verticalSliceStage
          : _campaign.stages.firstWhere((s) => s.isPlayable));

  StageDefinition? _findStage(String? id) => id == verticalSliceStage.id
      ? verticalSliceStage
      : id == null
      ? null
      : _campaign.stageById(id);

  bool _canEnterStage(StageDefinition stage) =>
      _save!.unlockedStageIds.contains(stage.id) &&
      const CampaignAccessPolicy().canEnterStage(
        stage,
        _campaign,
        _save!.completedStageIds,
        usesLegacyBoardRules:
            _save!.activeSession?['stageId'] == stage.id &&
            (_save!.activeSession?['rulesVersion'] ?? 1) == 1,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _audio =
        widget.audioController ??
        AudioController(
          createAudioBackend(),
          onHaptic: playPuzzleHaptic,
          onError: (error) {
            assert(() {
              debugPrint('Audio unavailable (${error.runtimeType}).');
              return true;
            }());
          },
          onChanged: () {
            if (mounted) setState(() {});
          },
        );
    unawaited(_audio.initialize());
    _repository =
        widget.repository ?? ProgressRepository(SharedPreferencesSaveStore());
    unawaited(_load());
    unawaited(_prepareAssets());
    _restTimer = Timer(const Duration(minutes: 20), () {
      if (mounted)
        setState(() => _statusMessage = '정원은 저장되어 있어요. 잠시 쉬었다 이어가도 좋아요.');
    });
  }

  Future<void> _prepareAssets() async {
    if (_preparingAssets) return;
    _preparingAssets = true;
    if (mounted && _assetError != null) {
      setState(() => _assetError = null);
    }
    try {
      final bundle = widget.assetBundle ?? await RetainedAssetBundle.prepare();
      if (mounted)
        setState(() {
          _assetBundle = bundle;
          _assetError = null;
        });
    } catch (error) {
      if (mounted) setState(() => _assetError = error);
    } finally {
      _preparingAssets = false;
    }
  }

  Future<void> _downloadImageAssets(BuildContext context) async {
    if (_preparingAssets) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('탐험 에셋 받기'),
        content: const Text(
          '배경·캐릭터 약 15MB를 최초 한 번만 받습니다. 모바일 데이터가 사용될 수 있습니다. 이후 코드 업데이트에서는 기기에 저장된 에셋을 재사용합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('다운로드'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted || _preparingAssets) return;
    setState(() => _preparingAssets = true);
    try {
      final bundle = await RetainedAssetBundle.prepare(download: true);
      if (mounted)
        setState(() {
          _assetBundle = bundle;
          _assetError = null;
        });
    } catch (_) {
      if (mounted)
        setState(() => _assetError = const MissingRetainedAssetsException());
    } finally {
      if (mounted) setState(() => _preparingAssets = false);
    }
  }

  Future<void> _load() async {
    if (_loadingProgress) return;
    _loadingProgress = true;
    if (mounted && _loadError != null) {
      setState(() => _loadError = null);
    }
    try {
      if (!_usesPrototype) {
        await CampaignContentUpdateService(
          _repository,
          _campaign,
        ).reconcileUnlocks();
      }
      final save = _usesPrototype
          ? await _repository.load()
          : await CompanionProgressService(_repository).reconcileEligibility();
      if (mounted)
        setState(() {
          _save = save;
          _loadError = null;
          if (!_usesPrototype && !save.onboardingCompleted) {
            _route = RenewalRoute.onboarding;
          }
        });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    } finally {
      _loadingProgress = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _audio.setForeground(_foreground);
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(
        _session?.checkpoint().catchError(_onSaveError) ?? Future<void>.value(),
      );
    }
  }

  void _onSaveError(Object error) {
    assert(() {
      debugPrint('Progress operation failed (${error.runtimeType}): $error');
      return true;
    }());
    if (mounted)
      setState(
        () => _statusMessage = error is DiscoveryBoardGenerationException
            ? '랜덤 보드를 확인하지 못했어요. 기록은 유지됩니다. 다시 시작해 주세요.'
            : '저장을 완료하지 못했어요. 저장소를 확인하고 다시 시도해 주세요.',
      );
  }

  Future<void> _update(SaveEnvelopeV1 Function(SaveEnvelopeV1) change) async {
    final save = await _repository.update(change);
    if (mounted) setState(() => _save = save);
  }

  void _showRegion(String id) {
    _regionId = id;
    _returnToExpedition();
  }

  void _returnToExpedition() {
    if (!mounted) return;
    final arrival = _usesPrototype || _needsOnboarding
        ? null
        : nextUnviewedCompanionArrival(_save!, regionId: _regionId);
    setState(() {
      _arrival = arrival;
      _arrivalReplay = false;
      _route = _needsOnboarding
          ? RenewalRoute.onboarding
          : arrival != null
          ? RenewalRoute.companionArrival
          : RenewalRoute.regionGarden;
    });
  }

  void _navigateBack() {
    if (_busy) return;
    if (_route == RenewalRoute.puzzle) {
      unawaited(_exitPuzzle());
    } else if (_route == RenewalRoute.companions) {
      setState(() => _route = _companionReturnRoute);
    } else if (_route == RenewalRoute.companionArrival) {
      setState(() {
        _route = _arrivalReplay
            ? RenewalRoute.companions
            : RenewalRoute.regionGarden;
        _arrivalReplay = false;
      });
    } else if (_route == RenewalRoute.regionGarden ||
        _route == RenewalRoute.memorySeeds ||
        _route == RenewalRoute.expeditionTraces) {
      setState(() => _route = RenewalRoute.worldMap);
    } else if (_route == RenewalRoute.restoration) {
      if (_restorationReturnRoute == RenewalRoute.regionGarden) {
        _returnToExpedition();
      } else {
        setState(() => _route = _restorationReturnRoute);
      }
    } else if (_route != RenewalRoute.worldMap &&
        _route != RenewalRoute.onboarding) {
      _returnFromStage();
    }
  }

  void _returnFromStage() {
    if (!_usesPrototype && !_needsOnboarding && _isDailyReview) {
      setState(() => _route = RenewalRoute.memorySeeds);
    } else {
      _returnToExpedition();
    }
  }

  void _showCompanions() => setState(() {
    _arrivalReplay = false;
    _companionReturnRoute = switch (_route) {
      RenewalRoute.worldMap ||
      RenewalRoute.memorySeeds ||
      RenewalRoute.expeditionTraces => _route,
      _ => RenewalRoute.regionGarden,
    };
    _route = RenewalRoute.companions;
  });

  void _replayArrival(String id) {
    final arrival = companionRecruitmentById(id);
    if (arrival == null ||
        (_save!.starterCharacterId ?? _save!.playerCharacterId) == id ||
        !_save!.unlockedCharacterIds.contains(id) ||
        !isCompanionRecruitmentEligible(arrival, _save!.completedStageIds)) {
      return;
    }
    setState(() {
      _arrival = arrival;
      _arrivalReplay = true;
      _route = RenewalRoute.companionArrival;
    });
  }

  Future<void> _finishArrival() async {
    final arrival = _arrival;
    if (_busy || arrival == null) return;
    setState(() => _busy = true);
    try {
      final save = await CompanionProgressService(
        _repository,
      ).markArrivalViewed(arrival.characterId);
      if (!mounted) return;
      setState(() {
        _save = save;
        _statusMessage = null;
      });
      if (_arrivalReplay) {
        setState(() {
          _arrivalReplay = false;
          _route = RenewalRoute.companions;
        });
      } else {
        _returnToExpedition();
      }
    } catch (error) {
      _onSaveError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choosePlayer(String id) async {
    if (_busy || !_needsOnboarding || companionProfileById(id) == null) return;
    setState(() => _busy = true);
    try {
      await _update((save) {
        if (save.onboardingCompleted || save.playerCharacterId != null)
          return save;
        return save.copyWith(
          playerCharacterId: id,
          starterCharacterId: id,
          unlockedCharacterIds: {...save.unlockedCharacterIds, id},
        );
      });
      if (mounted) setState(() => _statusMessage = null);
    } catch (error) {
      _onSaveError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startTutorial() {
    if (_save!.playerCharacterId == null || _busy) return;
    final stage = _campaign.stageById('r01-c01-s01');
    if (stage == null || !_canEnterStage(stage)) return;
    setState(() {
      _selectedStage = stage;
      _reviewTicketId = null;
      _isDailyReview = false;
      _route = RenewalRoute.briefing;
    });
  }

  Future<void> _changePlayer(String id) async {
    if (_busy || _needsOnboarding) return;
    setState(() => _busy = true);
    try {
      final save = await CompanionProgressService(_repository).selectPlayer(id);
      if (mounted)
        setState(() {
          _save = save;
          _statusMessage = null;
        });
    } catch (error) {
      _onSaveError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _depart() async {
    if (_busy || !_needsOnboarding) return;
    setState(() => _busy = true);
    try {
      await _update((save) {
        if (save.playerCharacterId == null ||
            !save.completedStageIds.contains('r01-c01-s01'))
          return save;
        return save.copyWith(onboardingCompleted: true);
      });
      if (!_needsOnboarding) {
        if (mounted) setState(() => _statusMessage = null);
        _returnToExpedition();
      }
    } catch (error) {
      _onSaveError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showBriefing() {
    final active = _save!.activeSession;
    final rawStageId = active?['stageId'];
    final stage =
        _findStage(rawStageId is String ? rawStageId : null) ??
        (_usesPrototype ? verticalSliceStage : _regionalNextStage);
    if (stage == null) return;
    setState(() {
      _regionId = _regionForStage(stage);
      _selectedStage = stage;
      _reviewTicketId = active?['reviewTicketId'] is String
          ? active!['reviewTicketId'] as String
          : null;
      _isDailyReview = active?['isDailyReview'] == true;
      _route = RenewalRoute.briefing;
    });
  }

  Future<void> _openStage(
    BuildContext context,
    StageDefinition stage, {
    String? reviewTicketId,
    bool isReview = false,
  }) async {
    if (!_canEnterStage(stage)) return;
    final active = _save!.activeSession;
    if (active != null && active['stageId'] != stage.id) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('진행 중인 탐험이 있어요'),
          content: const Text('진행도와 정원은 유지됩니다. 작성 중인 퍼즐을 새 문제로 바꿀까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('이어서 풀기'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('새 문제 시작'),
            ),
          ],
        ),
      );
      if (replace != true) {
        _showBriefing();
        return;
      }
      try {
        await _update((save) => save.copyWith(clearActiveSession: true));
      } catch (error) {
        _onSaveError(error);
        return;
      }
    }
    if (!mounted) return;
    final resuming = active != null && active['stageId'] == stage.id;
    setState(() {
      _selectedStage = stage;
      _reviewTicketId = resuming
          ? (active['reviewTicketId'] is String
                ? active['reviewTicketId'] as String
                : null)
          : reviewTicketId;
      _isDailyReview = resuming ? active['isDailyReview'] == true : isReview;
      _regionId = _regionForStage(stage);
      _route = RenewalRoute.briefing;
    });
  }

  Future<void> _start(BuildContext context) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final save = await _repository.load();
      final saved = save.activeSession;
      if (saved != null && saved['stageId'] is! String)
        throw const FormatException('Missing saved stage ID.');
      final stage = saved == null
          ? _stage
          : _findStage(saved['stageId'] as String?);
      if (stage == null || !_canEnterStage(stage))
        throw const FormatException('Saved stage is unavailable.');
      final media = MediaQuery.of(context);
      final rows = saved?['rows'];
      final columns = saved?['columns'];
      final config = saved == null
          ? DiscoveryChallengeProfile.boardFor(
              stage,
              media.size.width - media.padding.horizontal,
              media.size.height - media.padding.vertical,
            )
          : rows is int &&
                columns is int &&
                ((rows == 5 && columns == 5) ||
                    (rows == 6 && columns == 6) ||
                    (saved['rulesVersion'] == 4 ||
                            saved['rulesVersion'] == 5) &&
                        rows == 7 &&
                        columns == 7)
          ? DiscoveryBoardConfig(rows: rows, columns: columns)
          : throw const FormatException('Invalid saved board dimensions.');
      final session = StageSessionController(
        repository: _repository,
        stage: stage,
        reviewTicketId: _reviewTicketId,
        isDailyReview: _isDailyReview,
        boardConfig: config,
        savedSession: saved,
        newSessionRulesVersion: 5,
        onContinue: () => unawaited(_complete()),
        onSaveError: _onSaveError,
      );
      try {
        await session.checkpoint();
      } catch (_) {
        session.dispose();
        rethrow;
      }
      if (!mounted) {
        session.dispose();
        return;
      }
      _session?.dispose();
      setState(() {
        _session = session;
        _selectedStage = stage;
        _save = save;
        _route = RenewalRoute.puzzle;
        _statusMessage = null;
      });
    } on FormatException {
      if (context.mounted) {
        final restart = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('이전 퍼즐을 확인할 수 없어요'),
            content: const Text('진행 기록과 정원은 유지됩니다. 현재 퍼즐만 새로 시작할까요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('돌아가기'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('새로 시작'),
              ),
            ],
          ),
        );
        if (restart == true)
          await _update((s) => s.copyWith(clearActiveSession: true));
      }
    } catch (error) {
      _onSaveError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exitPuzzle() async {
    final session = _session;
    if (session == null || _busy) return;
    setState(() => _busy = true);
    try {
      await session.checkpoint();
      final save = await _repository.load();
      if (!mounted) return;
      setState(() {
        _save = save;
        _route = _needsOnboarding
            ? RenewalRoute.onboarding
            : _isDailyReview && !_usesPrototype
            ? RenewalRoute.memorySeeds
            : RenewalRoute.regionGarden;
        _session = null;
      });
      session.dispose();
    } catch (error) {
      _onSaveError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    final session = _session;
    if (session == null || _busy || !session.isAnswerCorrect) return;
    setState(() => _busy = true);
    // Retry a transient failed checkpoint with the current correct expression.
    final checkpoint = session.checkpoint();
    // Lifecycle checkpoints must not recreate a session after its completion.
    session.pauseSaving();
    try {
      await checkpoint;
      final receipt = await StageCompletionService(
        _repository,
        campaign: _campaign,
      ).complete(session.result(completedAt: _now));
      final save = await _repository.load();
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        if (receipt.unlockedRestorationNodeIds.isNotEmpty)
          _restorationNodeId = receipt.unlockedRestorationNodeIds.first;
        _save = save;
        _route = RenewalRoute.result;
        _session = null;
      });
      session.dispose();
    } catch (error) {
      session.resumeSaving();
      _onSaveError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Set<String> get _earnedNodeIds => {
    for (final receipt in _save!.rewardLedger.values)
      ...receipt.unlockedRestorationNodeIds,
  };
  String _regionForStage(StageDefinition stage) =>
      _campaign.regions
          .where(
            (region) =>
                region.chapters.any((chapter) => chapter.id == stage.chapterId),
          )
          .firstOrNull
          ?.id ??
      'region-01-calculation';

  StageDefinition? get _regionalNextStage {
    final candidates = _campaign.regions
        .where((region) => region.id == _regionId)
        .expand((region) => region.stages)
        .where(
          (stage) =>
              !_save!.completedStageIds.contains(stage.id) &&
              _canEnterStage(stage),
        );
    return candidates
            .where((stage) => stage.recurrencePlan?.isSpiral != true)
            .firstOrNull ??
        candidates.firstOrNull;
  }

  StageDefinition? _nextAfterResult(DailyRouteRecommendations daily) =>
      _stage.recurrencePlan?.isSpiral == true && _session?.isDailyReview != true
      ? _regionalNextStage ?? daily.explorationStage
      : daily.explorationStage;

  RestorationNode? get _restorationNode => gardenDefinitions
      .map((garden) => garden.nodeById(_nodeId ?? ''))
      .whereType<RestorationNode>()
      .firstOrNull;

  Set<String> get _earnedRegionNodeIds =>
      gardenDefinitionByRegionId(_regionId)?.restorationNodes
          .where((node) => _earnedNodeIds.contains(node.id))
          .map((node) => node.id)
          .toSet() ??
      const {};
  String? get _nodeId =>
      _restorationNodeId ??
      (_earnedNodeIds.isEmpty ? null : _earnedNodeIds.first);
  bool get _canRestore => _earnedNodeIds.isNotEmpty;
  String? get _nodeTitle {
    if (_nodeId == 'r01-demo-meadow') return null;
    return _restorationNode?.title;
  }

  Future<void> _chooseRestorationNode(BuildContext context) async {
    final earned = _usesPrototype ? _earnedNodeIds : _earnedRegionNodeIds;
    if (earned.isEmpty) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_usesPrototype ? '돌볼 정원을 고르세요' : '탐험 흔적 고르기'),
        content: SizedBox(
          width: 400,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (earned.contains(demoRestorationNode.id))
                ListTile(
                  leading: const Icon(Icons.local_florist_outlined),
                  title: Text(demoRestorationNode.title),
                  subtitle: const Text('체험 화단 · 무료로 장식 바꾸기'),
                  onTap: () => Navigator.pop(context, demoRestorationNode.id),
                ),
              for (final node
                  in gardenDefinitionByRegionId(_regionId)?.restorationNodes ??
                      <RestorationNode>[])
                if (earned.contains(node.id))
                  ListTile(
                    leading: Icon(
                      _save!.restoredNodeIds.contains(node.id)
                          ? Icons.local_florist_outlined
                          : Icons.grass_outlined,
                    ),
                    title: Text(expeditionMilestoneTitle(node)),
                    subtitle: Text(
                      _save!.restoredNodeIds.contains(node.id)
                          ? '무료로 표식 바꾸기'
                          : '새로운 탐험의 흔적',
                    ),
                    onTap: () => Navigator.pop(context, node.id),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
    if (mounted && selected != null) _showRestoration(selected);
  }

  Future<void> _viewCharacterStories(BuildContext context) async {
    final unlocked = _save!.unlockedCharacterIds;
    final story = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('탐험길의 친구들'),
        content: SizedBox(
          width: 400,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final entry in allCharacterStories)
                ListTile(
                  leading: Icon(
                    unlocked.contains(entry.characterId)
                        ? Icons.chat_bubble_outline
                        : Icons.lock_outline,
                  ),
                  title: Text(
                    '${entry.characterId.substring(5)} · ${entry.title}',
                  ),
                  subtitle: Text(
                    unlocked.contains(entry.characterId)
                        ? _save!.viewedStoryIds.contains(entry.id)
                              ? '다시 읽기'
                              : '새 이야기'
                        : '${(entry.requiredStageId?.substring(4) ?? '다음 탐험').toUpperCase().replaceAll('-', ' ')}에서 만나요',
                  ),
                  onTap: unlocked.contains(entry.characterId)
                      ? () => Navigator.pop(context, entry.id)
                      : null,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
    if (!mounted || story == null) return;
    final entry = allCharacterStories.singleWhere((entry) => entry.id == story);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.title),
        content: SingleChildScrollView(child: Text(entry.text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    try {
      await _update(
        (save) =>
            save.copyWith(viewedStoryIds: {...save.viewedStoryIds, story}),
      );
    } catch (error) {
      _onSaveError(error);
    }
  }

  void _showRestoration([String? preferred]) => setState(() {
    _restorationReturnRoute = _route == RenewalRoute.expeditionTraces
        ? RenewalRoute.expeditionTraces
        : _route == RenewalRoute.result && _isDailyReview && !_usesPrototype
        ? RenewalRoute.memorySeeds
        : RenewalRoute.regionGarden;
    _restorationNodeId =
        preferred ??
        _earnedNodeIds
            .where((id) => !_save!.restoredNodeIds.contains(id))
            .firstOrNull ??
        _earnedNodeIds.lastOrNull;
    final node = _restorationNode;
    if (node != null) _regionId = node.regionId;
    _route = RenewalRoute.restoration;
  });
  Future<void> _chooseDecoration(String choice) async {
    final nodeId = _nodeId;
    if (nodeId == null ||
        !_canRestore ||
        !const ['wildflowers', 'stone-path', 'herbs'].contains(choice))
      return;
    try {
      await _update(
        (s) =>
            !s.rewardLedger.values.any(
              (r) => r.unlockedRestorationNodeIds.contains(nodeId),
            )
            ? s
            : s.copyWith(
                restoredNodeIds: {...s.restoredNodeIds, nodeId},
                decorationChoices: {...s.decorationChoices, nodeId: choice},
              ),
      );
    } catch (error) {
      _onSaveError(error);
    }
  }

  Future<void> _finishRestoration() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final nodeId = _nodeId;
      if (nodeId == null) return;
      // Preserve any decoration selection queued before this transaction.
      await _update((s) {
        if (!s.rewardLedger.values.any(
          (r) => r.unlockedRestorationNodeIds.contains(nodeId),
        ))
          return s;
        return s.copyWith(
          restoredNodeIds: {...s.restoredNodeIds, nodeId},
          decorationChoices: {
            ...s.decorationChoices,
            nodeId: s.decorationChoices[nodeId] ?? 'wildflowers',
          },
          viewedStoryIds: {
            ...s.viewedStoryIds,
            nodeId == 'r01-demo-meadow' ? 'r01-demo-story' : '$nodeId-story',
          },
        );
      });
      if (!_save!.restoredNodeIds.contains(nodeId)) return;
      if (mounted) {
        if (_restorationReturnRoute == RenewalRoute.regionGarden) {
          _returnToExpedition();
        } else {
          setState(() => _route = _restorationReturnRoute);
        }
      }
    } catch (error) {
      _onSaveError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _offerAudioDownload(BuildContext context) async {
    // Preparation may finish after the frame that scheduled this prompt.
    await _audio.initialize();
    if (!mounted || !context.mounted || _audio.mediaAvailable) return;
    final accept = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('탐험 음악을 받을까요?'),
        content: const Text(
          '음악과 효과음 약 17MB를 최초 한 번만 받습니다. 모바일 데이터가 사용될 수 있습니다. 받지 않아도 모든 스테이지를 진행할 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('음악 없이 시작'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('음원 설정 열기'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    try {
      await _update(
        (save) =>
            save.copyWith(audio: save.audio.copyWith(downloadPromptSeen: true)),
      );
    } catch (error) {
      _onSaveError(error);
    }
    if (accept == true && mounted && context.mounted) await _settings(context);
  }

  Future<void> _settings(BuildContext context) async {
    var settings = _save!.accessibility;
    var audio = _save!.audio;
    var downloading = false;
    String? audioMessage;
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('음악·효과음 및 접근성'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AudioOptions(
                    settings: audio,
                    onChanged: (value) => updateDialog(() => audio = value),
                    mediaAvailable: _audio.mediaAvailable,
                    downloading: downloading,
                    message: audioMessage,
                    onDownload: !_audio.supportsDownload
                        ? null
                        : () async {
                            updateDialog(() {
                              downloading = true;
                              audioMessage = null;
                            });
                            try {
                              await _audio.downloadAssets();
                              audioMessage =
                                  '음원을 저장했습니다. 다음 앱 업데이트에서는 다시 받지 않습니다.';
                            } catch (_) {
                              audioMessage =
                                  '음원을 받지 못했습니다. 네트워크와 음원 배포 상태를 확인한 뒤 다시 시도해 주세요.';
                            } finally {
                              if (context.mounted)
                                updateDialog(() => downloading = false);
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('움직임 줄이기'),
                    value: settings.reducedMotion,
                    onChanged: (v) => updateDialog(
                      () => settings = settings.copyWith(reducedMotion: v),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('색상 구분 돕기'),
                    value: settings.colorAssist,
                    onChanged: (v) => updateDialog(
                      () => settings = settings.copyWith(colorAssist: v),
                    ),
                  ),
                  const Text('글자 크기'),
                  Slider(
                    value: settings.textScale.clamp(1, 1.3),
                    min: 1,
                    max: 1.3,
                    divisions: 3,
                    label: '${(settings.textScale * 100).round()}%',
                    onChanged: (v) => updateDialog(
                      () => settings = settings.copyWith(textScale: v),
                    ),
                  ),
                  const Text('출석이 끊겨도 정원은 사라지지 않아요. 알림·광고·결제는 없습니다.'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (apply != true) return;
    try {
      await _update((s) => s.copyWith(accessibility: settings, audio: audio));
    } catch (error) {
      _onSaveError(error);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'KV 수학탐험대 · 일곱 수식 정원',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    builder: (context, child) {
      final media = MediaQuery.of(context);
      final settings = _save?.accessibility;
      if (_save != null) {
        _audio.configure(
          _save!.audio,
          _startupReady && _assetBundle != null
              ? AudioScene.adventure
              : AudioScene.intro,
        );
        _audio.setForeground(_foreground);
      }
      return AudioScope(
        controller: _audio,
        child: Listener(
          onPointerDown: (_) => _audio.unlock(),
          behavior: HitTestBehavior.translucent,
          child: MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(
                media.textScaler.scale(1) * (settings?.textScale ?? 1),
              ),
              disableAnimations:
                  media.disableAnimations || (settings?.reducedMotion ?? false),
              highContrast:
                  media.highContrast || (settings?.colorAssist ?? false),
            ),
            child: LandscapeGameViewport(
              child: DefaultAssetBundle(
                bundle: _assetBundle ?? rootBundle,
                child: child!,
              ),
            ),
          ),
        ),
      );
    },
    home: StartupUpdateGate(
      service: widget.updateService ?? const AndroidAppUpdateService(),
      minimumIntroDuration: const Duration(milliseconds: 2400),
      preparationReady:
          (_save != null && _assetBundle != null) ||
          _loadError != null ||
          _assetError != null,
      introBuilder: (context, checking) => AdventureIntroScreen(
        status: checking
            ? 'GitHub의 새 버전을 확인하고 있어요'
            : _save == null
            ? '지난 탐험 기록을 불러오고 있어요'
            : _assetBundle == null
            ? '배경과 캐릭터를 확인하고 있어요'
            : '탐험을 출발할 준비가 되었어요',
      ),
      onReady: () {
        if (mounted) setState(() => _startupReady = true);
      },
      child: Builder(builder: _buildShell),
    ),
  );

  Widget _buildShell(BuildContext context) {
    if (_assetError != null) {
      if (_preparingAssets)
        return const AdventureIntroScreen(status: '탐험 에셋을 다운로드하고 검증하고 있어요');
      final downloadable = _assetError is MissingRetainedAssetsException;
      return _StartupIssueScreen(
        title: downloadable ? '배경·캐릭터 에셋이 필요합니다' : '정원 에셋을 확인할 수 없어요',
        detail: downloadable
            ? '최초 설치에서는 에셋을 한 번 받아야 합니다. 다운로드가 실패하면 네트워크·저장 공간·에셋 배포 상태를 확인하고 다시 시도해 주세요. 기존 진행 기록은 유지됩니다.'
            : '로직 전용 업데이트는 이전에 설치한 에셋 묶음이 필요합니다. '
                  '에셋 포함 전체 APK로 업데이트해 주세요. 진행 기록은 초기화하지 않았습니다.',
        retryLabel: downloadable ? '에셋 받기 · 약 15MB' : '다시 확인',
        onRetry: downloadable
            ? () => unawaited(_downloadImageAssets(context))
            : _prepareAssets,
      );
    }
    if (_loadError != null) {
      return _StartupIssueScreen(
        title: '저장된 정원을 열 수 없어요',
        detail: _loadError is FutureSaveVersionException
            ? '더 새로운 앱에서 만든 기록입니다. 기록을 보존했어요. 앱 버전을 확인해 주세요.'
            : '기록을 보존했어요. 저장소를 확인한 뒤 다시 열어 주세요.',
        retryLabel: '다시 열기',
        onRetry: _load,
      );
    }
    final save = _save;
    if (save == null || _assetBundle == null) {
      return AdventureIntroScreen(
        status: _assetBundle == null
            ? save == null
                  ? '정원 기록과 배경을 준비하고 있어요'
                  : '배경과 캐릭터를 확인하고 있어요'
            : '지난 탐험 기록을 불러오고 있어요',
      );
    }
    if (_startupReady &&
        _foreground &&
        !_audioDecisionAsked &&
        !save.audio.downloadPromptSeen &&
        _audio.supportsDownload &&
        !_audio.mediaAvailable) {
      _audioDecisionAsked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) unawaited(_offerAudioDownload(context));
      });
    }
    final daily = const DailyRouteService().build(save, _campaign, now: _now);
    final campaignStages = _campaign.stages
        .where(
          (stage) => stage.isPlayable && _regionForStage(stage) == _regionId,
        )
        .toList();
    final availableRegions = {
      for (final region in _campaign.regions)
        if (region.stages.any((stage) => stage.isPlayable)) region.id,
    };
    final unlockedRegions = {
      for (final region in legacyRegionCatalog)
        if (region.prerequisiteRegionId == null ||
            save.completedStageIds.contains(
              legacyRegionCatalog
                  .firstWhere((r) => r.id == region.prerequisiteRegionId)
                  .accessGateStageId,
            ))
          region.id,
    };
    final showRegionFoundation =
        !_needsOnboarding &&
        _route != RenewalRoute.worldMap &&
        _route != RenewalRoute.memorySeeds &&
        _route != RenewalRoute.expeditionTraces &&
        (_route != RenewalRoute.companions ||
            _companionReturnRoute == RenewalRoute.regionGarden);
    final pages = <Page<void>>[
      MaterialPage(
        key: ValueKey(
          _needsOnboarding ? RenewalRoute.onboarding : RenewalRoute.worldMap,
        ),
        // Retained navigator pages must not keep tooltip overlays alive after
        // their anchors become offstage, especially when a foldable resizes.
        child: TooltipVisibility(
          visible: _needsOnboarding
              ? _route == RenewalRoute.onboarding
              : _route == RenewalRoute.worldMap,
          child: _needsOnboarding
              ? ExpeditionOnboardingScreen(
                  save: save,
                  saving: _busy,
                  errorMessage: _statusMessage,
                  onChoosePlayer: (id) => unawaited(_choosePlayer(id)),
                  onStartTutorial: _startTutorial,
                  onSettings: () => unawaited(_settings(context)),
                  onDepart: () => unawaited(_depart()),
                )
              : WorldMapScreen(
                  availableRegionIds: _usesPrototype
                      ? const {'region-01-calculation'}
                      : availableRegions,
                  unlockedRegionIds: unlockedRegions,
                  restoredNodeIds: save.restoredNodeIds,
                  totalStars: save.bestStars.values.fold(0, (a, b) => a + b),
                  weeklyActions: _weeklyActions(save),
                  onExplore:
                      daily.explorationStage == null &&
                          save.activeSession == null
                      ? null
                      : () {
                          final activeId = save.activeSession?['stageId'];
                          final next =
                              _findStage(
                                activeId is String ? activeId : null,
                              ) ??
                              daily.explorationStage;
                          if (next == null) return;
                          _regionId = _regionForStage(next);
                          _showBriefing();
                        },
                  onReview: _usesPrototype
                      ? null
                      : () => setState(() => _route = RenewalRoute.memorySeeds),
                  reviewDetail: _usesPrototype
                      ? null
                      : daily.reviewCompletedToday
                      ? '오늘의 복습 완료'
                      : daily.reviewStage == null
                      ? '첫 탐험 뒤 내일부터 복습해요'
                      : daily.reviewKind == DailyReviewKind.dueReview
                      ? '돌아온 개념 · 기억 꺼내기'
                      : '하루 한 개 · 가볍게 다시 풀기',
                  explorationDetail: _usesPrototype
                      ? null
                      : save.activeSession != null
                      ? '저장된 탐험 이어가기'
                      : daily.explorationStage == null
                      ? daily.completedRegionIds.contains(
                              'region-01-calculation',
                            )
                            ? '탐험 완료 · 다음 지역 업데이트 예정'
                            : '새 묶음 준비 중 · 복습은 계속'
                      : '${daily.explorationStage!.chapterId.toUpperCase()} S${daily.explorationStage!.number.toString().padLeft(2, '0')}',
                  onRestore: _canRestore
                      ? () {
                          _showRestoration(daily.pendingRestorationNodeId);
                        }
                      : null,
                  onTraces: _usesPrototype
                      ? null
                      : () => setState(
                          () => _route = RenewalRoute.expeditionTraces,
                        ),
                  tracesDetail: _usesPrototype
                      ? null
                      : '발견한 이정표 · 챕터 도장 · 모험 배지',
                  onSelectRegion: _showRegion,
                  onSettings: () => unawaited(_settings(context)),
                  onCompanions: _usesPrototype ? null : _showCompanions,
                  statusMessage: _statusMessage,
                ),
        ),
      ),
      if (_route == RenewalRoute.memorySeeds)
        MaterialPage(
          key: const ValueKey(RenewalRoute.memorySeeds),
          child: MemorySeedsScreen(
            collection: const AdventureCollectionService().memorySeeds(
              save,
              _campaign,
              now: _now,
            ),
            initialSkillId: _isDailyReview
                ? _stage.learningPlan.primarySkillId
                : null,
            onBack: () => setState(() => _route = RenewalRoute.worldMap),
            onReview: save.activeSession?['isDailyReview'] == true
                ? _showBriefing
                : daily.reviewStage == null
                ? null
                : () => unawaited(
                    _openStage(
                      context,
                      daily.reviewStage!,
                      reviewTicketId:
                          daily.reviewKind == DailyReviewKind.dueReview
                          ? daily.reviewTicket?.id
                          : null,
                      isReview: true,
                    ),
                  ),
            onExplore:
                daily.explorationStage == null && save.activeSession == null
                ? null
                : () {
                    final activeId = save.activeSession?['stageId'];
                    final next =
                        _findStage(activeId is String ? activeId : null) ??
                        daily.explorationStage;
                    if (next == null) return;
                    _regionId = _regionForStage(next);
                    _showBriefing();
                  },
          ),
        ),
      if (_route == RenewalRoute.expeditionTraces)
        MaterialPage(
          key: const ValueKey(RenewalRoute.expeditionTraces),
          child: ExpeditionTracesScreen(
            journal: const AdventureCollectionService().journal(
              save,
              _campaign,
              gardenDefinitions,
              now: _now,
            ),
            onBack: () => setState(() => _route = RenewalRoute.worldMap),
            onRegion: _showRegion,
            onRestore: _showRestoration,
            onCompanions: _showCompanions,
          ),
        ),
      if (showRegionFoundation)
        MaterialPage(
          key: const ValueKey(RenewalRoute.regionGarden),
          child: TooltipVisibility(
            visible: _route == RenewalRoute.regionGarden,
            child: !_usesPrototype && availableRegions.contains(_regionId)
                ? CampaignRegionGardenScreen(
                    regionNumber: expeditionRegionNumber(_regionId),
                    stages: campaignStages,
                    completedStageIds: save.completedStageIds,
                    unlockedStageIds: save.unlockedStageIds,
                    restoredNodeIds: save.restoredNodeIds,
                    decorationChoices: save.decorationChoices,
                    nextStageId: _regionalNextStage?.id,
                    unlockedCharacterIds: save.unlockedCharacterIds,
                    playerCharacterId: save.playerCharacterId,
                    onCompanions: _showCompanions,
                    canEnterStage: _canEnterStage,
                    onStories: () => unawaited(_viewCharacterStories(context)),
                    onBack: () =>
                        setState(() => _route = RenewalRoute.worldMap),
                    onPlay:
                        _regionalNextStage == null && save.activeSession == null
                        ? null
                        : _showBriefing,
                    onSelectStage: (id) => unawaited(
                      _openStage(context, _campaign.stageById(id)!),
                    ),
                    onRestore: () => unawaited(_chooseRestorationNode(context)),
                    canRestore: _earnedRegionNodeIds.isNotEmpty,
                    hasActiveSession: save.activeSession != null,
                  )
                : RegionGardenScreen(
                    regionId: _regionId,
                    restoredNodeIds: save.restoredNodeIds,
                    decorationChoices: save.decorationChoices,
                    onBack: () =>
                        setState(() => _route = RenewalRoute.worldMap),
                    onPlay: _showBriefing,
                    onRestore: () =>
                        _showRestoration(daily.pendingRestorationNodeId),
                    canRestore: _canRestore,
                    hasActiveSession: save.activeSession != null,
                    demoCompleted: save.completedStageIds.contains(
                      verticalSliceStage.id,
                    ),
                  ),
          ),
        ),
      if (_route == RenewalRoute.briefing)
        MaterialPage(
          key: const ValueKey(RenewalRoute.briefing),
          child: StageBriefingScreen(
            playerCharacterId: save.playerCharacterId,
            randomChallenge:
                save.activeSession == null ||
                save.activeSession!['rulesVersion'] == 5,
            stage: _usesPrototype || _stage.id == verticalSliceStage.id
                ? null
                : save.activeSession != null &&
                      save.activeSession!['rulesVersion'] != 5
                ? _stage
                : DiscoveryChallengeProfile.stageFor(_stage),
            isReview: _isDailyReview || _stage.chapterId.endsWith('-c04'),
            onBack: _returnFromStage,
            onStart: () => unawaited(_start(context)),
            resume: save.activeSession != null,
          ),
        ),
      if (_route == RenewalRoute.puzzle && _session != null)
        MaterialPage(
          key: ValueKey(_session!.attemptId),
          child: DiscoveryPuzzleScreen(
            viewModel: _session,
            onExit: () => unawaited(_exitPuzzle()),
          ),
        ),
      if (_route == RenewalRoute.result && _receipt != null)
        MaterialPage(
          key: const ValueKey(RenewalRoute.result),
          child: StageResultScreen(
            stage: _usesPrototype || _stage.id == verticalSliceStage.id
                ? null
                : _stage,
            puzzle: _usesPrototype || _stage.id == verticalSliceStage.id
                ? null
                : discoveryRuntimeCatalog.resolve(_stage).puzzle,
            hasRestoration: _receipt!.unlockedRestorationNodeIds.isNotEmpty,
            continueLabel: _usesPrototype
                ? null
                : _needsOnboarding
                ? '모험 출발하기'
                : _receipt!.unlockedRestorationNodeIds.isNotEmpty
                ? '탐험의 흔적 남기기'
                : _isDailyReview
                ? '기억의 씨앗 확인하기'
                : _nextAfterResult(daily) == null
                ? '탐험 지도로 돌아가기'
                : '다음 탐험 안내',
            stars: _receipt!.stars,
            firstCompletion: _receipt!.firstCompletion,
            onContinue: () {
              if (_needsOnboarding) {
                unawaited(_depart());
              } else if (_receipt!.unlockedRestorationNodeIds.isNotEmpty)
                _showRestoration(_receipt!.unlockedRestorationNodeIds.first);
              else if (_isDailyReview && !_usesPrototype)
                _returnFromStage();
              else if (!_usesPrototype &&
                  nextUnviewedCompanionArrival(save, regionId: _regionId) !=
                      null)
                _returnToExpedition();
              else if (!_usesPrototype && _nextAfterResult(daily) != null)
                unawaited(_openStage(context, _nextAfterResult(daily)!));
              else
                _returnToExpedition();
            },
            onBack: _returnFromStage,
          ),
        ),
      if (_route == RenewalRoute.restoration)
        MaterialPage(
          key: const ValueKey(RenewalRoute.restoration),
          child: RestorationRevealScreen(
            nodeTitle: _nodeTitle,
            node: _restorationNode,
            unlockedCharacterIds: save.unlockedCharacterIds,
            restoredNodeIds: _usesPrototype ? const {} : save.restoredNodeIds,
            completedStageCount: _usesPrototype
                ? 0
                : save.completedStageIds
                      .where(
                        (id) =>
                            _findStage(id) != null &&
                            _regionForStage(_findStage(id)!) == _regionId,
                      )
                      .length,
            alreadyRestored: save.restoredNodeIds.contains(_nodeId),
            decorationId: save.decorationChoices[_nodeId] ?? 'wildflowers',
            onChooseDecoration: (choice) =>
                unawaited(_chooseDecoration(choice)),
            onFinish: () => unawaited(_finishRestoration()),
          ),
        ),
      if (_route == RenewalRoute.companions)
        MaterialPage(
          key: const ValueKey(RenewalRoute.companions),
          child: CompanionCollectionScreen(
            save: save,
            onBack: () => setState(() => _route = _companionReturnRoute),
            onReplayArrival: _replayArrival,
            onSelectPlayer: (id) => unawaited(_changePlayer(id)),
            saving: _busy,
          ),
        ),
      if (_route == RenewalRoute.companionArrival && _arrival != null)
        MaterialPage(
          key: ValueKey(_arrival!.arrivalStoryId),
          child: CompanionArrivalScreen(
            recruitment: _arrival!,
            replay: _arrivalReplay,
            saving: _busy,
            errorMessage: _statusMessage,
            onContinue: () => unawaited(_finishArrival()),
          ),
        ),
    ];
    return Stack(
      children: [
        // MaterialApp owns an outer home route; system back must reach this
        // typed inner navigation rather than popping/exiting that home route.
        PopScope<void>(
          canPop:
              _route == RenewalRoute.worldMap ||
              _route == RenewalRoute.onboarding,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _navigateBack();
          },
          child: Navigator(
            pages: pages,
            onDidRemovePage: (page) {
              if (pages.contains(page)) _navigateBack();
            },
          ),
        ),
        if (_statusMessage != null &&
            _route != RenewalRoute.worldMap &&
            !_needsOnboarding &&
            _route != RenewalRoute.companionArrival)
          Positioned(
            left: 12,
            right: 12,
            top: 6,
            child: SafeArea(
              child: Material(
                color: const Color(0xFFFFF4D9),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        tooltip: '안내 닫기',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _statusMessage = null),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_busy)
          const Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: Color(0x44000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    );
  }

  int _weeklyActions(SaveEnvelopeV1 save) {
    final now = _now;
    return List.generate(
      7,
      (i) =>
          save.dailyActions[localDateKey(
            DateTime(now.year, now.month, now.day - i),
          )] ??
          0,
    ).fold(0, (a, b) => a + b);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restTimer?.cancel();
    _session?.dispose();
    if (widget.audioController == null) unawaited(_audio.dispose());
    super.dispose();
  }
}
