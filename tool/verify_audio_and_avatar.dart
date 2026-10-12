import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../lib/core/audio/audio_controller.dart';
import '../lib/core/audio/audio_settings.dart';
import '../lib/features/companions/data/companion_catalog.dart';
import '../lib/features/companions/domain/companion_progress_service.dart';
import '../lib/features/progress/data/progress_repository.dart';
import '../lib/features/progress/domain/progress_models.dart';

void check(bool condition, String description) {
  if (!condition) throw StateError(description);
}

class RecordingAudioBackend implements AudioBackend {
  RecordingAudioBackend({this.available = true});
  bool available;
  final music = <(String?, double, bool)>[];
  final effects = <PuzzleSound>[];
  var suspensions = 0, disposals = 0, downloads = 0;
  @override
  bool get mediaAvailable => available;
  @override
  bool get supportsDownload => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> downloadAssets() async {
    downloads++;
    available = true;
  }

  @override
  Future<void> setMusic({
    required String? assetPath,
    required double volume,
    required bool active,
  }) async {
    music.add((assetPath, volume, active));
  }

  @override
  Future<void> playEffect(PuzzleSound sound, double volume) async {
    effects.add(sound);
  }

  @override
  void unlock() {}
  @override
  Future<void> suspend() async {
    suspensions++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

Future<void> main() async {
  final backend = RecordingAudioBackend();
  final haptics = <PuzzleHaptic>[];
  final audio = AudioController(
    backend,
    onHaptic: (cue) async {
      haptics.add(cue);
    },
  );
  audio.configure(AudioSettings(musicVolume: .3), AudioScene.intro);
  audio.setForeground(true);
  await audio.initialize();
  await audio.flush();
  check(
    backend.music.last == ('assets/audio/intro.mp3', .3, true),
    'Intro selection',
  );
  final requests = backend.music.length;
  audio.configure(audio.settings, AudioScene.intro);
  await audio.flush();
  check(backend.music.length == requests, 'Rebuild must not restart a track');
  audio.setForeground(false);
  audio.setForeground(true);
  await audio.flush();
  check(
    backend.music.length > requests && backend.music.last.$3,
    'Rapid pause/resume must reissue music even when the desired path is unchanged',
  );
  audio.play(PuzzleSound.select);
  check(
    backend.effects.length == 1 && haptics.last == PuzzleHaptic.select,
    'Selection feedback',
  );
  audio.setForeground(false);
  check(backend.suspensions == 2, 'Suspend is immediate');
  audio.play(PuzzleSound.swap);
  audio.haptic(PuzzleHaptic.success);
  await audio.flush();
  check(
    backend.effects.length == 1 && haptics.length == 1,
    'No background effects or haptics',
  );
  check(backend.music.last.$3 == false, 'Background music inactive');
  audio.configure(
    audio.settings.copyWith(gameTrackId: 'bgm02'),
    AudioScene.adventure,
  );
  await audio.flush();
  check(
    backend.music.last.$3 == false,
    'Settings never reactivate a background app',
  );
  audio.setForeground(true);
  await audio.flush();
  check(
    backend.music.last.$1 == 'assets/audio/bgm02.mp3' && backend.music.last.$3,
    'Resume desired scene',
  );
  audio.configure(
    audio.settings.copyWith(musicEnabled: false, effectsEnabled: false),
    AudioScene.adventure,
  );
  await audio.flush();
  audio.haptic(PuzzleHaptic.fragment);
  check(
    backend.music.last.$1 == null && haptics.last == PuzzleHaptic.fragment,
    'Haptics independent of muted sound',
  );
  audio.configure(
    audio.settings.copyWith(hapticsEnabled: false),
    AudioScene.adventure,
  );
  final feedbackCount = haptics.length;
  audio.haptic(PuzzleHaptic.success);
  check(haptics.length == feedbackCount, 'Haptic option');
  audio.configure(AudioSettings(gameTrackId: 'bgm01'), AudioScene.adventure);
  audio.configure(AudioSettings(gameTrackId: 'bgm03'), AudioScene.adventure);
  await audio.flush();
  check(backend.music.last.$1 == 'assets/audio/bgm03.mp3', 'Latest scene wins');
  await audio.dispose();
  audio.play(PuzzleSound.pop);
  audio.setForeground(true);
  check(
    backend.disposals == 1,
    'One disposal; disposed controller cannot restart',
  );

  final missing = RecordingAudioBackend(available: false);
  final silent = AudioController(missing);
  silent.setForeground(true);
  await silent.initialize();
  await silent.flush();
  check(
    missing.downloads == 0 && missing.music.isEmpty,
    'No automatic network download',
  );
  await silent.downloadAssets();
  check(
    missing.downloads == 1 &&
        silent.mediaAvailable &&
        missing.music.length == 1,
    'Optional one-time download',
  );
  await silent.dispose();

  final original = SaveEnvelopeV1.initial().copyWith(
    playerCharacterId: 'CHAR_A',
    unlockedCharacterIds: ['CHAR_A', 'CHAR_D', 'CHAR_J'],
    onboardingCompleted: true,
    completedStageIds: ['r01-c01-s10'],
    bestStars: {'r01-c01-s10': 3},
    restoredNodeIds: ['r01-c01-garden-02'],
    decorationChoices: {'r01-c01-garden-02': 'stone-path'},
    activeSession: {
      'stageId': 'r01-c02-s01',
      'board': [1, 2, 3],
      'draft': '4+',
    },
  );
  final legacy = original.toJson()
    ..remove('audio')
    ..remove('starterCharacterId');
  final migrated = SaveEnvelopeV1.fromJson(legacy);
  check(
    migrated.starterCharacterId == 'CHAR_A' && migrated.audio.musicEnabled,
    'Additive audio/starter migration',
  );
  final store = MemoryKeyValueSaveStore();
  final repo = ProgressRepository(store, initialFactory: () => migrated);
  final service = CompanionProgressService(repo);
  var changed = await service.selectPlayer('CHAR_D');
  check(
    changed.playerCharacterId == 'CHAR_D' &&
        changed.starterCharacterId == 'CHAR_A',
    'Active adventure avatar changes; initial avatar stays owned',
  );
  final beforeJson = migrated.toJson()
    ..remove('generation')
    ..remove('playerCharacterId');
  final afterJson = changed.toJson()
    ..remove('generation')
    ..remove('playerCharacterId');
  check(
    jsonEncode(beforeJson) == jsonEncode(afterJson),
    'Switch preserves every unrelated save field',
  );
  check(
    nextUnviewedCompanionArrival(changed)?.characterId == 'CHAR_D',
    'Selecting a rescued avatar must not swallow its story',
  );
  changed = await service.markArrivalViewed('CHAR_D');
  check(
    changed.viewedStoryIds.contains(
      companionRecruitmentById('CHAR_D')!.arrivalStoryId,
    ),
    'Current avatar rescue scene remains viewable',
  );
  final generation = changed.generation;
  check(
    (await service.selectPlayer('CHAR_D')).generation == generation,
    'Selecting current avatar is idempotent',
  );
  var rejected = false;
  try {
    await service.selectPlayer('CHAR_Z');
  } on StateError {
    rejected = true;
  }
  check(rejected, 'Locked character rejected');
  changed = await service.selectPlayer('CHAR_A');
  check(
    changed.unlockedCharacterIds.contains('CHAR_D'),
    'Changing player never revokes companions',
  );
  final savedAudio = AudioSettings(
    gameTrackId: 'bgm03',
    downloadPromptSeen: true,
    hapticsEnabled: false,
    musicVolume: .2,
  );
  await repo.update((save) => save.copyWith(audio: savedAudio));
  final restored = await ProgressRepository(store).load();
  check(
    restored.playerCharacterId == 'CHAR_A' &&
        restored.audio.gameTrackId == 'bgm03' &&
        !restored.audio.hapticsEnabled &&
        restored.audio.downloadPromptSeen &&
        restored.activeSession!['draft'] == '4+',
    'Restart restores audio, avatar and interrupted puzzle',
  );
  stdout.writeln(
    'PASS: audio scenes/lifecycle/mute/haptics/download, additive saves, rescued adventure-avatar selection and story continuity.',
  );
}
