/// Additive save fields: old expedition saves keep all progress and receive
/// these defaults. Audio preferences never participate in learning/rewards.
class AudioSettings {
  AudioSettings({
    this.musicEnabled = true,
    this.effectsEnabled = true,
    this.hapticsEnabled = true,
    this.downloadPromptSeen = false,
    this.musicVolume = .45,
    this.effectsVolume = .65,
    this.musicTrackId = defaultMusicTrackId,
  }) {
    for (final volume in [musicVolume, effectsVolume]) {
      if (!volume.isFinite || volume < 0 || volume > 1) {
        throw ArgumentError.value(volume, 'volume');
      }
    }
    if (musicTrackId != defaultMusicTrackId &&
        !audioTracks.any((track) => track.id == musicTrackId)) {
      throw const FormatException('Unknown audio track.');
    }
  }

  final bool musicEnabled;
  final bool effectsEnabled;
  final bool hapticsEnabled;
  final bool downloadPromptSeen;
  final double musicVolume;
  final double effectsVolume;
  static const defaultMusicTrackId = 'default';

  /// Default follows the scene. An explicit selection plays everywhere,
  /// including the cold-start intro, without restarting on a scene change.
  final String musicTrackId;

  String trackFor(AudioScene scene) => musicTrackId == defaultMusicTrackId
      ? scene == AudioScene.intro
            ? 'intro'
            : 'bgm01'
      : musicTrackId;

  AudioSettings copyWith({
    bool? musicEnabled,
    bool? effectsEnabled,
    bool? hapticsEnabled,
    bool? downloadPromptSeen,
    double? musicVolume,
    double? effectsVolume,
    String? musicTrackId,
  }) => AudioSettings(
    musicEnabled: musicEnabled ?? this.musicEnabled,
    effectsEnabled: effectsEnabled ?? this.effectsEnabled,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    downloadPromptSeen: downloadPromptSeen ?? this.downloadPromptSeen,
    musicVolume: musicVolume ?? this.musicVolume,
    effectsVolume: effectsVolume ?? this.effectsVolume,
    musicTrackId: musicTrackId ?? this.musicTrackId,
  );

  Map<String, Object?> toJson() => {
    'musicEnabled': musicEnabled,
    'effectsEnabled': effectsEnabled,
    'hapticsEnabled': hapticsEnabled,
    'downloadPromptSeen': downloadPromptSeen,
    'musicVolume': musicVolume,
    'effectsVolume': effectsVolume,
    'musicTrackId': musicTrackId,
    // Retain compatible fields for existing save readers. They are derived
    // from the single setting, not independently configurable preferences.
    'introTrackId': trackFor(AudioScene.intro),
    'gameTrackId': trackFor(AudioScene.adventure),
  };

  factory AudioSettings.fromJson(Map<String, dynamic> json) => AudioSettings(
    musicEnabled: json['musicEnabled'] as bool? ?? true,
    effectsEnabled: json['effectsEnabled'] as bool? ?? true,
    hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
    downloadPromptSeen: json['downloadPromptSeen'] as bool? ?? false,
    musicVolume: (json['musicVolume'] as num?)?.toDouble() ?? .45,
    effectsVolume: (json['effectsVolume'] as num?)?.toDouble() ?? .65,
    musicTrackId: _readMusicTrack(json),
  );

  static String _readMusicTrack(Map<String, dynamic> json) {
    final unified = json['musicTrackId'] as String?;
    if (unified != null) return unified;
    // Preserve an existing custom adventure track first. A custom intro track
    // is retained if the adventure selection was still the old default.
    final adventure = json['gameTrackId'] as String? ?? 'bgm01';
    final intro = json['introTrackId'] as String? ?? 'intro';
    if (!audioTracks.any((track) => track.id == adventure) ||
        !audioTracks.any((track) => track.id == intro)) {
      throw const FormatException('Unknown legacy audio track.');
    }
    if (adventure != 'bgm01') return adventure;
    if (intro != 'intro') return intro;
    return defaultMusicTrackId;
  }
}

class AudioTrack {
  const AudioTrack(this.id, this.label, this.assetPath);
  final String id;
  final String label;
  final String assetPath;
}

const audioTracks = [
  AudioTrack('intro', 'Before the Great Dawn · 인트로', 'assets/audio/intro.mp3'),
  AudioTrack('bgm01', 'Yellow Plastic Swings', 'assets/audio/bgm01.mp3'),
  AudioTrack('bgm02', 'The First Bloom', 'assets/audio/bgm02.mp3'),
  AudioTrack('bgm03', 'Seven Miles to Spring', 'assets/audio/bgm03.mp3'),
  AudioTrack('bgm04', 'Glass Horizon', 'assets/audio/bgm04.mp3'),
  AudioTrack('bgm05', 'Highest Point of the Swing', 'assets/audio/bgm05.mp3'),
  AudioTrack('bgm06', 'Painted Ponies Turning', 'assets/audio/bgm06.mp3'),
];

enum AudioScene { intro, adventure }

enum PuzzleSound { select, swap, pop, special }

enum PuzzleHaptic { select, swap, match, fragment, success }
