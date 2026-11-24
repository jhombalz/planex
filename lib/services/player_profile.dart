import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/aircraft.dart';
import '../game/campaign.dart';

class PlayerProfile extends ChangeNotifier {
  PlayerProfile(this.preferences) {
    _read();
  }
  final SharedPreferences preferences;
  static const storageKey = 'planex_profile_v1';
  List<int> scores = [];
  final Map<Challenge, List<int>> modeScores = {
    Challenge.easy: [],
    Challenge.expert: [],
  };
  final Map<String, int> medals = {};
  final Map<String, int> completions = {};
  final Map<String, int> rushBests = {};
  final Set<String> achievements = {};
  final Set<String> collectedWeapons = {};
  int clearedStage = 0;
  Aircraft selected = Aircraft.swift;
  Challenge mode = Challenge.normal;
  RunCheckpoint? checkpoint;
  bool tutorialSeen = false;
  bool muted = false,
      reducedMotion = false,
      leftHanded = false,
      saveFailed = false;
  double sensitivity = 1;
  Future<void> _pending = Future.value();
  List<int> get visibleScores =>
      mode == Challenge.normal ? scores : modeScores[mode]!;
  int get highScore => visibleScores.isEmpty ? 0 : visibleScores.first;
  bool get strikerUnlocked => clearedStage >= 1;
  bool get bossRushUnlocked => clearedStage >= campaign.length;
  bool unlocked(Aircraft plane) => switch (plane) {
    Aircraft.swift => true,
    Aircraft.striker => clearedStage >= 1,
    Aircraft.wraith => clearedStage >= 3,
  };

  List<int> _scores(dynamic raw) => raw is List
      ? (raw.whereType<int>().where((s) => s >= 0 && s <= 1000000000).toList()
              ..sort((a, b) => b.compareTo(a)))
            .take(5)
            .toList()
      : [];
  void _read() {
    try {
      final raw = preferences.getString(storageKey);
      if (raw == null) return;
      final v = jsonDecode(raw) as Map<String, dynamic>;
      scores = _scores(v['scores']);
      clearedStage = (v['clearedStage'] is int ? v['clearedStage'] as int : 0)
          .clamp(0, campaign.length);
      selected = Aircraft.values.firstWhere(
        (p) => p.name == v['selected'] && unlocked(p),
        orElse: () => Aircraft.swift,
      );
      mode = Challenge.values.firstWhere(
        (m) => m.name == v['mode'],
        orElse: () => Challenge.normal,
      );
      for (final m in [Challenge.easy, Challenge.expert]) {
        modeScores[m] = _scores(
          v['modeScores'] is Map ? (v['modeScores'] as Map)[m.name] : null,
        );
      }
      if (v['medals'] is Map) {
        for (final entry in (v['medals'] as Map).entries) {
          if (entry.key is String &&
              RegExp(r'^(easy|normal|expert):[1-6]$')
                  .hasMatch(entry.key as String) &&
              entry.value is int) {
            medals[entry.key as String] = (entry.value as int).clamp(0, 2);
          }
        }
      }
      if (v['completions'] is Map) {
        for (final m in Challenge.values) {
          final n = (v['completions'] as Map)[m.name];
          if (n is int && n >= 0) completions[m.name] = n.clamp(0, 1000000);
        }
      }
      if (v['rushBests'] is Map) {
        for (final m in Challenge.values) {
          final score = (v['rushBests'] as Map)[m.name];
          if (score is int && score >= 0) {
            rushBests[m.name] = score.clamp(0, 1000000000);
          }
        }
      }
      if (v['achievements'] is List) {
        achievements.addAll(
          (v['achievements'] as List).whereType<String>().where(
            (id) => Achievement.values.any((a) => a.name == id),
          ),
        );
      }
      if (v['collectedWeapons'] is List) {
        collectedWeapons.addAll(
          (v['collectedWeapons'] as List).whereType<String>().where(
            (w) => ['laser', 'missiles', 'plasma', 'spread'].contains(w),
          ),
        );
      }
      checkpoint = RunCheckpoint.fromJson(v['checkpoint']);
      tutorialSeen = v['tutorialSeen'] == true;
      muted = v['muted'] == true;
      reducedMotion = v['reducedMotion'] == true;
      leftHanded = v['leftHanded'] == true;
      final speed = v['sensitivity'];
      if (speed is num && speed.isFinite) {
        sensitivity = speed.toDouble().clamp(0.5, 1.8);
      }
    } catch (_) {
      scores = [];
      clearedStage = 0;
      selected = Aircraft.swift;
      checkpoint = null;
    }
  }

  Future<void> save() {
    final snapshot = jsonEncode({
      'schema': 2,
      'scores': scores,
      'modeScores': {for (final e in modeScores.entries) e.key.name: e.value},
      'clearedStage': clearedStage,
      'selected': selected.name,
      'mode': mode.name,
      'medals': medals,
      'completions': completions,
      'rushBests': rushBests,
      'achievements': achievements.toList(),
      'collectedWeapons': collectedWeapons.toList(),
      'checkpoint': checkpoint?.toJson(),
      'tutorialSeen': tutorialSeen,
      'muted': muted,
      'reducedMotion': reducedMotion,
      'leftHanded': leftHanded,
      'sensitivity': sensitivity,
    });
    _pending = _pending.then((_) async {
      try {
        saveFailed = !await preferences.setString(storageKey, snapshot);
      } catch (_) {
        saveFailed = true;
      }
      notifyListeners();
    });
    notifyListeners();
    return _pending;
  }

  void _award(RunStats? stats, int stage, Challenge challenge, {Medal? medal}) {
    if (stats == null) return;
    void earn(Achievement a, bool condition) {
      if (condition) achievements.add(a.name);
    }

    earn(Achievement.firstKill, stats.kills > 0);
    earn(Achievement.comboAce, stats.maxCombo >= 8);
    earn(Achievement.powerMaster, stats.maxPower >= 4);
    earn(Achievement.untouchable, stage > 0 && medal == Medal.gold);
    earn(Achievement.bossHunter, stage >= 3);
    earn(Achievement.campaignHero, stage >= campaign.length);
    earn(
      Achievement.expertPilot,
      stage >= campaign.length && challenge == Challenge.expert,
    );
    earn(Achievement.noBombs, stage >= campaign.length && stats.bombs == 0);
    collectedWeapons.addAll(stats.weapons);
    earn(
      Achievement.arsenal,
      ['laser', 'missiles', 'plasma'].every(collectedWeapons.contains),
    );
  }

  Future<void> recordRun(
    int score,
    int stage, {
    Challenge challenge = Challenge.normal,
    RunStats? stats,
    bool practice = false,
  }) {
    if (practice) return Future.value();
    final list = challenge == Challenge.normal
        ? scores
        : modeScores[challenge]!;
    final next = [...list, score.clamp(0, 1000000000)]
      ..sort((a, b) => b.compareTo(a));
    if (challenge == Challenge.normal) {
      scores = next.take(5).toList();
    } else {
      modeScores[challenge] = next.take(5).toList();
    }
    clearedStage = stage.clamp(clearedStage, campaign.length);
    _award(stats, stage, challenge);
    return save();
  }

  Future<void> recordStage(
    int stage, {
    Challenge challenge = Challenge.normal,
    RunStats? stats,
    Medal? medal,
    bool practice = false,
  }) {
    if (practice) return Future.value();
    clearedStage = stage.clamp(clearedStage, campaign.length);
    if (medal != null) {
      final key = '${challenge.name}:$stage';
      if ((medals[key] ?? -1) < medal.index) medals[key] = medal.index;
    }
    if (stage == campaign.length) {
      completions[challenge.name] = (completions[challenge.name] ?? 0) + 1;
    }
    _award(stats, stage, challenge, medal: medal);
    return save();
  }

  Future<void> saveCheckpoint(RunCheckpoint value) {
    checkpoint = RunCheckpoint.fromJson(value.toJson());
    return save();
  }

  Future<void> clearCheckpoint() {
    checkpoint = null;
    return save();
  }

  Future<void> recordBossRush(int score, Challenge challenge) {
    final best = rushBests[challenge.name] ?? 0;
    rushBests[challenge.name] = score.clamp(best, 1000000000);
    return save();
  }

  Future<void> selectMode(Challenge value) {
    mode = value;
    return save();
  }

  Future<void> select(Aircraft aircraft) async {
    if (!unlocked(aircraft)) return;
    selected = aircraft;
    await save();
  }
}
