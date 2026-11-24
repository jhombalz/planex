import 'dart:async';
import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';

import '../services/game_audio.dart';
import '../services/player_profile.dart';
import 'artwork.dart';
import 'combat_state.dart';

class FlightGame extends FlameGame with DragCallbacks {
  FlightGame(this.profile, {this.enableAudio = true});
  final PlayerProfile profile;
  final bool enableAudio;
  final audio = GameAudio();
  final combat = CombatState();
  final hudRevision = ValueNotifier(0);
  bool started = false;
  bool get ended => combat.ended;
  bool active = false;
  int get score => combat.score;
  double scroll = 0;
  int? _pointer;
  int _hudHash = 0;
  bool _recorded = false;

  @override
  Future<void> onLoad() async {
    overlays.add('menu');
    pauseEngine();
    if (enableAudio) unawaited(audio.initialize());
  }

  void startFlight() {
    if (!started || ended) {
      combat.reset(selected: profile.selected);
      _recorded = false;
    }
    started = active = true;
    _pointer = null;
    overlays.remove('menu');
    overlays.remove('debrief');
    overlays.add('hud');
    audio.setPlaying(true, mute: profile.muted);
    resumeEngine();
    refreshHud();
  }

  void pauseFlight() {
    if (!active) return;
    active = false;
    _pointer = null;
    pauseEngine();
    audio.silence();
    overlays.remove('hud');
    overlays.add('menu');
  }

  void settingsChanged() {
    if (profile.muted) audio.silence();
    audio.setPlaying(active, mute: profile.muted);
    refreshHud();
  }

  void _recordRun() {
    if (_recorded) return;
    _recorded = true;
    unawaited(
      profile.recordRun(
        score,
        combat.stageCleared ? combat.stage : combat.stage - 1,
      ),
    );
  }

  void returnToHangar() {
    if (started) _recordRun();
    active = started = false;
    _pointer = null;
    combat.reset(selected: profile.selected);
    pauseEngine();
    audio.silence();
    overlays.remove('hud');
    overlays.remove('debrief');
    overlays.add('menu');
  }

  void nextStage() {
    combat.nextStage();
    startFlight();
  }

  bool useBomb() {
    if (!active) return false;
    final used = combat.useBomb();
    _playSounds();
    refreshHud();
    return used;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (active && _pointer == null) _pointer = event.pointerId;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!active || event.pointerId != _pointer) return;
    final scale = min(size.x / 360, size.y / 640);
    if (scale <= 0) return;
    combat.player.add(
      event.localDelta / scale * profile.sensitivity * combat.aircraft.handling,
    );
    combat.player.x = combat.player.x.clamp(24, 336);
    combat.player.y = combat.player.y.clamp(80, 600);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (event.pointerId == _pointer) _pointer = null;
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    if (event.pointerId == _pointer) _pointer = null;
  }

  void refreshHud() {
    final hash = Object.hash(
      combat.score,
      combat.lives,
      combat.power,
      combat.bombs,
      combat.stage,
      combat.stageCleared,
      combat.difficulty,
      profile.leftHanded,
    );
    if (hash != _hudHash) {
      _hudHash = hash;
      hudRevision.value++;
    }
  }

  void _playSounds() {
    for (final sound in combat.sounds) {
      audio.play(sound);
    }
    combat.sounds.clear();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!active) return;
    scroll = (scroll + min(dt, 0.1) * 55) % 640;
    combat.update(dt);
    _playSounds();
    refreshHud();
    if (combat.stageCleared) {
      active = false;
      _pointer = null;
      pauseEngine();
      audio.setPlaying(false, mute: profile.muted);
      overlays.remove('hud');
      overlays.add('debrief');
      unawaited(profile.recordStage(combat.stage));
      if (combat.victory) _recordRun();
    } else if (ended) {
      _recordRun();
      pauseFlight();
    }
  }

  @override
  void onRemove() {
    unawaited(audio.dispose());
    hudRevision.dispose();
    super.onRemove();
  }

  void label(
    Canvas canvas,
    String text,
    Offset at, {
    double size = 14,
    Color color = const Color(0xffffffff),
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final scale = min(size.x / 360, size.y / 640);
    canvas.save();
    canvas.translate((size.x - 360 * scale) / 2, (size.y - 640 * scale) / 2);
    canvas.scale(scale);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 360, 640));
    final background = const [
      Color(0xff092f45),
      Color(0xff152d3e),
      Color(0xff202742),
    ][combat.stage - 1];
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 360, 640),
      Paint()..color = background,
    );
    if (combat.bombFlash > 0 && !profile.reducedMotion) {
      canvas.translate(
        sin(combat.bombFlash * 120) * 3,
        cos(combat.bombFlash * 90) * 3,
      );
    }
    for (var i = 0; i < 18; i++) {
      final y = (i * 83.0 + scroll) % 720 - 60;
      final x = (i * 137.0) % 360;
      if (combat.stage == 2) {
        canvas.drawRect(
          Rect.fromLTWH(i.isEven ? -10 : 316, y, 54, 58),
          Paint()..color = const Color(0xff425263),
        );
        canvas.drawLine(
          Offset(0, y + 64),
          Offset(360, y + 64),
          Paint()..color = const Color(0xff274958),
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, y),
            width: combat.stage == 1 ? 85 : 150,
            height: 24,
          ),
          Paint()
            ..color = combat.stage == 1
                ? const Color(0xff104459)
                : const Color(0xff303952),
        );
        if (combat.stage == 1 && i % 5 == 0) {
          canvas.drawOval(
            Rect.fromCenter(center: Offset(x, y), width: 54, height: 30),
            Paint()..color = const Color(0xff36715c),
          );
        }
      }
    }
    for (final shot in combat.bullets.items) {
      if (!shot.active) continue;
      final point = Offset(shot.position.x, shot.position.y);
      if (shot.owner == BulletOwner.player) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: point, width: 4, height: 16),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xff9dffe6),
        );
      } else {
        canvas.drawCircle(point, 5, Paint()..color = const Color(0xffffb74d));
        canvas.drawCircle(point, 2, Paint()..color = const Color(0xfffff3ba));
      }
    }
    for (final enemy in combat.enemies) {
      Artwork.enemy(
        canvas,
        Offset(enemy.position.x, enemy.position.y),
        enemy.pattern,
      );
    }
    if (combat.boss != null) Artwork.boss(canvas, combat.boss!);
    for (final pickup in combat.pickups) {
      final point = Offset(pickup.position.x, pickup.position.y);
      canvas.drawCircle(
        point,
        14,
        Paint()
          ..color = pickup.kind == PickupKind.power
              ? const Color(0xff3ee5ae)
              : const Color(0xffe6a74c),
      );
      label(
        canvas,
        pickup.kind == PickupKind.power ? 'P' : 'B',
        point - const Offset(5, 9),
        color: const Color(0xff102c3a),
      );
    }
    final player = Offset(combat.player.x, combat.player.y);
    if (combat.protection <= 0 ||
        profile.reducedMotion ||
        (combat.protection * 8).floor().isEven) {
      Artwork.aircraft(canvas, player, combat.aircraft);
    }
    if (combat.protection > 0) {
      canvas.drawCircle(
        player,
        30,
        Paint()
          ..color = const Color(0xff8fe6ff)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    for (final blast in combat.blasts) {
      final progress = blast.age / 0.55;
      final radius = (blast.large ? 55 : 28) * progress + 3;
      canvas.drawCircle(
        Offset(blast.position.x, blast.position.y),
        radius,
        Paint()
          ..color = Color.fromRGBO(255, 184, 91, 1 - progress)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * (1 - progress),
      );
    }
    if (combat.bombFlash > 0 && !profile.reducedMotion) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 360, 640),
        Paint()..color = Color.fromRGBO(171, 231, 255, combat.bombFlash * 0.8),
      );
    }
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 360, 66),
      Paint()..color = const Color(0xcc061725),
    );
    label(canvas, 'SCORE $score', const Offset(12, 10), size: 16);
    label(
      canvas,
      'LIVES ${combat.lives}   POWER ${combat.power}   STAGE ${combat.stage}',
      const Offset(12, 36),
      size: 12,
    );
    if (combat.boss != null) {
      label(
        canvas,
        combat.boss!.exposed ? 'CORE EXPOSED' : 'DESTROY BOTH TURRETS',
        const Offset(68, 72),
        size: 12,
        color: const Color(0xffffc06d),
      );
    } else if (combat.stageTime < 3) {
      label(canvas, combat.stageName, const Offset(55, 240), size: 18);
    }
    canvas.restore();
  }
}
