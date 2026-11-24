import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planex/game/sprite_art.dart';
import 'package:planex/game/scenery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(SpriteArt.load);

  test(
    'three cached scenery images cover the viewport through scroll wrap',
    () async {
      expect(SpriteArt.backgrounds.length, 3);
      expect(
        SpriteArt.backgrounds.values.every((image) => image.width <= 512),
        isTrue,
      );
      for (var stage = 1; stage <= 3; stage++) {
        for (final scroll in [0.0, 320.0, 639.9, 640.0]) {
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder)..scale(64 / 360, 96 / 640);
          Scenery.draw(canvas, stage, scroll);
          final picture = recorder.endRecording();
          final image = await picture.toImage(64, 96);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            for (final pixel in [0, 63, 64 * 95, 64 * 96 - 1, 64 * 48 + 32]) {
              expect(
                bytes!.getUint8(pixel * 4 + 3),
                255,
                reason: 'stage $stage scroll $scroll',
              );
            }
          } finally {
            image.dispose();
            picture.dispose();
          }
        }
      }
    },
  );

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
