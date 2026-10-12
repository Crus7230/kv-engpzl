import 'dart:convert';

import '../../../core/audio/audio_settings.dart';

import '../../campaign/domain/campaign_models.dart';
import '../../campaign/domain/learning_models.dart';
import '../../campaign/domain/stage_recurrence_models.dart';

class FutureSaveVersionException implements Exception {
  const FutureSaveVersionException(
    this.version, {
    this.field = 'schemaVersion',
  });
  final int version;
  final String field;
  @override
  String toString() => 'Unsupported future save $field: $version';
}

class AccessibilitySettings {
  AccessibilitySettings({
    this.reducedMotion = false,
    this.colorAssist = false,
    this.textScale = 1,
  }) {
    if (!textScale.isFinite || textScale < 0.8 || textScale > 2) {
      throw ArgumentError.value(textScale, 'textScale');
    }
  }
  final bool reducedMotion;
  final bool colorAssist;
  final double textScale;
  AccessibilitySettings copyWith({
    bool? reducedMotion,
    bool? colorAssist,
    double? textScale,
  }) => AccessibilitySettings(
    reducedMotion: reducedMotion ?? this.reducedMotion,
    colorAssist: colorAssist ?? this.colorAssist,
    textScale: textScale ?? this.textScale,
  );
  Map<String, Object?> toJson() => {
    'reducedMotion': reducedMotion,
    'colorAssist': colorAssist,
    'textScale': textScale,
  };
  factory AccessibilitySettings.fromJson(Map<String, dynamic> json) =>
      AccessibilitySettings(
        reducedMotion: _boolean(json, 'reducedMotion'),
        colorAssist: _boolean(json, 'colorAssist'),
        textScale: _number(json, 'textScale').toDouble(),
      );
}

class StageAttemptResult {
  StageAttemptResult({
    required this.attemptId,
    required this.stage,
    required this.metrics,
    required this.completedAt,
    this.reviewTicketId,
    this.isDailyReview = false,
    Iterable<String> misconceptionIds = const [],
  }) : misconceptionIds = Set.unmodifiable(misconceptionIds) {
    _nonEmpty(attemptId, 'attemptId');
    if (reviewTicketId != null) _nonEmpty(reviewTicketId!, 'reviewTicketId');
    if (metrics.movesUsed < 0 ||
        metrics.meaningfulSubmissionCount < 0 ||
        metrics.highestMathHintTierUsed < 0) {
      throw ArgumentError('Attempt metrics must not be negative.');
    }
  }
  final String attemptId;
  final StageDefinition stage;
  final StageAttemptMetrics metrics;
  final DateTime completedAt;
  final String? reviewTicketId;

  /// Calendar practice is not a stage-count review ticket or delayed mastery.
  final bool isDailyReview;
  final Set<String> misconceptionIds;
}

class CompletionReceipt {
  CompletionReceipt({
    required this.attemptId,
    required this.stageId,
    required this.stars,
    required this.firstCompletion,
    required this.supportReviewNeeded,
    Iterable<String> unlockedRestorationNodeIds = const [],
    Iterable<String> unlockedCharacterIds = const [],
    this.nextStageId,
  }) : unlockedRestorationNodeIds = List.unmodifiable(
         unlockedRestorationNodeIds,
       ),
       unlockedCharacterIds = List.unmodifiable(unlockedCharacterIds) {
    _nonEmpty(attemptId, 'attemptId');
    _nonEmpty(stageId, 'stageId');
    if (stars < 1 || stars > 3) throw ArgumentError.value(stars, 'stars');
    for (final id in this.unlockedRestorationNodeIds) {
      _nonEmpty(id, 'restorationNodeId');
    }
    for (final id in this.unlockedCharacterIds) {
      _nonEmpty(id, 'characterId');
    }
    if (nextStageId != null) _nonEmpty(nextStageId!, 'nextStageId');
  }
  final String attemptId;
  final String stageId;
  final int stars;
  final bool firstCompletion;
  final bool supportReviewNeeded;
  final List<String> unlockedRestorationNodeIds;
  final List<String> unlockedCharacterIds;
  final String? nextStageId;
  Map<String, Object?> toJson() => {
    'attemptId': attemptId,
    'stageId': stageId,
    'stars': stars,
    'firstCompletion': firstCompletion,
    'supportReviewNeeded': supportReviewNeeded,
    'unlockedRestorationNodeIds': unlockedRestorationNodeIds,
    'unlockedCharacterIds': unlockedCharacterIds,
    'nextStageId': nextStageId,
  };
  factory CompletionReceipt.fromJson(Map<String, dynamic> json) =>
      CompletionReceipt(
        attemptId: _string(json, 'attemptId'),
        stageId: _string(json, 'stageId'),
        stars: _integer(json, 'stars'),
        firstCompletion: _boolean(json, 'firstCompletion'),
        supportReviewNeeded: _boolean(json, 'supportReviewNeeded'),
        unlockedRestorationNodeIds: _strings(
          json['unlockedRestorationNodeIds'],
          'unlockedRestorationNodeIds',
        ),
        nextStageId: _optionalString(json, 'nextStageId'),
        unlockedCharacterIds: _strings(
          json['unlockedCharacterIds'] ?? const <String>[],
          'unlockedCharacterIds',
        ),
      );
}

/// Complete immutable snapshot. Unknown catalog IDs are intentionally retained.
class SaveEnvelopeV1 {
  SaveEnvelopeV1({
    this.generation = 0,
    this.contentVersion = 1,
    Iterable<String> completedStageIds = const [],
    Iterable<String> unlockedStageIds = const [],
    Iterable<String> restoredNodeIds = const [],
    Iterable<String> unlockedCharacterIds = const [],
    Iterable<String> viewedStoryIds = const [],
    this.playerCharacterId,
    this.starterCharacterId,
    this.onboardingCompleted = false,
    Map<String, int> bestStars = const {},
    Map<String, int> dailyActions = const {},
    Map<String, int> dailyReviewActions = const {},
    Map<String, String> stageLastPlayedDates = const {},
    Map<String, String> decorationChoices = const {},
    Map<String, SkillProgressSnapshot> skillProgress = const {},
    Map<String, SkillMasteryState> masteryStates = const {},
    Map<String, dynamic>? activeSession,
    Map<String, CompletionReceipt> rewardLedger = const {},
    AccessibilitySettings? accessibility,
    AudioSettings? audio,
  }) : completedStageIds = Set.unmodifiable(completedStageIds),
       unlockedStageIds = Set.unmodifiable(unlockedStageIds),
       restoredNodeIds = Set.unmodifiable(restoredNodeIds),
       unlockedCharacterIds = Set.unmodifiable(unlockedCharacterIds),
       viewedStoryIds = Set.unmodifiable(viewedStoryIds),
       bestStars = Map.unmodifiable(bestStars),
       dailyActions = Map.unmodifiable(dailyActions),
       dailyReviewActions = Map.unmodifiable(dailyReviewActions),
       stageLastPlayedDates = Map.unmodifiable(stageLastPlayedDates),
       decorationChoices = Map.unmodifiable(decorationChoices),
       skillProgress = Map.unmodifiable(skillProgress),
       masteryStates = Map.unmodifiable(masteryStates),
       activeSession = activeSession == null ? null : _freezeMap(activeSession),
       rewardLedger = Map.unmodifiable(rewardLedger),
       audio = audio ?? AudioSettings(),
       accessibility = accessibility ?? AccessibilitySettings() {
    validate();
  }
  static const currentSchemaVersion = 1;
  int get schemaVersion => currentSchemaVersion;
  static const supportedContentVersion = 1;
  final int generation;
  final int contentVersion;
  final Set<String> completedStageIds;
  final Set<String> unlockedStageIds;
  final Set<String> restoredNodeIds;
  final Set<String> unlockedCharacterIds;
  final Set<String> viewedStoryIds;

  /// Chosen player avatar is separate from companions rescued on expeditions.
  final String? playerCharacterId;

  /// Original onboarding avatar is immutable even when the active avatar changes.
  final String? starterCharacterId;
  final bool onboardingCompleted;
  final Map<String, int> bestStars;
  final Map<String, int> dailyActions;
  final Map<String, int> dailyReviewActions;
  final Map<String, String> stageLastPlayedDates;
  final Map<String, String> decorationChoices;
  final Map<String, SkillProgressSnapshot> skillProgress;
  final Map<String, SkillMasteryState> masteryStates;
  final Map<String, dynamic>? activeSession;
  final Map<String, CompletionReceipt> rewardLedger;
  final AccessibilitySettings accessibility;
  final AudioSettings audio;
  factory SaveEnvelopeV1.initial() => SaveEnvelopeV1(
    unlockedStageIds: const ['prototype-bundle-add', 'r01-c01-s01'],
  );
  SaveEnvelopeV1 copyWith({
    int? generation,
    int? contentVersion,
    Iterable<String>? completedStageIds,
    Iterable<String>? unlockedStageIds,
    Iterable<String>? restoredNodeIds,
    Iterable<String>? unlockedCharacterIds,
    Iterable<String>? viewedStoryIds,
    String? playerCharacterId,
    String? starterCharacterId,
    bool? onboardingCompleted,
    Map<String, int>? bestStars,
    Map<String, int>? dailyActions,
    Map<String, int>? dailyReviewActions,
    Map<String, String>? stageLastPlayedDates,
    Map<String, String>? decorationChoices,
    Map<String, SkillProgressSnapshot>? skillProgress,
    Map<String, SkillMasteryState>? masteryStates,
    Map<String, dynamic>? activeSession,
    bool clearActiveSession = false,
    Map<String, CompletionReceipt>? rewardLedger,
    AccessibilitySettings? accessibility,
    AudioSettings? audio,
  }) => SaveEnvelopeV1(
    generation: generation ?? this.generation,
    contentVersion: contentVersion ?? this.contentVersion,
    completedStageIds: completedStageIds ?? this.completedStageIds,
    unlockedStageIds: unlockedStageIds ?? this.unlockedStageIds,
    restoredNodeIds: restoredNodeIds ?? this.restoredNodeIds,
    unlockedCharacterIds: unlockedCharacterIds ?? this.unlockedCharacterIds,
    viewedStoryIds: viewedStoryIds ?? this.viewedStoryIds,
    playerCharacterId: playerCharacterId ?? this.playerCharacterId,
    starterCharacterId: starterCharacterId ?? this.starterCharacterId,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    bestStars: bestStars ?? this.bestStars,
    dailyActions: dailyActions ?? this.dailyActions,
    dailyReviewActions: dailyReviewActions ?? this.dailyReviewActions,
    stageLastPlayedDates: stageLastPlayedDates ?? this.stageLastPlayedDates,
    decorationChoices: decorationChoices ?? this.decorationChoices,
    skillProgress: skillProgress ?? this.skillProgress,
    masteryStates: masteryStates ?? this.masteryStates,
    activeSession: clearActiveSession
        ? null
        : activeSession ?? this.activeSession,
    rewardLedger: rewardLedger ?? this.rewardLedger,
    accessibility: accessibility ?? this.accessibility,
    audio: audio ?? this.audio,
  );
  void validate() {
    if (playerCharacterId != null)
      _nonEmpty(playerCharacterId!, 'playerCharacterId');
    if (starterCharacterId != null)
      _nonEmpty(starterCharacterId!, 'starterCharacterId');
    if (generation < 0 || contentVersion < 1)
      throw const FormatException('Invalid save version or generation.');
    if (contentVersion > supportedContentVersion)
      throw FutureSaveVersionException(contentVersion, field: 'contentVersion');
    for (final ids in [
      completedStageIds,
      unlockedStageIds,
      restoredNodeIds,
      unlockedCharacterIds,
      viewedStoryIds,
    ]) {
      for (final id in ids) {
        _nonEmpty(id, 'id');
      }
    }
    for (final entry in bestStars.entries) {
      _nonEmpty(entry.key, 'stageId');
      if (entry.value < 0 || entry.value > 3)
        throw const FormatException('Invalid star count.');
    }
    for (final records in [dailyActions, dailyReviewActions]) {
      for (final entry in records.entries) {
        if (!_isCalendarDate(entry.key) || entry.value < 0)
          throw const FormatException('Invalid daily record.');
      }
    }
    for (final entry in stageLastPlayedDates.entries) {
      _nonEmpty(entry.key, 'stageId');
      if (!_isCalendarDate(entry.value))
        throw const FormatException('Invalid last played date.');
    }
    for (final entry in decorationChoices.entries) {
      _nonEmpty(entry.key, 'nodeId');
      _nonEmpty(entry.value, 'choiceId');
    }
    for (final entry in masteryStates.entries) {
      _nonEmpty(entry.key, 'skillId');
    }
    for (final entry in skillProgress.entries) {
      if (entry.key != entry.value.skillId)
        throw const FormatException('Skill snapshot key mismatch.');
      _validateSkill(entry.value);
    }
    for (final entry in rewardLedger.entries) {
      if (entry.key != entry.value.attemptId)
        throw const FormatException('Reward ledger key mismatch.');
    }
    if (activeSession != null) jsonEncode(activeSession);
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'contentVersion': contentVersion,
    'generation': generation,
    'completedStageIds': completedStageIds.toList(),
    'unlockedStageIds': unlockedStageIds.toList(),
    'restoredNodeIds': restoredNodeIds.toList(),
    'unlockedCharacterIds': unlockedCharacterIds.toList(),
    'viewedStoryIds': viewedStoryIds.toList(),
    'playerCharacterId': playerCharacterId,
    'starterCharacterId': starterCharacterId,
    'onboardingCompleted': onboardingCompleted,
    'bestStars': bestStars,
    'dailyActions': dailyActions,
    'dailyReviewActions': dailyReviewActions,
    'stageLastPlayedDates': stageLastPlayedDates,
    'decorationChoices': decorationChoices,
    'skillProgress': skillProgress.map(
      (key, value) => MapEntry(key, _skillToJson(value)),
    ),
    'masteryStates': masteryStates.map(
      (key, value) => MapEntry(key, value.name),
    ),
    'activeSession': activeSession,
    'rewardLedger': rewardLedger.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'accessibility': accessibility.toJson(),
    'audio': audio.toJson(),
  };
  factory SaveEnvelopeV1.fromJson(Map<String, dynamic> json) {
    final version = _integer(json, 'schemaVersion');
    if (version > currentSchemaVersion)
      throw FutureSaveVersionException(version);
    if (version != currentSchemaVersion)
      throw FormatException('Unsupported save schema: $version');
    final ownedIds = _strings(
      json['unlockedCharacterIds'],
      'unlockedCharacterIds',
    );
    return SaveEnvelopeV1(
      generation: _integer(json, 'generation'),
      contentVersion: _integer(json, 'contentVersion'),
      completedStageIds: _strings(
        json['completedStageIds'],
        'completedStageIds',
      ),
      unlockedStageIds: _strings(json['unlockedStageIds'], 'unlockedStageIds'),
      restoredNodeIds: _strings(json['restoredNodeIds'], 'restoredNodeIds'),
      unlockedCharacterIds: ownedIds,
      viewedStoryIds: _strings(json['viewedStoryIds'], 'viewedStoryIds'),
      // Expedition onboarding is never inferred from previously owned IDs.
      // The repository isolates this run from the untouched previous epoch.
      playerCharacterId: json.containsKey('playerCharacterId')
          ? _optionalString(json, 'playerCharacterId')
          : null,
      starterCharacterId: json.containsKey('starterCharacterId')
          ? _optionalString(json, 'starterCharacterId')
          : _optionalString(json, 'playerCharacterId'),
      onboardingCompleted: json.containsKey('onboardingCompleted')
          ? _boolean(json, 'onboardingCompleted')
          : false,
      bestStars: _map(
        json['bestStars'],
      ).map((k, v) => MapEntry(k, _intValue(v, k))),
      dailyActions: _map(
        json['dailyActions'],
      ).map((k, v) => MapEntry(k, _intValue(v, k))),
      // Additive v1 migration: old saves retain every previous field and ID.
      dailyReviewActions: _map(
        json['dailyReviewActions'] ?? const <String, dynamic>{},
      ).map((k, v) => MapEntry(k, _intValue(v, k))),
      stageLastPlayedDates: _map(
        json['stageLastPlayedDates'] ?? const <String, dynamic>{},
      ).map((k, v) => MapEntry(k, _stringValue(v, k))),
      decorationChoices: _map(
        json['decorationChoices'],
      ).map((k, v) => MapEntry(k, _stringValue(v, k))),
      skillProgress: _map(
        json['skillProgress'],
      ).map((k, v) => MapEntry(k, _skillFromJson(_map(v)))),
      masteryStates: _map(
        json['masteryStates'],
      ).map((k, v) => MapEntry(k, _enumValue(SkillMasteryState.values, v, k))),
      activeSession: json['activeSession'] == null
          ? null
          : _map(json['activeSession']),
      rewardLedger: _map(
        json['rewardLedger'],
      ).map((k, v) => MapEntry(k, CompletionReceipt.fromJson(_map(v)))),
      accessibility: AccessibilitySettings.fromJson(
        _map(json['accessibility']),
      ),
      audio: AudioSettings.fromJson(
        _map(json['audio'] ?? const <String, dynamic>{}),
      ),
    );
  }
}

Map<String, Object?> _profileToJson(LearningVariantProfile p) => {
  'stageId': p.stageId,
  'primarySkillId': p.primarySkillId,
  'relationSchemaId': p.relationSchemaId,
  'answerAstShapeId': p.answerAstShapeId,
  'operandBandId': p.operandBandId,
  'unknownPositionId': p.unknownPositionId,
  'contextFamilyId': p.contextFamilyId,
  'representationId': p.representationId,
  'problemSeed': p.problemSeed,
  'boardSeed': p.boardSeed,
  'surfaceNouns': p.surfaceNouns.toList(),
};
LearningVariantProfile _profileFromJson(Map<String, dynamic> j) =>
    LearningVariantProfile(
      stageId: _string(j, 'stageId'),
      primarySkillId: _string(j, 'primarySkillId'),
      relationSchemaId: _string(j, 'relationSchemaId'),
      answerAstShapeId: _string(j, 'answerAstShapeId'),
      operandBandId: _string(j, 'operandBandId'),
      unknownPositionId: _string(j, 'unknownPositionId'),
      contextFamilyId: _string(j, 'contextFamilyId'),
      representationId: _string(j, 'representationId'),
      problemSeed: j['problemSeed'] == null ? null : _integer(j, 'problemSeed'),
      boardSeed: j['boardSeed'] == null ? null : _integer(j, 'boardSeed'),
      surfaceNouns: _strings(j['surfaceNouns'], 'surfaceNouns'),
    );
Map<String, Object?> _ticketToJson(ReviewTicket t) => {
  'id': t.id,
  'skillId': t.skillId,
  'sourceVariantId': t.sourceVariantId,
  'sourceVariantProfile': _profileToJson(t.sourceVariantProfile),
  'policyIndex': t.policyIndex,
  'stageOffset': t.stageOffset,
  'dueAfterCompletedStageCount': t.dueAfterCompletedStageCount,
  'reason': t.reason.name,
};
ReviewTicket _ticketFromJson(Map<String, dynamic> j) {
  final id = _string(j, 'id');
  final skillId = _string(j, 'skillId');
  final variantId = _string(j, 'sourceVariantId');
  final profile = _profileFromJson(_map(j['sourceVariantProfile']));
  final index = _integer(j, 'policyIndex');
  final offset = _integer(j, 'stageOffset');
  final due = _integer(j, 'dueAfterCompletedStageCount');
  if (profile.stageId != variantId ||
      profile.primarySkillId != skillId ||
      index < 0 ||
      offset < 1 ||
      due < offset) {
    throw const FormatException('Invalid review ticket.');
  }
  return ReviewTicket(
    id: id,
    skillId: skillId,
    sourceVariantId: variantId,
    sourceVariantProfile: profile,
    policyIndex: index,
    stageOffset: offset,
    dueAfterCompletedStageCount: due,
    reason: _enumValue(ReviewReason.values, j['reason'], 'reason'),
  );
}

Map<String, Object?> _skillToJson(SkillProgressSnapshot s) => {
  'skillId': s.skillId,
  'independentVariantProfiles': s.independentVariantProfiles
      .map(_profileToJson)
      .toList(),
  'hasDelayedIndependentSuccess': s.hasDelayedIndependentSuccess,
  'hasTransferIndependentSuccess': s.hasTransferIndependentSuccess,
  'pendingReviewTickets': s.pendingReviewTickets.map(_ticketToJson).toList(),
};
SkillProgressSnapshot _skillFromJson(Map<String, dynamic> j) =>
    SkillProgressSnapshot(
      skillId: _string(j, 'skillId'),
      independentVariantProfiles: _list(
        j['independentVariantProfiles'],
      ).map((v) => _profileFromJson(_map(v))),
      hasDelayedIndependentSuccess: _boolean(j, 'hasDelayedIndependentSuccess'),
      hasTransferIndependentSuccess: _boolean(
        j,
        'hasTransferIndependentSuccess',
      ),
      pendingReviewTickets: _list(
        j['pendingReviewTickets'],
      ).map((v) => _ticketFromJson(_map(v))),
    );
void _validateSkill(SkillProgressSnapshot s) {
  _nonEmpty(s.skillId, 'skillId');
  final accepted = <LearningVariantProfile>[];
  for (final p in s.independentVariantProfiles) {
    for (final field in [
      p.stageId,
      p.primarySkillId,
      p.relationSchemaId,
      p.answerAstShapeId,
      p.operandBandId,
      p.unknownPositionId,
      p.contextFamilyId,
      p.representationId,
    ]) {
      _nonEmpty(field, 'semantic profile');
    }
    if (p.primarySkillId != s.skillId ||
        accepted.any((other) => other.isSemanticallyEquivalentTo(p)) ||
        (accepted.isNotEmpty &&
            !accepted.any((other) => other.isIndependentVariationFrom(p)))) {
      throw const FormatException('Invalid independent learning evidence.');
    }
    accepted.add(p);
  }
  if (s.pendingReviewTickets.length > 1)
    throw const FormatException(
      'Only one active review ticket is allowed per skill.',
    );
  for (final t in s.pendingReviewTickets) {
    _ticketFromJson(_ticketToJson(t));
    final offsets = const ReviewPolicy().offsetsFor(
      supportNeeded: t.reason == ReviewReason.supportNeeded,
    );
    if (t.skillId != s.skillId ||
        t.sourceVariantId != t.sourceVariantProfile.stageId ||
        t.sourceVariantProfile.primarySkillId != s.skillId ||
        t.policyIndex < 0 ||
        t.policyIndex >= offsets.length ||
        t.stageOffset != offsets[t.policyIndex] ||
        t.dueAfterCompletedStageCount < t.stageOffset) {
      throw const FormatException('Invalid active review ticket.');
    }
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String))
    throw const FormatException('Expected JSON object.');
  return Map<String, dynamic>.from(value);
}

List<dynamic> _list(Object? value) {
  if (value is! List) throw const FormatException('Expected JSON array.');
  return value;
}

List<String> _strings(Object? value, String field) =>
    _list(value).map((item) => _stringValue(item, field)).toList();
int _intValue(Object? v, String field) {
  if (v is! int) throw FormatException('Expected integer: $field');
  return v;
}

int _integer(Map<String, dynamic> j, String field) =>
    _intValue(j[field], field);
num _number(Map<String, dynamic> j, String field) {
  final v = j[field];
  if (v is! num || !v.isFinite)
    throw FormatException('Expected number: $field');
  return v;
}

String _stringValue(Object? v, String field) {
  if (v is! String || v.trim().isEmpty)
    throw FormatException('Expected nonempty string: $field');
  return v;
}

String _string(Map<String, dynamic> j, String field) =>
    _stringValue(j[field], field);
String? _optionalString(Map<String, dynamic> j, String field) =>
    j[field] == null ? null : _string(j, field);
bool _boolean(Map<String, dynamic> j, String field) {
  final v = j[field];
  if (v is! bool) throw FormatException('Expected boolean: $field');
  return v;
}

T _enumValue<T extends Enum>(List<T> values, Object? v, String field) =>
    values.firstWhere(
      (e) => e.name == v,
      orElse: () => throw FormatException('Unknown enum: $field'),
    );
void _nonEmpty(String value, String field) {
  if (value.trim().isEmpty) throw FormatException('Empty $field');
}

bool _isCalendarDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final parsed = DateTime.tryParse(value);
  return parsed != null && localDateKey(parsed) == value;
}

String localDateKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic> _freezeMap(Map<String, dynamic> map) {
  dynamic freeze(dynamic value) {
    if (value is Map)
      return Map<String, dynamic>.unmodifiable(
        value.map((key, v) => MapEntry(key as String, freeze(v))),
      );
    if (value is List) return List<dynamic>.unmodifiable(value.map(freeze));
    if (value == null ||
        value is String ||
        value is bool ||
        (value is num && value.isFinite))
      return value;
    throw const FormatException(
      'Active session must contain only JSON values.',
    );
  }

  return freeze(map) as Map<String, dynamic>;
}
