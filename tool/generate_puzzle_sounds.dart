import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Reproducible original PCM cues. No extracted reference-game audio.
void main() {
  const rate = 22050;
  final random = math.Random(42026);
  for (final spec in <(String, double)>[
    ('select', .075),
    ('swap', .13),
    ('pop', .18),
    ('special', .34),
  ]) {
    final count = (spec.$2 * rate).round();
    final bytes = ByteData(44 + count * 2);
    void ascii(int offset, String value) {
      for (var i = 0; i < value.length; i++)
        bytes.setUint8(offset + i, value.codeUnitAt(i));
    }

    ascii(0, 'RIFF');
    bytes.setUint32(4, bytes.lengthInBytes - 8, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, rate, Endian.little);
    bytes.setUint32(28, rate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    bytes.setUint32(40, count * 2, Endian.little);
    for (var i = 0; i < count; i++) {
      final t = i / rate, u = i / count;
      final envelope = math.min(1.0, t / .004) * math.pow(1 - u, 2.5);
      final sample = switch (spec.$1) {
        'select' => math.sin(2 * math.pi * 880 * t) * .22,
        'swap' => math.sin(2 * math.pi * (280 * t + 1000 * t * t)) * .25,
        'pop' =>
          math.sin(2 * math.pi * (600 * t - 1100 * t * t)) * .28 +
              (random.nextDouble() * 2 - 1) * .09,
        _ =>
          (math.sin(2 * math.pi * 523.25 * t) +
                  math.sin(2 * math.pi * 659.25 * t) +
                  math.sin(2 * math.pi * 783.99 * t)) *
              .105,
      };
      bytes.setInt16(
        44 + i * 2,
        (sample * envelope * 32767).round(),
        Endian.little,
      );
    }
    final file = File('assets/audio/${spec.$1}.wav');
    if (file.existsSync())
      throw StateError('Refusing to overwrite ${file.path}');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes.buffer.asUint8List());
    stdout.writeln('${file.path}: ${bytes.lengthInBytes} bytes');
  }
}
