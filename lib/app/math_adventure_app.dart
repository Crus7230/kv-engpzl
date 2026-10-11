import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/branding/garden_branding.dart';
import '../core/theme/app_theme.dart';
import '../core/assets/retained_asset_bundle.dart';
import '../core/updates/app_update_service.dart';
import '../core/updates/startup_update_gate.dart';
import '../features/campaign/data/initial_campaign.dart';
import '../features/campaign/domain/campaign_models.dart';
import '../features/campaign/data/legacy_region_catalog.dart';
import '../features/discovery/domain/discovery_models.dart';
import '../features/discovery/data/discovery_runtime_catalog.dart';
import '../features/garden/data/garden_catalog.dart';
import '../features/discovery/presentation/discovery_puzzle_screen.dart';
import '../features/discovery/presentation/stage_session_controller.dart';
import '../features/garden/presentation/garden_screens.dart';
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
    super.key,
  });
  final ProgressRepository? repository;
  final CampaignDefinition? campaign;
  final AssetBundle? assetBundle;
  final DateTime Function()? now;
  final AppUpdateService? updateService;
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
}

class _MathAdventureAppState extends State<MathAdventureApp>
    with WidgetsBindingObserver {
  late final ProgressRepository _repository;
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
  CampaignDefinition get _campaign => widget.campaign ?? initialCampaign;
  bool get _usesPrototype => identical(_campaign, prototypeCampaign);
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
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  Future<void> _load() async {
    if (_loadingProgress) return;
    _loadingProgress = true;
    if (mounted && _loadError != null) {
      setState(() => _loadError = null);
    }
    try {
      final save = await _repository.load();
      if (mounted)
        setState(() {
          _save = save;
          _loadError = null;
        });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    } finally {
      _loadingProgress = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
      setState(() => _statusMessage = '저장을 완료하지 못했어요. 저장소를 확인하고 다시 시도해 주세요.');
  }

  Future<void> _update(SaveEnvelopeV1 Function(SaveEnvelopeV1) change) async {
    final save = await _repository.update(change);
    if (mounted) setState(() => _save = save);
  }

  void _showRegion(String id) => setState(() {
    _regionId = id;
    _route = RenewalRoute.regionGarden;
  });
  void _showBriefing() {
    if (_regionId != 'region-01-calculation') return;
    final active = _save!.activeSession;
    final daily = const DailyRouteService().build(_save!, _campaign, now: _now);
    final rawStageId = active?['stageId'];
    final stage =
        _findStage(rawStageId is String ? rawStageId : null) ??
        daily.explorationStage;
    if (stage == null) return;
    setState(() {
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
      _regionId = 'region-01-calculation';
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
          ? media.size.width - media.padding.horizontal < 720 ||
                    media.size.height - media.padding.vertical < 400
                ? DiscoveryBoardConfig.compactPhone
                : DiscoveryBoardConfig.standardPhone
          : rows is int &&
                columns is int &&
                ((rows == 5 && columns == 5) || (rows == 6 && columns == 6))
          ? DiscoveryBoardConfig(rows: rows, columns: columns)
          : throw const FormatException('Invalid saved board dimensions.');
      final session = StageSessionController(
        repository: _repository,
        stage: stage,
        reviewTicketId: _reviewTicketId,
        isDailyReview: _isDailyReview,
        boardConfig: config,
        savedSession: saved,
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
        _route = RenewalRoute.regionGarden;
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
  String? get _nodeId =>
      _restorationNodeId ??
      (_earnedNodeIds.isEmpty ? null : _earnedNodeIds.first);
  bool get _canRestore => _earnedNodeIds.isNotEmpty;
  String? get _nodeTitle {
    if (_nodeId == 'r01-demo-meadow') return null;
    return gardenDefinitionByRegionId(
      'region-01-calculation',
    )?.nodeById(_nodeId ?? '')?.title;
  }

  Future<void> _chooseRestorationNode(BuildContext context) async {
    final earned = _earnedNodeIds;
    if (earned.isEmpty) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('돌볼 정원을 고르세요'),
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
              for (final node in gardenDefinitions.first.restorationNodes)
                if (earned.contains(node.id))
                  ListTile(
                    leading: Icon(
                      _save!.restoredNodeIds.contains(node.id)
                          ? Icons.local_florist_outlined
                          : Icons.grass_outlined,
                    ),
                    title: Text(node.title),
                    subtitle: Text(
                      _save!.restoredNodeIds.contains(node.id)
                          ? '무료로 장식 바꾸기'
                          : '복원할 준비가 되었어요',
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
        title: const Text('평원의 친구들'),
        content: SizedBox(
          width: 400,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final entry in r1CharacterStories)
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
                        : entry.requiredStageId == 'r01-c02-s10'
                        ? 'C02 S10에서 만나요'
                        : 'C03 S10에서 만나요',
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
    final entry = r1CharacterStories.singleWhere((entry) => entry.id == story);
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
    _restorationNodeId =
        preferred ??
        _earnedNodeIds
            .where((id) => !_save!.restoredNodeIds.contains(id))
            .firstOrNull ??
        _earnedNodeIds.lastOrNull;
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
      if (mounted) setState(() => _route = RenewalRoute.regionGarden);
    } catch (error) {
      _onSaveError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _settings(BuildContext context) async {
    var settings = _save!.accessibility;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('편안하게 즐기기'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    try {
      await _update((s) => s.copyWith(accessibility: settings));
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
      return MediaQuery(
        data: media.copyWith(
          textScaler: TextScaler.linear(
            media.textScaler.scale(1) * (settings?.textScale ?? 1),
          ),
          disableAnimations:
              media.disableAnimations || (settings?.reducedMotion ?? false),
          highContrast: media.highContrast || (settings?.colorAssist ?? false),
        ),
        child: DefaultAssetBundle(
          bundle: _assetBundle ?? rootBundle,
          child: child!,
        ),
      );
    },
    home: StartupUpdateGate(
      service: widget.updateService ?? const AndroidAppUpdateService(),
      child: Builder(builder: _buildShell),
    ),
  );

  Widget _buildShell(BuildContext context) {
    if (_assetError != null) {
      return _StartupIssueScreen(
        title: '정원 에셋을 확인할 수 없어요',
        detail:
            '로직 전용 업데이트는 이전에 설치한 에셋 묶음이 필요합니다. '
            '에셋 포함 전체 APK로 업데이트해 주세요. 진행 기록은 초기화하지 않았습니다.',
        retryLabel: '다시 확인',
        onRetry: _prepareAssets,
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
      return GardenLoadingScreen(
        status: _assetBundle == null
            ? save == null
                  ? '정원 기록과 배경을 준비하고 있어요'
                  : '배경과 캐릭터를 확인하고 있어요'
            : '지난 탐험 기록을 불러오고 있어요',
        reduceMotion: MediaQuery.disableAnimationsOf(context),
      );
    }
    final daily = const DailyRouteService().build(save, _campaign, now: _now);
    final campaignStages = _campaign.stages
        .where((stage) => stage.isPlayable && stage.id.startsWith('r01-'))
        .toList();
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
    final pages = <Page<void>>[
      MaterialPage(
        key: const ValueKey(RenewalRoute.worldMap),
        child: WorldMapScreen(
          unlockedRegionIds: unlockedRegions,
          restoredNodeIds: save.restoredNodeIds,
          totalStars: save.bestStars.values.fold(0, (a, b) => a + b),
          weeklyActions: _weeklyActions(save),
          onExplore:
              daily.explorationStage == null && save.activeSession == null
              ? null
              : () {
                  _regionId = 'region-01-calculation';
                  _showBriefing();
                },
          onReview: daily.reviewStage == null
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
              ? daily.completedRegionIds.contains('region-01-calculation')
                    ? '평원 완료 · 다음 지역 업데이트 예정'
                    : '새 묶음 준비 중 · 복습은 계속'
              : '${daily.explorationStage!.chapterId.toUpperCase()} S${daily.explorationStage!.number.toString().padLeft(2, '0')}',
          onRestore: _canRestore
              ? () {
                  _regionId = 'region-01-calculation';
                  _showRestoration(daily.pendingRestorationNodeId);
                }
              : null,
          onSelectRegion: _showRegion,
          onSettings: () => unawaited(_settings(context)),
          statusMessage: _statusMessage,
        ),
      ),
      if (_route != RenewalRoute.worldMap)
        MaterialPage(
          key: const ValueKey(RenewalRoute.regionGarden),
          child: !_usesPrototype && _regionId == 'region-01-calculation'
              ? CampaignRegionGardenScreen(
                  stages: campaignStages,
                  completedStageIds: save.completedStageIds,
                  unlockedStageIds: save.unlockedStageIds,
                  restoredNodeIds: save.restoredNodeIds,
                  decorationChoices: save.decorationChoices,
                  nextStageId: daily.explorationStage?.id,
                  unlockedCharacterIds: save.unlockedCharacterIds,
                  canEnterStage: _canEnterStage,
                  onStories: () => unawaited(_viewCharacterStories(context)),
                  onBack: () => setState(() => _route = RenewalRoute.worldMap),
                  onPlay:
                      daily.explorationStage == null &&
                          save.activeSession == null
                      ? null
                      : _showBriefing,
                  onSelectStage: (id) =>
                      unawaited(_openStage(context, _campaign.stageById(id)!)),
                  onRestore: () => unawaited(_chooseRestorationNode(context)),
                  canRestore: _canRestore,
                  hasActiveSession: save.activeSession != null,
                )
              : RegionGardenScreen(
                  regionId: _regionId,
                  restoredNodeIds: save.restoredNodeIds,
                  decorationChoices: save.decorationChoices,
                  onBack: () => setState(() => _route = RenewalRoute.worldMap),
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
      if (_route == RenewalRoute.briefing)
        MaterialPage(
          key: const ValueKey(RenewalRoute.briefing),
          child: StageBriefingScreen(
            stage: _usesPrototype || _stage.id == verticalSliceStage.id
                ? null
                : _stage,
            isReview: _isDailyReview || _stage.chapterId == 'r01-c04',
            onBack: () => setState(() => _route = RenewalRoute.regionGarden),
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
                : _receipt!.unlockedRestorationNodeIds.isNotEmpty
                ? '열린 정원 복원하기'
                : daily.explorationStage == null
                ? '정원으로 돌아가기'
                : '다음 탐험 안내',
            stars: _receipt!.stars,
            firstCompletion: _receipt!.firstCompletion,
            onContinue: () {
              if (_receipt!.unlockedRestorationNodeIds.isNotEmpty)
                _showRestoration(_receipt!.unlockedRestorationNodeIds.first);
              else if (!_usesPrototype && daily.explorationStage != null)
                unawaited(_openStage(context, daily.explorationStage!));
              else
                setState(() => _route = RenewalRoute.regionGarden);
            },
            onBack: () => setState(() => _route = RenewalRoute.regionGarden),
          ),
        ),
      if (_route == RenewalRoute.restoration)
        MaterialPage(
          key: const ValueKey(RenewalRoute.restoration),
          child: RestorationRevealScreen(
            nodeTitle: _nodeTitle,
            node: gardenDefinitions.first.nodeById(_nodeId ?? ''),
            unlockedCharacterIds: save.unlockedCharacterIds,
            restoredNodeIds: _usesPrototype ? const {} : save.restoredNodeIds,
            completedStageCount: _usesPrototype
                ? 0
                : save.completedStageIds
                      .where((id) => id.startsWith('r01-'))
                      .length,
            alreadyRestored: save.restoredNodeIds.contains(_nodeId),
            decorationId: save.decorationChoices[_nodeId] ?? 'wildflowers',
            onChooseDecoration: (choice) =>
                unawaited(_chooseDecoration(choice)),
            onFinish: () => unawaited(_finishRestoration()),
          ),
        ),
    ];
    return Stack(
      children: [
        Navigator(
          pages: pages,
          onDidRemovePage: (page) {
            if (!pages.contains(page)) return;
            if (_route == RenewalRoute.puzzle) {
              unawaited(_exitPuzzle());
            } else if (_route != RenewalRoute.worldMap)
              setState(
                () => _route =
                    page.key == const ValueKey(RenewalRoute.regionGarden)
                    ? RenewalRoute.worldMap
                    : RenewalRoute.regionGarden,
              );
          },
        ),
        if (_statusMessage != null && _route != RenewalRoute.worldMap)
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
    super.dispose();
  }
}
