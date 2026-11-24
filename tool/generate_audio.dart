// Original synthesized soundtrack and effects. Run: dart tool/generate_audio.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const rate = 22050;
void write(String name, double seconds, double Function(double) sample) {
  final count = (seconds * rate).round();
  final data = ByteData(44 + count * 2);
  void text(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  data.setUint32(4, 36 + count * 2, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  text(36, 'data');
  data.setUint32(40, count * 2, Endian.little);
  for (var i = 0; i < count; i++) {
    data.setInt16(
      44 + i * 2,
      (sample(i / rate).clamp(-1.0, 1.0) * 24000).round(),
      Endian.little,
    );
  }
  File('assets/audio/$name.wav').writeAsBytesSync(data.buffer.asUint8List());
}

void main() {
  Directory('assets/audio').createSync(recursive: true);
  final random = Random(42);
  write(
    'shot',
    0.09,
    (t) => sin(2 * pi * (1600 * t - 5000 * t * t)) * exp(-t * 45) * 0.5,
  );
  write(
    'explosion',
    0.38,
    (t) =>
        ((random.nextDouble() * 2 - 1) * 0.7 + sin(2 * pi * 65 * t) * 0.3) *
        exp(-t * 10),
  );
  write(
    'bomb',
    0.7,
    (t) =>
        ((random.nextDouble() * 2 - 1) * 0.5 +
            sin(2 * pi * (95 * t - 50 * t * t)) * 0.5) *
        exp(-t * 5),
  );
  write(
    'pickup',
    0.28,
    (t) => sin(2 * pi * (600 * t + 1800 * t * t)) * sin(pi * t / 0.28) * 0.6,
  );
  write('clear', 0.9, (t) {
    final frequency = [
      523.25,
      659.25,
      783.99,
      1046.5,
    ][min(3, (t / 0.2).floor())];
    return sin(2 * pi * frequency * t) * 0.5 * min(1, (0.9 - t) * 5);
  });
  const notes = [
    64,
    67,
    71,
    76,
    71,
    67,
    62,
    67,
    60,
    64,
    67,
    72,
    67,
    64,
    62,
    59,
  ];
  write('music', 8, (t) {
    final beat = (t / 0.25).floor();
    final local = t % 0.25;
    final hz = 440 * pow(2, (notes[beat % notes.length] - 69) / 12);
    final melody = sin(2 * pi * hz * t) * exp(-local * 12) * 0.28;
    final bass = sin(2 * pi * (beat ~/ 8 % 2 == 0 ? 82.41 : 65.41) * t) * 0.16;
    final drum =
        sin(2 * pi * (65 * local - 55 * local * local)) *
        exp(-local * 35) *
        0.32;
    return (melody + bass + drum) * min(1, t * 100) * min(1, (8 - t) * 100);
  });
}
