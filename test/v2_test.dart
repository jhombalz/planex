import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planex/game/aircraft.dart';
import 'package:planex/game/campaign.dart';
import 'package:planex/game/combat_state.dart';
import 'package:planex/game/weapon.dart';
import 'package:planex/services/player_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<PlayerProfile> profile([Map<String, Object> data = const {}]) async {
    SharedPreferences.setMockInitialValues(data);
    return PlayerProfile(await SharedPreferences.getInstance());
  }

  test(
    'v1 progress survives migration; mode leaderboards stay separate',
    () async {
      final p = await profile({
        PlayerProfile.storageKey: jsonEncode({
          'scores': [100, 500],
          'clearedStage': 3,
          'selected': 'striker',
          'muted': true,
          'leftHanded': true,
          'sensitivity': 1.4,
        }),
      });
      expect(p.scores, [500, 100]);
      expect(p.selected, Aircraft.striker);
      expect(p.unlocked(Aircraft.wraith), isTrue);
      expect(p.muted && p.leftHanded, isTrue);
      expect(p.sensitivity, 1.4);
      await p.recordRun(999, 1, challenge: Challenge.easy);
      await p.recordRun(777, 2, challenge: Challenge.expert);
      await p.selectMode(Challenge.expert);
      final reloaded = PlayerProfile(p.preferences);
      expect(reloaded.highScore, 777);
      expect(reloaded.scores, [500, 100]);
      expect(reloaded.modeScores[Challenge.easy], [999]);
      expect(reloaded.clearedStage, 3);
    },
  );

  test('checkpoint snapshots restore stage resources but reset hazards and bonuses', () async {
    final p = await profile();
    final s = CombatState()
      ..reset(
        selected: Aircraft.wraith,
        challenge: Challenge.expert,
        startStage: 4,
      );
    s.score = 12345;
    s.elapsed = 180;
    s.power = 4;
    s.bombs = 3;
    s.lives = 2;
    s.stats.kills = 30;
    s.stats.weapons.add('laser');
    await p.saveCheckpoint(s.checkpoint());
    s.stats.kills = 999;
    final saved = PlayerProfile(p.preferences).checkpoint!;
    expect(saved.stats.kills, 30);
    final restored = CombatState()..restore(saved);
    expect(restored.stage, 4);
    expect(restored.mode, Challenge.expert);
    expect(restored.aircraft, Aircraft.wraith);
    expect(
      [restored.score, restored.power, restored.bombs, restored.lives],
      [12345, 4, 3, 2],
    );
    expect(restored.stageTime, 0);
    expect(restored.elapsed, 180);
    expect(restored.difficulty, s.difficulty);
    expect(restored.weapon, Weapon.pulse);
    expect(restored.enemies, isEmpty);
    expect(restored.boss, isNull);
    expect(RunCheckpoint.fromJson({...saved.toJson(), 'stage': 7}), isNull);
    expect(RunCheckpoint.fromJson({...saved.toJson(), 'lives': 0}), isNull);
    expect(
      RunCheckpoint.fromJson({...saved.toJson(), 'mode': 'invalid'}),
      isNull,
    );
  });

  test(
    'practice cannot alter scores, unlocks, medals, achievements or checkpoint',
    () async {
      final p = await profile();
      await p.saveCheckpoint(CombatState().checkpoint());
      final before = p.preferences.getString(PlayerProfile.storageKey);
      final stats = RunStats()
        ..kills = 99
        ..maxCombo = 20
        ..maxPower = 4;
      await p.recordStage(
        6,
        challenge: Challenge.expert,
        stats: stats,
        medal: Medal.gold,
        practice: true,
      );
      await p.recordRun(99999, 6, stats: stats, practice: true);
      expect(p.preferences.getString(PlayerProfile.storageKey), before);
      expect(p.clearedStage, 0);
      expect(p.achievements, isEmpty);
      expect(p.scores, isEmpty);
    },
  );

  test(
    'medals retain best by mode and achievements persist without duplicates',
    () async {
      final p = await profile();
      final stats = RunStats()
        ..kills = 30
        ..maxCombo = 8
        ..maxPower = 4;
      stats.weapons.addAll(['laser', 'missiles', 'plasma']);
      await p.recordStage(
        6,
        challenge: Challenge.expert,
        stats: stats,
        medal: Medal.gold,
      );
      await p.recordStage(
        6,
        challenge: Challenge.expert,
        stats: stats,
        medal: Medal.bronze,
      );
      expect(p.medals['expert:6'], Medal.gold.index);
      expect(p.medals['normal:6'], isNull);
      expect(p.achievements.length, Achievement.values.length);
      expect(PlayerProfile(p.preferences).achievements, p.achievements);
      expect(p.completions['expert'], 2);
    },
  );

  test('difficulty and aircraft perks change actual combat values', () {
    final easy = CombatState()..reset(challenge: Challenge.easy);
    final normal = CombatState()..reset();
    final expert = CombatState()..reset(challenge: Challenge.expert);
    expect(easy.lives, 5);
    expect(expert.enemyBulletSpeed, greaterThan(normal.enemyBulletSpeed));
    expect(easy.enemyFireInterval, greaterThan(normal.enemyFireInterval));
    expect(expert.bonusDuration, lessThan(normal.bonusDuration));
    final wraith = CombatState()..reset(selected: Aircraft.wraith);
    expect(wraith.bombs, 1);
    expect(wraith.bonusDuration, greaterThan(normal.bonusDuration));
    expect(wraith.aircraft.fireMultiplier, lessThan(1));
  });

  test('new bosses fire distinct pincer, lane and helix projectile paths', () {
    for (final stage in [4, 5, 6]) {
      final state = CombatState()..reset(startStage: stage);
      state.boss = StageBoss(stage)
        ..position.setValues(180, 215)
        ..fanCharge = 0.001;
      state.update(0.01);
      final shots = state.bullets.items
          .where((b) => b.active && b.owner == BulletOwner.enemy)
          .toList();
      expect(shots.length, {4: 12, 5: 7, 6: 18}[stage]);
      final paths = shots
          .map(
            (b) =>
                '${b.velocity.x.toStringAsFixed(2)}:${b.velocity.y.toStringAsFixed(2)}',
          )
          .toSet();
      expect(paths.length, stage == 5 ? 1 : shots.length);
      if (stage == 5) {
        expect(
          shots.map((b) => b.position.x.toStringAsFixed(2)).toSet().length,
          7,
        );
        expect(shots.every((b) => b.velocity.y > 0), isTrue);
      }
    }
  });

  test('all six stages have ordered waves, one ace and three boss phases', () {
    expect(stageWaves.length, campaign.length);
    for (var stage = 1; stage <= campaign.length; stage++) {
      final waves = stageWaves[stage - 1];
      for (var i = 1; i < waves.length; i++) {
        expect(waves[i].$1, greaterThan(waves[i - 1].$1));
      }
      final s = CombatState()..reset(startStage: stage);
      s.stageTime = 22;
      s.update(0.01);
      expect(
        s.enemies.where((e) => e.pattern == EnemyPattern.miniboss).length,
        1,
      );
      s.update(0.01);
      expect(
        s.enemies.where((e) => e.pattern == EnemyPattern.miniboss).length,
        1,
      );
      final boss = StageBoss(stage);
      expect(boss.phase, 1);
      boss.wings.first.health = 0;
      expect(boss.phase, 2);
      boss.wings.last.health = 0;
      expect(boss.phase, 3);
      boss.core.health = 0;
      expect(boss.phase, 4);
    }
  });
}
