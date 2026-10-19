import 'package:flutter/material.dart';

import 'audio_settings.dart';

class AudioOptions extends StatelessWidget {
  const AudioOptions({
    required this.settings,
    required this.onChanged,
    required this.mediaAvailable,
    this.onDownload,
    this.downloading = false,
    this.message,
    super.key,
  });
  final AudioSettings settings;
  final ValueChanged<AudioSettings> onChanged;
  final bool mediaAvailable;
  final VoidCallback? onDownload;
  final bool downloading;
  final String? message;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!mediaAvailable) ...[
        const Text('현재 버전의 음원 팩이 없습니다. 다운로드하지 않아도 탐험과 저장은 가능합니다.'),
        if (onDownload != null)
          OutlinedButton.icon(
            key: const Key('download-audio'),
            onPressed: downloading ? null : onDownload,
            icon: const Icon(Icons.download_rounded),
            label: Text(
              downloading ? '음원 다운로드·검증 중…' : '음원 받기 · 약 30MB, 팩당 1회',
            ),
          ),
      ],
      if (message != null) Text(message!, style: const TextStyle(fontSize: 12)),
      SwitchListTile(
        title: const Text('배경 음악'),
        value: settings.musicEnabled,
        onChanged: (value) => onChanged(settings.copyWith(musicEnabled: value)),
      ),
      _trackPicker(
        context,
        '음악 선택',
        settings.musicTrackId,
        (id) => onChanged(settings.copyWith(musicTrackId: id)),
      ),
      const Text(
        '곡을 누르면 바로 적용·자동 저장됩니다. 음악이 꺼져 있으면 배경 음악을 켜 주세요. 직접 고른 곡은 인트로와 탐험에서 이어집니다.',
        style: TextStyle(fontSize: 12),
      ),
      const Text('음악 음량'),
      Slider(
        value: settings.musicVolume,
        min: 0,
        max: 1,
        divisions: 20,
        label: '${(settings.musicVolume * 100).round()}%',
        onChanged: (value) => onChanged(settings.copyWith(musicVolume: value)),
      ),
      SwitchListTile(
        title: const Text('퍼즐 효과음'),
        value: settings.effectsEnabled,
        onChanged: (value) =>
            onChanged(settings.copyWith(effectsEnabled: value)),
      ),
      const Text('효과음 음량'),
      Slider(
        value: settings.effectsVolume,
        min: 0,
        max: 1,
        divisions: 20,
        label: '${(settings.effectsVolume * 100).round()}%',
        onChanged: (value) =>
            onChanged(settings.copyWith(effectsVolume: value)),
      ),
      const Text(
        '다른 앱으로 이동하면 음악과 효과음이 멈춥니다. 복귀하면 음악을 이어서 재생합니다.',
        style: TextStyle(fontSize: 12),
      ),
      SwitchListTile(
        title: const Text('퍼즐 햅틱'),
        subtitle: const Text('선택·매치·풀이 블록 획득·정답 완료'),
        value: settings.hapticsEnabled,
        onChanged: (value) =>
            onChanged(settings.copyWith(hapticsEnabled: value)),
      ),
    ],
  );

  Widget _trackPicker(
    BuildContext context,
    String label,
    String value,
    ValueChanged<String> change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      for (final track in [
        const AudioTrack(
          AudioSettings.defaultMusicTrackId,
          '기본 · 인트로 → 탐험 BGM',
          '',
        ),
        ...audioTracks,
      ])
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Material(
            color: value == track.id
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            child: Semantics(
              selected: value == track.id,
              button: true,
              child: InkWell(
                key: Key('audio-track-${track.id}'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => change(track.id),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          value == track.id
                              ? Icons.check_circle
                              : Icons.play_circle_outline,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            track.label,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
