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
import 'weapon.dart';

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
      combat.reset(
        selected: profile.selected,
        unlocked: profile.clearedStage,
        selectedWeapon: profile.selectedWeapon,
      );
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
    // Debrief/menu sounds must stop on app interruptions too.
    audio.silence();
    _pointer = null;
    if (!active) return;
    active = false;
    pauseEngine();
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

  void cycleWeapon() {
    if (!active) return;
    combat.cycleWeapon();
    unawaited(profile.selectWeapon(combat.weapon));
    refreshHud();
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
      combat.weapon,
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
    if (active && combat.weapon == Weapon.laser) {
      final target = combat.boss;
      final blocked =
          target != null &&
          !target.exposed &&
          (combat.player.x - target.position.x).abs() < 30 &&
          target.position.y < combat.player.y;
      final top = blocked ? target.position.y + 30 : 66.0;
      final start = Offset(combat.player.x, combat.player.y - 25);
      final end = Offset(combat.player.x, top);
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = const Color(0x5545dcff)
          ..strokeWidth = combat.laserWidth + 10,
      );
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = const Color(0xff65e7ff)
          ..strokeWidth = combat.laserWidth,
      );
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = const Color(0xffe6ffff)
          ..strokeWidth = 3,
      );
    }
    for (final shot in combat.bullets.items) {
      if (!shot.active) continue;
      final point = Offset(shot.position.x, shot.position.y);
      if (shot.owner == BulletOwner.player) {
        if (shot.kind == Weapon.missiles) {
          canvas.save();
          canvas.translate(point.dx, point.dy);
          canvas.rotate(atan2(shot.velocity.x, -shot.velocity.y));
          canvas.drawOval(
            const Rect.fromLTWH(-3, 5, 6, 15),
            Paint()..color = const Color(0xffff9c40),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-4, -10, 8, 19),
              const Radius.circular(4),
            ),
            Paint()..color = const Color(0xffeff2f4),
          );
          canvas.drawRect(
            const Rect.fromLTWH(-6, 4, 12, 4),
            Paint()..color = const Color(0xffed727d),
          );
          canvas.restore();
          continue;
        }
        if (shot.kind == Weapon.plasma) {
          canvas.drawCircle(
            point,
            11,
            Paint()..color = const Color(0x6655ffaa),
          );
          canvas.drawCircle(point, 7, Paint()..color = const Color(0xff73ffbc));
          canvas.drawCircle(point, 3, Paint()..color = const Color(0xffeffff5));
          continue;
        }
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
      Artwork.healthBar(
        canvas,
        Rect.fromLTWH(enemy.position.x - 20, enemy.position.y - 36, 40, 5),
        enemy.health,
        enemy.maxHealth,
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
      if (blast.age < blast.delay) continue;
      final progress = ((blast.age - blast.delay) / blast.duration).clamp(
        0.0,
        1.0,
      );
      final radius = (blast.large ? 55 : 28) * progress + 3;
      final center = Offset(blast.position.x, blast.position.y);
      canvas.drawCircle(
        center,
        radius * 0.65,
        Paint()..color = Color.fromRGBO(255, 116, 40, (1 - progress) * 0.45),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Color.fromRGBO(255, 184, 91, 1 - progress)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * (1 - progress),
      );
      if (!profile.reducedMotion) {
        for (var i = 0; i < 10; i++) {
          final angle = i * pi / 5;
          final offset = Offset(cos(angle), sin(angle));
          canvas.drawLine(
            center + offset * radius * 0.7,
            center + offset * radius * 1.25,
            Paint()
              ..color = Color.fromRGBO(255, 222, 129, 1 - progress)
              ..strokeWidth = 2,
          );
        }
      }
    }
    for (final wave in combat.bombWaves) {
      final center = Offset(wave.position.x, wave.position.y);
      final radius = profile.reducedMotion ? 90.0 : 30 + wave.age * 750;
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(
          center,
          max(0.0, radius - i * 22),
          Paint()
            ..color = Color.fromRGBO(
              255,
              203 - i * 30,
              111,
              (1 - wave.age) * (0.8 - i * 0.2),
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7 - i * 2.0,
        );
      }
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
      final boss = combat.boss!;
      final totalHealth = boss.parts.fold(0, (value, p) => value + p.health);
      final maxHealth = boss.parts.fold(0, (value, p) => value + p.maxHealth);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(6, 68, 348, 68),
          const Radius.circular(8),
        ),
        Paint()..color = const Color(0xee091522),
      );
      label(
        canvas,
        'BOSS ${combat.stage}  ${boss.exposed ? (boss.core.health < boss.core.maxHealth / 2 ? 'ENRAGED' : 'CORE EXPOSED') : 'DESTROY TURRETS'}',
        const Offset(14, 73),
        size: 11,
        color: const Color(0xffffc06d),
      );
      Artwork.healthBar(
        canvas,
        const Rect.fromLTWH(14, 91, 332, 8),
        totalHealth,
        maxHealth,
      );
      final parts = [boss.wings.first, boss.core, boss.wings.last];
      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];
        final x = 14 + i * 112.0;
        final name = ['LEFT', 'CORE', 'RIGHT'][i];
        label(
          canvas,
          '$name ${part.health <= 0 ? 'DOWN' : '${part.health}/${part.maxHealth}'}',
          Offset(x, 105),
          size: 9,
        );
        Artwork.healthBar(
          canvas,
          Rect.fromLTWH(x, 123, 102, 4),
          part.health,
          part.maxHealth,
          shielded: i == 1 && !boss.exposed,
        );
      }
    } else if (combat.stageTime < 3) {
      label(canvas, combat.stageName, const Offset(55, 240), size: 18);
    }
    canvas.restore();
  }
}
