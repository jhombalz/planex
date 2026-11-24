import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:planex/game/combat_state.dart';
import 'package:planex/game/weapon.dart';

void advance(CombatState state, double seconds) {
  for (var i = 0; i < (seconds * 100).ceil(); i++) {
    state.update(0.01);
  }
}

void main() {
  test('enemy warns before firing and keeps its telegraphed aim', () {
    final state = CombatState();
    final enemy = Enemy(100, 100, EnemyPattern.straight, 0)..fireTime = 10;
    state.enemies.add(enemy);
    state.update(0.01);
    expect(enemy.charge, greaterThan(0));
    expect(
      state.bullets.items.where(
        (b) => b.active && b.owner == BulletOwner.enemy,
      ),
      isEmpty,
    );
    final angle = enemy.aimAngle;
    state.player.x = 320;
    advance(state, 0.2);
    expect(
      state.bullets.items.where(
        (b) => b.active && b.owner == BulletOwner.enemy,
      ),
      isEmpty,
    );
    advance(state, 0.15);
    final shot = state.bullets.items.firstWhere(
      (b) => b.active && b.owner == BulletOwner.enemy,
    );
    expect(atan2(shot.velocity.y, shot.velocity.x), closeTo(angle, 0.0001));
  });
  test('offscreen enemies do not charge and destroyed enemies cannot finish firing', () {
    final state = CombatState();
    final hidden = Enemy(100, -100, EnemyPattern.straight, 0)..fireTime = 10;
    final visible = Enemy(100, 150, EnemyPattern.straight, 0, health: 1)
      ..fireTime = 10;
    state.enemies.addAll([hidden, visible]);
    state.update(0.01);
    expect(hidden.charge, 0);
    expect(visible.charge, greaterThan(0));
    state.bullets.spawn(100, 150, 0, 0, BulletOwner.player);
    state.update(0.01);
    advance(state, 0.5);
    expect(state.enemies.contains(visible), isFalse);
    expect(
      state.bullets.items.where(
        (b) => b.active && b.owner == BulletOwner.enemy,
      ),
      isEmpty,
    );
  });
  test(
    'boss arrival warning precedes spawn; entry does not fire hidden bullets',
    () {
      final state = CombatState()..stageTime = 42;
      expect(state.bossApproaching, isTrue);
      state.stageTime = 44.99;
      state.update(0.02);
      expect(state.bossApproaching, isFalse);
      final boss = state.boss!
        ..radialTime = 10
        ..aimedTime = 10;
      state.update(0.1);
      expect(boss.fanCharge, 0);
      expect(boss.aimCharge, 0);
      expect(
        state.bullets.items.where(
          (b) => b.active && b.owner == BulletOwner.enemy,
        ),
        isEmpty,
      );
      boss.position.setValues(180, 215);
      state.update(0.01);
      expect(boss.fanCharge, greaterThan(0));
      expect(boss.aimCharge, greaterThan(0));
      expect(
        state.bullets.items.where(
          (b) => b.active && b.owner == BulletOwner.enemy,
        ),
        isEmpty,
      );
      advance(state, 0.35);
      expect(
        state.bullets.items.where(
          (b) => b.active && b.owner == BulletOwner.enemy,
        ),
        isNotEmpty,
      );
    },
  );
  test('nearby pickups attract while distant drops continue falling', () {
    final state = CombatState();
    final near = Pickup(90, 530, PickupKind.power);
    final far = Pickup(30, 100, PickupKind.bomb);
    state.pickups.addAll([near, far]);
    state.update(0.1);
    expect(near.position.x, greaterThan(90));
    expect(far.position.x, 30);
    expect(far.position.y, greaterThan(100));
    advance(state, 0.5);
    expect(state.power, 2);
    expect(state.pickups.contains(near), isFalse);
  });
  test('projectile hits produce temporary feedback and hit sound', () {
    final state = CombatState();
    final enemy = Enemy(100, 100, EnemyPattern.straight, 0, health: 10);
    state.enemies.add(enemy);
    state.bullets.spawn(100, 100, 0, 0, BulletOwner.player);
    state.update(0.01);
    expect(enemy.health, 9);
    expect(enemy.hitTime, greaterThan(0));
    expect(state.sounds, contains(CombatSound.hit));
    advance(state, 0.15);
    expect(enemy.hitTime, 0);
    final boss = StageBoss(1)..position.setValues(180, 215);
    state.boss = boss;
    state.damageBossPart(boss.wings.first, 1);
    expect(boss.wings.first.hitTime, greaterThan(0));
    state.protection = 0;
    state.damagePlayer();
    expect(state.playerHitTime, greaterThan(0));
  });
  test(
    'pickup announcements and expiry warning occur once and reset cleanly',
    () {
      final state = CombatState();
      state.collect(PickupKind.power);
      expect(state.notice, 'POWER 2');
      state.collect(PickupKind.bonus, bonus: Weapon.laser);
      expect(state.notice, 'LASER BONUS');
      state.bonusTime = 3.01;
      state.update(0.03);
      expect(state.notice, 'BONUS ENDING');
      final noticeTime = state.noticeTime;
      state.update(0.1);
      expect(state.noticeTime, lessThan(noticeTime));
      state.reset();
      expect(state.noticeTime, 0);
      expect(state.playerHitTime, 0);
    },
  );
}
