import 'dart:math';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planex/game/combat_state.dart';
import 'package:planex/game/weapon.dart';
import 'package:planex/game/aircraft.dart';
import 'package:planex/services/player_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'old weapon selections are ignored and every new flight starts on Pulse',
    () async {
      SharedPreferences.setMockInitialValues({
        PlayerProfile.storageKey: jsonEncode({
          'weapon': 'plasma',
          'clearedStage': 3,
          'scores': [6000],
        }),
      });
      final profile = PlayerProfile(await SharedPreferences.getInstance());
      expect(profile.highScore, 6000);
      final state = CombatState()
        ..collect(PickupKind.bonus, bonus: Weapon.plasma);
      state.reset(selected: profile.selected);
      expect(state.weapon, Weapon.pulse);
      expect(state.bonusTime, 0);
    },
  );
  test('collecting each bonus equips it; timeout and death restore Pulse', () {
    final state = CombatState();
    for (final weapon in [Weapon.laser, Weapon.missiles, Weapon.plasma]) {
      state.collect(PickupKind.bonus, bonus: weapon);
      expect(state.weapon, weapon);
      expect(state.bonusTime, 18);
    }
    state.bonusTime = 0.05;
    state.update(0.1);
    expect(state.weapon, Weapon.pulse);
    state.collect(PickupKind.bonus, bonus: Weapon.laser);
    state.protection = 0;
    state.damagePlayer();
    expect(state.weapon, Weapon.pulse);
    expect(state.bonusTime, 0);
  });
  test('weapon drop is collected by contact without reducing P power', () {
    final state = CombatState()..power = 4;
    state.pickups.add(
      Pickup(180, 530, PickupKind.bonus, weapon: Weapon.missiles),
    );
    state.update(0.01);
    expect(state.weapon, Weapon.missiles);
    expect(state.power, 4);
    expect(state.pickups, isEmpty);
    state.collect(PickupKind.bonus, bonus: Weapon.laser);
    expect(state.bonusTime, 18);
  });
  test('four rapid kills guarantee a bonus; six kills give another reward', () {
    final state = CombatState(random: Random(42));
    for (var i = 0; i < 4; i++) {
      state.destroyEnemy(Enemy(100, 100, EnemyPattern.straight, 0));
    }
    expect(state.pickups.where((p) => p.kind == PickupKind.bonus), isNotEmpty);
    expect(
      state.pickups
          .where((p) => p.kind == PickupKind.bonus)
          .every((p) => p.weapon != null && p.weapon != Weapon.pulse),
      isTrue,
    );
    final count = state.pickups.where((p) => p.kind == PickupKind.bonus).length;
    state.streak = 0;
    for (var i = 0; i < 2; i++) {
      state.destroyEnemy(Enemy(100, 100, EnemyPattern.straight, 0));
    }
    expect(
      state.pickups.where((p) => p.kind == PickupKind.bonus).length,
      greaterThan(count),
    );
  });
  test('combo window expires while playing and drops remain bounded', () {
    final state = CombatState()
      ..streak = 3
      ..killWindow = 0.01;
    state.update(0.02);
    expect(state.streak, 0);
    for (var i = 0; i < 100; i++) {
      state.destroyEnemy(Enemy(100, 100, EnemyPattern.straight, 0));
    }
    expect(state.pickups.length, lessThanOrEqualTo(12));
  });
  test('P increases laser from one to two to three to four real beams', () {
    final state = CombatState()..collect(PickupKind.bonus, bonus: Weapon.laser);
    for (var power = 1; power <= 4; power++) {
      expect(state.laserOffsets.length, power);
      if (power < 4) state.collect(PickupKind.power);
    }
    final left = Enemy(144, 200, EnemyPattern.straight, 0, health: 10);
    final right = Enemy(216, 200, EnemyPattern.straight, 0, health: 10);
    state.enemies.addAll([left, right]);
    state.update(0.1);
    state.update(0.01);
    expect(left.health, lessThan(10));
    expect(right.health, lessThan(10));
    expect(state.power, 4);
  });
  test('laser pierces aligned enemies but respects shielded boss core', () {
    final state = CombatState()..weapon = Weapon.laser;
    final first = Enemy(180, 200, EnemyPattern.straight, 0, health: 4);
    final second = Enemy(180, 100, EnemyPattern.straight, 0, health: 4);
    final aside = Enemy(250, 100, EnemyPattern.straight, 0, health: 4);
    state.enemies.addAll([first, second, aside]);
    state.update(0.1);
    state.update(0.01);
    expect(first.health, 3);
    expect(second.health, 3);
    expect(aside.health, 4);
    final boss = StageBoss(1)..position.setValues(180, 215);
    state.boss = boss;
    state.update(0.1);
    expect(boss.core.health, boss.core.maxHealth);
    for (final wing in boss.wings) {
      wing.health = 0;
    }
    state.update(0.1);
    expect(boss.core.health, lessThan(boss.core.maxHealth));
  });
  test('P multiplies missile and plasma volleys too', () {
    final state = CombatState();
    for (var power = 1; power <= 4; power++) {
      state.power = power;
      state.weapon = Weapon.missiles;
      state.bullets.clear();
      state.shoot();
      expect(state.bullets.items.where((b) => b.active).length, power);
      state.weapon = Weapon.plasma;
      state.bullets.clear();
      state.shoot();
      expect(
        state.bullets.items.where((b) => b.active).length,
        [1, 2, 3, 5][power - 1],
      );
    }
  });
  test(
    'missiles steer toward valid targets and pooled damage metadata resets',
    () {
      final state = CombatState()..weapon = Weapon.missiles;
      state.enemies.add(Enemy(250, 200, EnemyPattern.straight, 0, health: 10));
      state.shoot();
      final missile = state.bullets.items.firstWhere((b) => b.active);
      state.update(0.02);
      expect(missile.velocity.x, greaterThan(0));
      missile.position.setValues(250, 200);
      state.update(0.001);
      expect(state.enemies.single.health, 5);
      state.bullets.clear();
      final reused = state.bullets.spawn(1, 2, 0, 3, BulletOwner.enemy)!;
      expect(reused.kind, Weapon.pulse);
      expect(reused.damage, 1);
    },
  );
  test(
    'entering level 2 equips bronze plane and Pulse; unlock saves',
    () async {
      final state = CombatState()
        ..stageCleared = true
        ..weapon = Weapon.laser
        ..bonusTime = 10;
      state.nextStage();
      expect(state.aircraft, Aircraft.striker);
      expect(state.weapon, Weapon.pulse);
      expect(state.bonusTime, 0);
      expect(state.power, greaterThanOrEqualTo(2));
      expect(Aircraft.striker.weaponColor, isNot(Aircraft.swift.weaponColor));
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final profile = PlayerProfile(prefs);
      await profile.recordStage(1);
      await profile.select(Aircraft.striker);
      expect(PlayerProfile(prefs).selected, Aircraft.striker);
    },
  );
  test('each level increases enemy health, speed and firing pressure', () {
    CombatState? previous;
    for (var stage = 1; stage <= 3; stage++) {
      final state = CombatState(random: Random(1))..stage = stage;
      state.spawnWave();
      state.boss = StageBoss(stage);
      if (previous != null) {
        expect(
          state.enemies.first.maxHealth,
          greaterThan(previous.enemies.first.maxHealth),
        );
        expect(
          state.enemies.first.speed,
          greaterThan(previous.enemies.first.speed),
        );
        expect(state.enemyFireInterval, lessThan(previous.enemyFireInterval));
        expect(state.enemyBulletSpeed, greaterThan(previous.enemyBulletSpeed));
        expect(state.bossFanInterval, lessThan(previous.bossFanInterval));
        expect(
          state.boss!.core.maxHealth,
          greaterThan(previous.boss!.core.maxHealth),
        );
      }
      previous = state;
    }
  });
}
