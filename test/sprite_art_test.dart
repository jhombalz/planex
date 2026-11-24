import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planex/game/sprite_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(SpriteArt.load);

  test(
    'atlas loads once and contains all aircraft and projectile regions',
    () async {
      final first = SpriteArt.load();
      expect(identical(first, SpriteArt.load()), isTrue);
      expect(SpriteArt.ready, isTrue);
      expect(
        SpriteArt.regions.keys,
        containsAll([
          'swift',
          'striker',
          'enemyScout',
          'enemyInterceptor',
          'enemyGunship',
          'bossCoral',
          'bossHarbor',
          'bossStorm',
          'pulse',
          'enemyBullet',
          'missile',
          'plasma',
          'laser',
          'bossTurret',
          'bossCore',
          'bomb',
        ]),
      );
    },
  );

  test('sprite atlas preserves a transparent background', () async {
    final data = await rootBundle.load('assets/images/arcade_atlas.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final image = (await codec.getNextFrame()).image;
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(bytes!.getUint8(3), 0);
      expect(bytes.getUint8((image.width - 1) * 4 + 3), 0);
    } finally {
      image.dispose();
      codec.dispose();
    }
  });

  test(
    'every sprite renders visible pixels from its own atlas region',
    () async {
      for (final name in SpriteArt.regions.keys) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        SpriteArt.draw(
          canvas,
          name,
          const ui.Offset(32, 32),
          const ui.Size(56, 56),
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(64, 64);
        try {
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          var visible = 0;
          for (var i = 3; i < bytes!.lengthInBytes; i += 4) {
            if (bytes.getUint8(i) > 24) visible++;
          }
          expect(visible, greaterThan(30), reason: name);
        } finally {
          image.dispose();
          picture.dispose();
        }
      }
    },
  );
}
