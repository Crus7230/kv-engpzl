import 'dart:math';

import '../../progress/progress.dart';
import 'discovery_puzzle_view_model.dart';
import 'engine_discovery_puzzle_view_model.dart';

/// Owns one attempt and persists deterministic checkpoints after interactions.
class StageSessionController extends EngineDiscoveryPuzzleViewModel
    implements DiscoveryCompletionHandler {
  StageSessionController({
    required this.repository,
    required super.stage,
    required super.boardConfig,
    required this.onContinue,
    required this.onSaveError,
    Map<String, dynamic>? savedSession,
    super.runtimeCatalog,
    String? reviewTicketId,
    bool isDailyReview = false,
  }) {
    final savedTicket = savedSession?['reviewTicketId'];
    final savedReview = savedSession?['isDailyReview'];
    if (savedTicket != null && savedTicket is! String ||
        savedReview != null && savedReview is! bool)
      throw const FormatException('Invalid review session.');
    this.reviewTicketId = savedSession == null
        ? reviewTicketId
        : savedTicket as String?;
    this.isDailyReview = savedSession == null
        ? isDailyReview
        : savedReview == true;
    if (this.reviewTicketId != null && this.reviewTicketId!.trim().isEmpty)
      throw const FormatException('Empty review ticket ID.');
    final savedId = savedSession?['attemptId'];
    if (savedSession != null && savedId is! String) {
      throw const FormatException('Missing attempt ID.');
    }
    attemptId = savedId as String? ?? _newAttemptId();
    if (attemptId.trim().isEmpty)
      throw const FormatException('Missing attempt ID.');
    if (savedSession != null) restoreSession(savedSession);
    addListener(_checkpoint);
  }

  final ProgressRepository repository;
  final void Function() onContinue;
  final void Function(Object error) onSaveError;
  late String attemptId;
  late String? reviewTicketId;
  late bool isDailyReview;
  Future<void> _pending = Future<void>.value();
  Object? _lastError;
  bool _savingEnabled = true;

  static String _newAttemptId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x100000000)}';

  void _checkpoint() {
    if (!_savingEnabled) return;
    final checkpoint = {
      ...exportSession(),
      'attemptId': attemptId,
      'reviewTicketId': reviewTicketId,
      'isDailyReview': isDailyReview,
    };
    _pending = repository
        .update(
          (save) => save.rewardLedger.containsKey(checkpoint['attemptId'])
              ? save
              : save.copyWith(activeSession: checkpoint),
        )
        .then<void>((_) {
          _lastError = null;
        })
        .catchError((Object error) {
          _lastError = error;
          onSaveError(error);
        });
  }

  Future<void> checkpoint() async {
    _checkpoint();
    await flush();
  }

  Future<void> flush() async {
    await _pending;
    if (_lastError != null) throw _lastError!;
  }

  void pauseSaving() {
    _savingEnabled = false;
  }

  void resumeSaving() {
    _savingEnabled = true;
  }

  @override
  void resetRound() {
    attemptId = _newAttemptId();
    super.resetRound();
  }

  StageAttemptResult result({DateTime? completedAt}) => StageAttemptResult(
    attemptId: attemptId,
    stage: stage,
    metrics: attemptMetrics,
    completedAt: completedAt ?? DateTime.now(),
    misconceptionIds: misconceptionIds,
    reviewTicketId: reviewTicketId,
    isDailyReview: isDailyReview,
  );

  @override
  void continueToResult() {
    if (isAnswerCorrect) onContinue();
  }

  @override
  void dispose() {
    _savingEnabled = false;
    removeListener(_checkpoint);
    super.dispose();
  }
}
