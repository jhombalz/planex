import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:planex/game/combat_state.dart';

void main() {
  test('projectile is consumed once; a kill awards score once', () {
    final state = CombatState();
    state.enemies.add(Enemy(100, 100, EnemyPattern.straight, 0)..health = 1);
    final shot = state.bullets.spawn(100, 100, 0, 0, BulletOwner.player)!;
    state.update(0.001);
    state.update(0.001);
    expect(state.score, 100);
    expect(state.enemies, isEmpty);
    expect(shot.active, isFalse);
  });
  test('three hits end the run; respawn protects against repeated damage', () {
    final state = CombatState()..protection = 0;
    state.damagePlayer();
    expect(state.lives, 2);
    expect(state.protection, 2);
    state.damagePlayer();
    expect(state.lives, 2);
    state.protection = 0;
    state.damagePlayer();
    state.protection = 0;
    state.damagePlayer();
    expect(state.lives, 0);
    expect(state.ended, isTrue);
    state.damagePlayer();
    expect(state.lives, 0);
  });
  test('enemy bullets hurt player but player bullets do not', () {
    final state = CombatState()..protection = 0;
    state.bullets.spawn(180, 530, 0, 0, BulletOwner.player);
    state.update(0.001);
    expect(state.lives, 3);
    state.bullets.spawn(180, 530, 0, 0, BulletOwner.enemy);
    state.update(0.001);
    expect(state.lives, 2);
    expect(
      state.bullets.items.where(
        (b) => b.active && b.owner == BulletOwner.enemy,
      ),
      isEmpty,
    );
  });
  test('launch shield blocks damage and expires during gameplay', () {
    final state = CombatState();
    state.damagePlayer();
    expect(state.lives, 3);
    for (var i = 0; i < 21; i++) {
      state.update(0.1);
    }
    expect(state.protection, 0);
    state.damagePlayer();
    expect(state.lives, 2);
  });
  test('pool is bounded and reuses objects with reset velocity and owner', () {
    final pool = BulletPool(1);
    final first = pool.spawn(1, 2, 3, 4, BulletOwner.enemy)!;
    expect(pool.spawn(0, 0, 0, 0, BulletOwner.player), isNull);
    first.active = false;
    final reused = pool.spawn(10, 20, 0, -600, BulletOwner.player)!;
    expect(identical(first, reused), isTrue);
    expect(reused.position.x, 10);
    expect(reused.velocity.y, -600);
    expect(reused.owner, BulletOwner.player);
  });
  test('all viewport edges reclaim bullets', () {
    final state = CombatState();
    for (final point in [
      (-31.0, 100.0),
      (391.0, 100.0),
      (100.0, -41.0),
      (100.0, 681.0),
    ]) {
      state.bullets.spawn(point.$1, point.$2, 0, 0, BulletOwner.enemy);
    }
    state.update(0.001);
    expect(state.bullets.items.where((b) => b.active), isEmpty);
  });
  test('waves rotate patterns and difficulty is capped', () {
    final state = CombatState(random: Random(1));
    for (final pattern in EnemyPattern.values) {
      state.enemies.clear();
      state.spawnWave();
      expect(state.enemies.every((e) => e.pattern == pattern), isTrue);
    }
    state.elapsed = 25;
    expect(state.difficulty, 2);
    state.elapsed = 1000;
    expect(state.difficulty, 6);
    for (var i = 0; i < 50; i++) {
      state.spawnWave();
    }
    expect(state.enemies.length, lessThanOrEqualTo(32));
  });
  test('enemies fire aimed bullets; sine and turret movement differ', () {
    final state = CombatState();
    final sine = Enemy(100, 100, EnemyPattern.sine, 100)..fireTime = 3;
    final turret = Enemy(260, 120, EnemyPattern.turret, 100);
    state.enemies.addAll([sine, turret]);
    state.update(0.1);
    expect(sine.position.x, isNot(100));
    expect(turret.position.y, 120);
    for (var i = 0; i < 3; i++) {
      state.update(0.1);
    }
    final shot = state.bullets.items.firstWhere(
      (b) => b.active && b.owner == BulletOwner.enemy,
    );
    expect(shot.velocity.x, greaterThan(0));
    expect(shot.velocity.y, greaterThan(0));
  });
  test('restart clears score, hazards, difficulty and restores lives', () {
    final state = CombatState()
      ..score = 1000
      ..lives = 0
      ..elapsed = 100
      ..ended = true;
    state.spawnWave();
    state.bullets.spawn(10, 10, 0, 100, BulletOwner.enemy);
    state.reset();
    expect(state.lives, 3);
    expect(state.score, 0);
    expect(state.difficulty, 1);
    expect(state.ended, isFalse);
    expect(state.enemies, isEmpty);
    expect(state.bullets.items.where((b) => b.active), isEmpty);
  });
}
