import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planex/game/aircraft.dart';
import 'package:planex/services/player_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  test('scores, unlock, plane and settings survive reload', () async {
    final prefs = await SharedPreferences.getInstance();
    final profile = PlayerProfile(prefs);
    await profile.select(Aircraft.striker);
    expect(profile.selected, Aircraft.swift);
    await profile.recordRun(6000, 0);
    expect(profile.strikerUnlocked, isTrue);
    await profile.select(Aircraft.striker);
    profile.muted = true;
    profile.leftHanded = true;
    profile.reducedMotion = true;
    profile.sensitivity = 1.5;
    await profile.save();
    final reloaded = PlayerProfile(prefs);
    expect(reloaded.highScore, 6000);
    expect(reloaded.selected, Aircraft.striker);
    expect(
      reloaded.muted && reloaded.leftHanded && reloaded.reducedMotion,
      isTrue,
    );
    expect(reloaded.sensitivity, 1.5);
  });
  test(
    'stage clear unlocks plane and leaderboard keeps five sorted scores',
    () async {
      final profile = PlayerProfile(await SharedPreferences.getInstance());
      await profile.recordStage(1);
      expect(profile.strikerUnlocked, isTrue);
      for (final score in [100, 600, 200, 400, 300, 500]) {
        await profile.recordRun(score, 0);
      }
      expect(profile.scores, [600, 500, 400, 300, 200]);
      expect(profile.clearedStage, 1);
    },
  );
  test('malformed save falls back to safe defaults', () async {
    SharedPreferences.setMockInitialValues({
      PlayerProfile.storageKey: '{bad json',
    });
    final profile = PlayerProfile(await SharedPreferences.getInstance());
    expect(profile.highScore, 0);
    expect(profile.selected, Aircraft.swift);
    expect(profile.sensitivity, 1);
  });
  test(
    'invalid values are sanitized and locked selection cannot load',
    () async {
      SharedPreferences.setMockInitialValues({
        PlayerProfile.storageKey: jsonEncode({
          'scores': [-1, 'bad', 200],
          'clearedStage': -3,
          'sensitivity': 999,
          'selected': 'striker',
        }),
      });
      final profile = PlayerProfile(await SharedPreferences.getInstance());
      expect(profile.scores, [200]);
      expect(profile.clearedStage, 0);
      expect(profile.sensitivity, 1.8);
      expect(profile.selected, Aircraft.swift);
    },
  );
  test('rapid snapshots are written in order', () async {
    final prefs = await SharedPreferences.getInstance();
    final profile = PlayerProfile(prefs);
    profile.sensitivity = 0.5;
    final first = profile.save();
    profile.sensitivity = 1.8;
    final second = profile.save();
    await Future.wait([first, second]);
    expect(PlayerProfile(prefs).sensitivity, 1.8);
  });
}
