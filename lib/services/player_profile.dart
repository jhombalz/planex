import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/aircraft.dart';

class PlayerProfile extends ChangeNotifier {
  PlayerProfile(this.preferences) {
    _read();
  }
  final SharedPreferences preferences;
  static const storageKey = 'planex_profile_v1';
  List<int> scores = [];
  int clearedStage = 0;
  Aircraft selected = Aircraft.swift;
  bool muted = false;
  bool reducedMotion = false;
  bool leftHanded = false;
  double sensitivity = 1;
  bool saveFailed = false;
  Future<void> _pending = Future.value();
  int get highScore => scores.isEmpty ? 0 : scores.first;
  bool get strikerUnlocked => highScore >= 5000 || clearedStage >= 1;

  void _read() {
    try {
      final raw = preferences.getString(storageKey);
      if (raw == null) return;
      final value = jsonDecode(raw) as Map<String, dynamic>;
      scores =
          (value['scores'] as List? ?? [])
              .whereType<int>()
              .where((s) => s >= 0 && s <= 1000000000)
              .toList()
            ..sort((a, b) => b.compareTo(a));
      scores = scores.take(5).toList();
      clearedStage =
          (value['clearedStage'] is int ? value['clearedStage'] as int : 0)
              .clamp(0, 3);
      selected = value['selected'] == Aircraft.striker.name && strikerUnlocked
          ? Aircraft.striker
          : Aircraft.swift;
      muted = value['muted'] == true;
      reducedMotion = value['reducedMotion'] == true;
      leftHanded = value['leftHanded'] == true;
      final saved = value['sensitivity'];
      if (saved is num && saved.isFinite) {
        sensitivity = saved.toDouble().clamp(0.5, 1.8);
      }
    } catch (_) {
      // A malformed or incompatible save must never prevent launching the game.
      scores = [];
      clearedStage = 0;
      selected = Aircraft.swift;
    }
  }

  Future<void> save() {
    final snapshot = jsonEncode({
      'scores': scores,
      'clearedStage': clearedStage,
      'selected': selected.name,
      'muted': muted,
      'reducedMotion': reducedMotion,
      'leftHanded': leftHanded,
      'sensitivity': sensitivity,
    });
    // Serialize immutable snapshots so an older write cannot overwrite a newer one.
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

  Future<void> recordRun(int score, int stage) {
    scores = [...scores, score.clamp(0, 1000000000)]
      ..sort((a, b) => b.compareTo(a));
    scores = scores.take(5).toList();
    clearedStage = stage.clamp(clearedStage, 3);
    return save();
  }

  Future<void> recordStage(int stage) {
    clearedStage = stage.clamp(clearedStage, 3);
    return save();
  }

  Future<void> select(Aircraft aircraft) async {
    if (aircraft == Aircraft.striker && !strikerUnlocked) return;
    selected = aircraft;
    await save();
  }
}
