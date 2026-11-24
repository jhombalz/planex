import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planex/game/combat_state.dart';
import 'package:planex/game/weapon.dart';
import 'package:planex/game/sprite_art.dart';

void step(CombatState state, double seconds) {
  for (var i = 0; i < (seconds * 100).ceil(); i++) {
    state.update(0.01);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(SpriteArt.load);

  test(
    'bosses have distinct telegraphed fan, crossfire and spiral attacks',
    () {
      for (var stage = 1; stage <= 3; stage++) {
        final state = CombatState()..stage = stage;
        final boss = StageBoss(stage)
          ..position.setValues(180, 215)
          ..radialTime = 99;
        state.boss = boss;
        state.update(0.01);
        expect(boss.fanCharge, greaterThan(0));
        expect(
          state.bullets.items.where(
            (b) => b.active && b.owner == BulletOwner.enemy,
          ),
          isEmpty,
        );
        step(state, 0.36);
        final shots = state.bullets.items
            .where((b) => b.active && b.owner == BulletOwner.enemy)
            .toList();
        expect(shots.length, [9, 8, 14][stage - 1]);
        if (stage < 3) expect(shots.every((b) => b.velocity.y > 0), isTrue);
        if (stage == 2) {
          expect(
            shots.map((b) => b.position.x).reduce((a, b) => a + b) /
                shots.length,
            greaterThan(boss.position.x + 40),
          );
        }
        if (stage == 3) {
          expect(shots.any((b) => b.velocity.y < 0), isTrue);
          expect(shots.any((b) => b.velocity.y > 0), isTrue);
        }
      }
    },
  );

  test(
    'boss destruction plays before progression, is safe, and scores once',
    () {
      for (var stage = 1; stage <= 3; stage++) {
        final state = CombatState()..stage = stage;
        final boss = StageBoss(stage)..position.setValues(180, 215);
        state.boss = boss;
        for (final part in boss.parts) {
          state.damageBossPart(part, 10000);
        }
        final score = state.score;
        expect(boss.dying, isTrue);
        expect(state.stageCleared, isFalse);
        expect(state.useBomb(), isFalse);
        final lives = state.lives;
        state.protection = 0;
        state.damagePlayer();
        expect(state.lives, lives);
        step(state, 0.5);
        expect(state.stageCleared, isFalse);
        expect(boss.deathBursts, greaterThan(0));
        expect(state.blasts, isNotEmpty);
        if (stage == 3) {
          expect(state.blasts.any((b) => b.color == 0xffb38cff), isTrue);
        }
        step(state, 1.0);
        expect(state.stageCleared, isTrue);
        expect(state.ended, stage == 6);
        expect(state.score, score);
        expect(state.sounds, contains(CombatSound.clear));
      }
    },
  );

  test('each weapon emits a distinct bundled sound', () async {
    final sounds = <CombatSound>[];
    for (final weapon in Weapon.values) {
      final state = CombatState()..weapon = weapon;
      state.shoot();
      sounds.add(state.sounds.single);
    }
    expect(sounds.toSet().length, 4);
    for (final sound in CombatSound.values) {
      final bytes = await rootBundle.load('assets/audio/${sound.name}.wav');
      expect(String.fromCharCodes(bytes.buffer.asUint8List(0, 4)), 'RIFF');
    }
  });

  test(
    'aircraft retain physical proportions across tall fullscreen viewports',
    () async {
      for (final viewport in [
        const ui.Size(360, 640),
        const ui.Size(360, 800),
        const ui.Size(412, 915),
      ]) {
        for (final sprite in ['swift', 'striker', 'wraith']) {
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder);
          final sx = viewport.width / 360;
          final sy = viewport.height / 640;
          canvas.scale(sx, sy);
          SpriteArt.draw(
            canvas,
            sprite,
            const ui.Offset(180, 320),
            const ui.Size(54, 60),
            yScale: sx / sy,
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(
            viewport.width.toInt(),
            viewport.height.toInt(),
          );
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            var minX = image.width;
            var minY = image.height;
            var maxX = 0;
            var maxY = 0;
            for (var y = 0; y < image.height; y++) {
              for (var x = 0; x < image.width; x++) {
                if (bytes.getUint8((y * image.width + x) * 4 + 3) > 24) {
                  minX = min(minX, x);
                  minY = min(minY, y);
                  maxX = max(maxX, x);
                  maxY = max(maxY, y);
                }
              }
            }
            final ratio = (maxX - minX + 1) / (maxY - minY + 1);
            final source = SpriteArt.regions[sprite]!;
            expect(
              ratio,
              closeTo(source.width / source.height, 0.04),
              reason: '$sprite in $viewport',
            );
          } finally {
            image.dispose();
            picture.dispose();
          }
        }
      }
    },
  );
}
