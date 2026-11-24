import 'package:flutter_test/flutter_test.dart';
import 'package:planex/game/aircraft.dart';
import 'package:planex/game/combat_state.dart';

void main() {
  test('four power levels have distinct projectile patterns', () {
    final state = CombatState();
    for (var power = 1; power <= 4; power++) {
      state.bullets.clear();
      state.power = power;
      state.shoot();
      final shots = state.bullets.items.where((b) => b.active).toList();
      expect(shots.length, [1, 2, 3, 5][power - 1]);
      if (power >= 3) {
        expect(shots.any((b) => b.velocity.x < 0), isTrue);
        expect(shots.any((b) => b.velocity.x > 0), isTrue);
      }
    }
  });
  test('pickups are collected by proximity; caps award bonus points', () {
    final state = CombatState();
    state.pickups.add(Pickup(180, 530, PickupKind.power));
    state.update(0.01);
    expect(state.power, 2);
    expect(state.pickups, isEmpty);
    state.power = 4;
    state.collect(PickupKind.power);
    expect(state.power, 4);
    expect(state.score, 1000);
    state.bombs = 5;
    state.collect(PickupKind.bomb);
    expect(state.bombs, 5);
    expect(state.score, 1500);
  });
  test(
    'bomb clears enemy bullets, kills enemies once and grants protection',
    () {
      final state = CombatState()..protection = 0;
      state.enemies.add(Enemy(100, 100, EnemyPattern.straight, 0));
      state.bullets.spawn(50, 50, 0, 100, BulletOwner.enemy);
      final friendly = state.bullets.spawn(
        150,
        200,
        0,
        -600,
        BulletOwner.player,
      )!;
      expect(state.useBomb(), isTrue);
      expect(state.bombs, 1);
      expect(state.score, 100);
      expect(state.enemies, isEmpty);
      expect(friendly.active, isTrue);
      expect(
        state.bullets.items.where(
          (b) => b.active && b.owner == BulletOwner.enemy,
        ),
        isEmpty,
      );
      expect(state.protection, greaterThanOrEqualTo(1.5));
      state.useBomb();
      expect(state.score, 100);
      expect(state.useBomb(), isFalse);
      expect(state.bombs, 0);
      state.bombs = 2;
      state.stageCleared = true;
      expect(state.useBomb(), isFalse);
      state.stageCleared = false;
      state.ended = true;
      expect(state.useBomb(), isFalse);
    },
  );
  test('every third kill drops supplies; damage reduces power', () {
    final state = CombatState()
      ..protection = 0
      ..power = 4;
    for (var i = 0; i < 9; i++) {
      state.destroyEnemy(Enemy(100, 100, EnemyPattern.straight, 0));
    }
    final supplies = state.pickups
        .where((p) => p.kind != PickupKind.bonus)
        .toList();
    expect(supplies.length, 3);
    expect(supplies.last.kind, PickupKind.bomb);
    state.damagePlayer();
    expect(state.power, 3);
  });
  test('boss arrives after approach and replaces normal hazards', () {
    final state = CombatState()..stageTime = 44.99;
    state.enemies.add(Enemy(100, 100, EnemyPattern.straight, 0));
    state.bullets.spawn(20, 20, 0, 20, BulletOwner.enemy);
    state.update(0.02);
    expect(state.boss, isNotNull);
    expect(state.enemies, isEmpty);
    expect(
      state.bullets.items.where(
        (b) => b.active && b.owner == BulletOwner.enemy,
      ),
      isEmpty,
    );
  });
  test(
    'shielded core consumes a shot without damage; turret can be destroyed',
    () {
      final state = CombatState();
      final boss = StageBoss(1)..position.setValues(180, 110);
      state.boss = boss;
      state.bullets.spawn(180, 110, 0, 0, BulletOwner.player);
      final initialHealth = boss.core.health;
      state.update(0.001);
      expect(boss.core.health, initialHealth);
      final wing = boss.wings.first..health = 1;
      state.bullets.spawn(
        boss.position.x + wing.offsetX,
        110,
        0,
        0,
        BulletOwner.player,
      );
      state.update(0.001);
      expect(wing.health, 0);
      expect(state.score, 500);
    },
  );
  test('three boss victories advance stages and finish campaign once', () {
    final state = CombatState()..power = 4;
    for (var stage = 1; stage <= 3; stage++) {
      expect(state.stage, stage);
      final boss = StageBoss(stage)..position.setValues(180, 110);
      state.boss = boss;
      for (final wing in boss.wings) {
        state.damageBossPart(wing, 1000);
      }
      expect(boss.exposed, isTrue);
      state.damageBossPart(boss.core, 1000);
      final score = state.score;
      state.damageBossPart(boss.core, 1000);
      expect(state.score, score);
      expect(boss.dying, isTrue);
      expect(state.stageCleared, isFalse);
      for (var i = 0; i < 15; i++) {
        state.update(0.1);
      }
      expect(state.stageCleared, isTrue);
      final time = state.elapsed;
      state.update(0.1);
      expect(state.elapsed, time);
      if (stage < 3) {
        state.nextStage();
        expect(state.boss, isNull);
        expect(state.stageTime, 0);
        expect(state.power, 4);
        expect(state.protection, 3);
      }
    }
    expect(state.victory, isTrue);
    expect(state.ended, isTrue);
    state.nextStage();
    expect(state.stage, 3);
    state.reset(selected: Aircraft.striker);
    expect(state.stageCleared, isFalse);
    expect(state.stage, 1);
    expect(state.power, 2);
    expect(state.boss, isNull);
  });
  test(
    'boss fires radial and turret patterns after entering the playfield',
    () {
      final state = CombatState()..stage = 2;
      state.boss = StageBoss(2)
        ..position.setValues(180, 215)
        ..radialTime = 2
        ..aimedTime = 2;
      state.update(0.01);
      for (var i = 0; i < 4; i++) {
        state.update(0.1);
      }
      final shots = state.bullets.items
          .where((b) => b.active && b.owner == BulletOwner.enemy)
          .toList();
      expect(shots.length, 10);
      expect(shots.every((b) => b.velocity.y > 0), isTrue);
    },
  );
}
