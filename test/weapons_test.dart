import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planex/game/combat_state.dart';
import 'package:planex/game/weapon.dart';
import 'package:planex/services/player_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('locked weapons cannot be equipped on reset or via profile', () async {
    final state = CombatState()..reset(selectedWeapon: Weapon.plasma);
    expect(state.weapon, Weapon.pulse);
    expect(state.availableWeapons, [Weapon.pulse]);
    state.cycleWeapon();
    expect(state.weapon, Weapon.pulse);
    SharedPreferences.setMockInitialValues({});
    final profile = PlayerProfile(await SharedPreferences.getInstance());
    await profile.selectWeapon(Weapon.missiles);
    expect(profile.selectedWeapon, Weapon.pulse);
  });
  test('stage unlocks persist and selected weapon survives restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final profile = PlayerProfile(prefs);
    for (var stage = 1; stage <= 3; stage++) {
      await profile.recordStage(stage);
      expect(profile.selectedWeapon, Weapon.values[stage]);
      expect(profile.weapons.length, stage + 1);
    }
    await profile.selectWeapon(Weapon.laser);
    final loaded = PlayerProfile(prefs);
    expect(loaded.selectedWeapon, Weapon.laser);
    expect(loaded.weapons, Weapon.values);
    final state = CombatState()
      ..reset(
        unlocked: loaded.clearedStage,
        selectedWeapon: loaded.selectedWeapon,
      );
    expect(state.weapon, Weapon.laser);
    state.cycleWeapon();
    expect(state.weapon, Weapon.missiles);
  });
  test('next stage equips newly unlocked laser then missiles', () {
    final state = CombatState()..stageCleared = true;
    state.nextStage();
    expect(state.weapon, Weapon.laser);
    state.stageCleared = true;
    state.nextStage();
    expect(state.weapon, Weapon.missiles);
  });
  test(
    'laser pierces aligned enemies and leaves off-axis targets untouched',
    () {
      final state = CombatState()..weapon = Weapon.laser;
      final front = Enemy(180, 200, EnemyPattern.straight, 0, health: 4);
      final rear = Enemy(180, 100, EnemyPattern.straight, 0, health: 4);
      final aside = Enemy(250, 100, EnemyPattern.straight, 0, health: 4);
      state.enemies.addAll([front, rear, aside]);
      state.update(0.1);
      state.update(0.01);
      expect(front.health, 3);
      expect(rear.health, 3);
      expect(aside.health, 4);
      expect(
        state.bullets.items.where(
          (b) => b.active && b.owner == BulletOwner.player,
        ),
        isEmpty,
      );
    },
  );
  test('laser respects boss shield and damages exposed core', () {
    final state = CombatState()..weapon = Weapon.laser;
    final boss = StageBoss(1)..position.setValues(180, 175);
    state.boss = boss;
    final initial = boss.core.health;
    state.update(0.1);
    state.update(0.01);
    expect(boss.core.health, initial);
    for (final wing in boss.wings) {
      wing.health = 0;
    }
    state.update(0.1);
    expect(boss.core.health, lessThan(initial));
  });
  test('missiles steer toward enemies and deal explosive damage', () {
    final state = CombatState()..weapon = Weapon.missiles;
    state.enemies.add(Enemy(250, 200, EnemyPattern.straight, 0, health: 10));
    state.shoot();
    final missile = state.bullets.items.firstWhere((b) => b.active);
    expect(missile.kind, Weapon.missiles);
    state.update(0.02);
    expect(missile.velocity.x, greaterThan(0));
    missile.position.setValues(250, 200);
    state.update(0.001);
    expect(state.enemies.single.health, 5);
    expect(state.blasts, isNotEmpty);
  });
  test('homing missiles prefer boss turrets over shielded core', () {
    final state = CombatState()..weapon = Weapon.missiles;
    state.boss = StageBoss(1)..position.setValues(180, 175);
    state.shoot();
    final missile = state.bullets.items.firstWhere((b) => b.active);
    state.update(0.01);
    expect(missile.velocity.x.abs(), greaterThan(0));
  });
  test(
    'plasma is a distinct three-way weapon and pool resets its metadata',
    () {
      final state = CombatState()
        ..weapon = Weapon.plasma
        ..power = 4;
      state.shoot();
      final shots = state.bullets.items.where((b) => b.active).toList();
      expect(shots.length, 3);
      expect(
        shots.every((b) => b.kind == Weapon.plasma && b.damage == 6),
        isTrue,
      );
      final first = shots.first;
      state.bullets.clear();
      final recycled = state.bullets.spawn(10, 20, 0, 100, BulletOwner.enemy)!;
      expect(identical(first, recycled), isTrue);
      expect(recycled.kind, Weapon.pulse);
      expect(recycled.damage, 1);
    },
  );
  test('bomb creates visible effects on empty screen and effects expire', () {
    final state = CombatState();
    state.useBomb();
    expect(state.bombWaves.length, 1);
    expect(state.blasts.length, 10);
    expect(state.blasts.any((blast) => blast.delay > 0), isTrue);
    for (var i = 0; i < 15; i++) {
      state.update(0.1);
    }
    expect(state.bombWaves, isEmpty);
    expect(state.blasts, isEmpty);
  });
  test('later stages have tougher waves and schedules stay ordered', () {
    final first = CombatState(random: Random(1))..spawnWave();
    final later = CombatState(random: Random(1))..stage = 3;
    later.spawnWave();
    expect(
      later.enemies.first.maxHealth,
      greaterThan(first.enemies.first.maxHealth),
    );
    expect(later.enemies.first.speed, greaterThan(first.enemies.first.speed));
    for (final schedule in stageWaves) {
      for (var i = 1; i < schedule.length; i++) {
        expect(schedule[i].$1, greaterThan(schedule[i - 1].$1));
      }
    }
    expect(stageWaves.last.length, greaterThan(stageWaves.first.length));
  });
}
