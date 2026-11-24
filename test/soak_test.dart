import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:planex/game/combat_state.dart';
import 'package:planex/game/weapon.dart';

void main() {
  test('ten-minute combat stress simulation keeps entities bounded', () {
    var state = CombatState(random: Random(42))
      ..stage = 3
      ..power = 4
      ..protection = 100000;
    final watch = Stopwatch()..start();
    var maxBullets = 0,
        maxEnemies = 0,
        maxPickups = 0,
        maxBlasts = 0,
        maxWaves = 0;
    for (var frame = 0; frame < 60 * 600; frame++) {
      if (state.stageCleared) {
        state = CombatState(random: Random(frame))
          ..stage = 3
          ..power = 4
          ..protection = 100000;
      }
      state.stageTime = 0;
      if (frame % 60 == 0) state.spawnWave();
      if (frame % 600 == 0) {
        state.collect(
          PickupKind.bonus,
          bonus: Weapon.values[(frame ~/ 600) % 4],
        );
      }
      if (frame % 900 == 0 && state.boss == null) {
        state.boss = StageBoss(3)..position.setValues(180, 215);
      }
      state.player.x = 180 + sin(frame / 60) * 100;
      if (frame % 180 == 0) {
        state.bombs = 2;
        state.useBomb();
      }
      state.update(1 / 60);
      maxBullets = max(
        maxBullets,
        state.bullets.items.where((b) => b.active).length,
      );
      maxEnemies = max(maxEnemies, state.enemies.length);
      maxPickups = max(maxPickups, state.pickups.length);
      maxBlasts = max(maxBlasts, state.blasts.length);
      maxWaves = max(maxWaves, state.bombWaves.length);
      state.sounds.clear();
    }
    watch.stop();
    expect(maxBullets, lessThanOrEqualTo(192));
    expect(maxEnemies, lessThanOrEqualTo(32));
    expect(maxPickups, lessThanOrEqualTo(12));
    expect(maxBlasts, lessThanOrEqualTo(32));
    expect(maxWaves, lessThanOrEqualTo(3));
    Directory('build').createSync(recursive: true);
    File('build/combat-soak.json').writeAsStringSync(
      jsonEncode({
        'simulatedSeconds': 600,
        'frames': 36000,
        'executionMilliseconds': watch.elapsedMilliseconds,
        'peakBullets': maxBullets,
        'peakEnemies': maxEnemies,
        'peakPickups': maxPickups,
        'peakBlasts': maxBlasts,
        'peakBombWaves': maxWaves,
        'scope': 'Headless combat simulation; not physical-device FPS or native audio validation',
      }),
    );
  });
}
