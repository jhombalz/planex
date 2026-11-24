import 'dart:async';

import 'package:flame_audio/flame_audio.dart';

import '../game/combat_state.dart';

/// One reusable native player per sound; no player allocation in the game loop.
class GameAudio {
  final Map<CombatSound, AudioPlayer> _effects = {};
  final Map<CombatSound, Future<void>> _effectQueues = {};
  AudioPlayer? _music;
  Future<void>? _initializing;
  Future<void> _musicQueue = Future.value();
  bool _ready = false;
  bool _disposed = false;
  bool _wanted = false;
  bool muted = false;
  bool unavailable = false;

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    try {
      for (final sound in CombatSound.values) {
        final player = AudioPlayer()..audioCache = FlameAudio.audioCache;
        _effects[sound] = player;
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setSource(AssetSource('${sound.name}.wav'));
      }
      final music = AudioPlayer()..audioCache = FlameAudio.audioCache;
      _music = music;
      await music.setReleaseMode(ReleaseMode.loop);
      await music.setVolume(0.22);
      await music.setSource(AssetSource('music.wav'));
      _ready = true;
      setPlaying(_wanted, mute: muted);
    } catch (_) {
      unavailable = true;
    }
  }

  void setPlaying(bool playing, {required bool mute}) {
    _wanted = playing;
    muted = mute;
    if (!_ready || _disposed) return;
    _musicQueue = _musicQueue
        .then((_) async {
          if (_disposed) return;
          if (_wanted && !muted) {
            await _music?.resume();
          } else {
            await _music?.pause();
          }
        })
        .catchError((Object _) {
          unavailable = true;
        });
  }

  void play(CombatSound sound) {
    if (!_ready ||
        _disposed ||
        muted ||
        (!_wanted && sound != CombatSound.clear)) {
      return;
    }
    final player = _effects[sound]!;
    // Drop overlapping requests for the same effect instead of building a backlog.
    if (_effectQueues.containsKey(sound)) return;
    _effectQueues[sound] = (() async {
      try {
        await player.stop();
        if (_disposed || muted || (!_wanted && sound != CombatSound.clear)) {
          return;
        }
        await player.setVolume(sound == CombatSound.shot ? 0.13 : 0.45);
        if (_disposed || muted || (!_wanted && sound != CombatSound.clear)) {
          return;
        }
        await player.resume();
      } catch (_) {
        unavailable = true;
      } finally {
        _effectQueues.remove(sound);
      }
    })();
  }

  void silence() {
    setPlaying(false, mute: muted);
    for (final entry in _effects.entries) {
      final pending = _effectQueues[entry.key] ?? Future<void>.value();
      unawaited(
        pending.then((_) => entry.value.stop()).catchError((Object _) {}),
      );
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    if (_initializing != null) await _initializing;
    await _musicQueue;
    await Future.wait(_effectQueues.values.toList());
    await _music?.dispose();
    for (final player in _effects.values) {
      await player.dispose();
    }
  }
}
