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
    this.introTrackId = 'intro',
    this.gameTrackId = 'bgm01',
  }) {
    for (final volume in [musicVolume, effectsVolume]) {
      if (!volume.isFinite || volume < 0 || volume > 1) {
        throw ArgumentError.value(volume, 'volume');
      }
    }
    if (!audioTracks.any((track) => track.id == introTrackId) ||
        !audioTracks.any((track) => track.id == gameTrackId)) {
      throw const FormatException('Unknown audio track.');
    }
  }

  final bool musicEnabled;
  final bool effectsEnabled;
  final bool hapticsEnabled;
  final bool downloadPromptSeen;
  final double musicVolume;
  final double effectsVolume;
  final String introTrackId;
  final String gameTrackId;

  AudioSettings copyWith({
    bool? musicEnabled,
    bool? effectsEnabled,
    bool? hapticsEnabled,
    bool? downloadPromptSeen,
    double? musicVolume,
    double? effectsVolume,
    String? introTrackId,
    String? gameTrackId,
  }) => AudioSettings(
    musicEnabled: musicEnabled ?? this.musicEnabled,
    effectsEnabled: effectsEnabled ?? this.effectsEnabled,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    downloadPromptSeen: downloadPromptSeen ?? this.downloadPromptSeen,
    musicVolume: musicVolume ?? this.musicVolume,
    effectsVolume: effectsVolume ?? this.effectsVolume,
    introTrackId: introTrackId ?? this.introTrackId,
    gameTrackId: gameTrackId ?? this.gameTrackId,
  );

  Map<String, Object?> toJson() => {
    'musicEnabled': musicEnabled,
    'effectsEnabled': effectsEnabled,
    'hapticsEnabled': hapticsEnabled,
    'downloadPromptSeen': downloadPromptSeen,
    'musicVolume': musicVolume,
    'effectsVolume': effectsVolume,
    'introTrackId': introTrackId,
    'gameTrackId': gameTrackId,
  };

  factory AudioSettings.fromJson(Map<String, dynamic> json) => AudioSettings(
    musicEnabled: json['musicEnabled'] as bool? ?? true,
    effectsEnabled: json['effectsEnabled'] as bool? ?? true,
    hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
    downloadPromptSeen: json['downloadPromptSeen'] as bool? ?? false,
    musicVolume: (json['musicVolume'] as num?)?.toDouble() ?? .45,
    effectsVolume: (json['effectsVolume'] as num?)?.toDouble() ?? .65,
    introTrackId: json['introTrackId'] as String? ?? 'intro',
    gameTrackId: json['gameTrackId'] as String? ?? 'bgm01',
  );
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
];

enum AudioScene { intro, adventure }

enum PuzzleSound { select, swap, pop, special }

enum PuzzleHaptic { select, swap, match, fragment, success }
