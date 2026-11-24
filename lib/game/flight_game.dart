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
import 'sprite_art.dart';

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
  double topInset = 0;
  int? _pointer;
  int _hudHash = 0;
  bool _recorded = false;

  @override
  Future<void> onLoad() async {
    if (!SpriteArt.ready) await SpriteArt.load();
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

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (active && _pointer == null) _pointer = event.pointerId;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!active || event.pointerId != _pointer) return;
    if (size.x <= 0 || size.y <= 0) return;
    combat.player.add(
      Vector2(
            event.localDelta.x * 360 / size.x,
            event.localDelta.y * 640 / size.y,
          ) *
          profile.sensitivity *
          combat.aircraft.handling,
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
      combat.bonusTime.ceil(),
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
    if (size.x <= 0 || size.y <= 0) return;
    final inset = (topInset * 640 / size.y).clamp(0.0, 32.0);
    canvas.save();
    canvas.scale(size.x / 360, size.y / 640);
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
      for (final offset in combat.laserOffsets) {
        final beamX = combat.player.x + offset;
        final target = combat.boss;
        final blocked =
            target != null &&
            !target.exposed &&
            (beamX - target.position.x).abs() < 30 &&
            target.position.y < combat.player.y;
        final top = blocked ? target.position.y + 30 : 66.0;
        final start = Offset(beamX, combat.player.y - 25);
        final end = Offset(beamX, top);
        SpriteArt.draw(
          canvas,
          'laser',
          (start + end) / 2,
          Size(combat.laserWidth + 8, (start.dy - end.dy).abs()),
          stretch: true,
          tint: Color(combat.aircraft.weaponColor),
        );
      }
    }
    for (final shot in combat.bullets.items) {
      if (!shot.active) continue;
      final point = Offset(shot.position.x, shot.position.y);
      if (shot.owner == BulletOwner.player) {
        if (shot.kind == Weapon.missiles) {
          SpriteArt.draw(
            canvas,
            'missile',
            point,
            const Size(16, 30),
            rotation: atan2(shot.velocity.x, -shot.velocity.y),
            tint: Color(combat.aircraft.weaponColor),
          );
          continue;
        }
        if (shot.kind == Weapon.plasma) {
          SpriteArt.draw(
            canvas,
            'plasma',
            point,
            const Size(22, 22),
            tint: Color(combat.aircraft.weaponColor),
          );
          continue;
        }
        SpriteArt.draw(
          canvas,
          'pulse',
          point,
          const Size(8, 22),
          tint: Color(combat.aircraft.weaponColor),
        );
      } else {
        SpriteArt.draw(canvas, 'enemyBullet', point, const Size(12, 12));
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
    if (combat.boss != null) Artwork.boss(canvas, combat.boss!, combat.stage);
    for (final pickup in combat.pickups) {
      final point = Offset(pickup.position.x, pickup.position.y);
      if (pickup.kind == PickupKind.bonus) {
        canvas.drawCircle(point, 18, Paint()..color = const Color(0xdd253f6a));
        canvas.drawCircle(
          point,
          18,
          Paint()
            ..color = const Color(0xffffd16a)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        SpriteArt.draw(
          canvas,
          SpriteArt.weaponSprite(pickup.weapon!),
          point,
          const Size(24, 28),
        );
        continue;
      }
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
      Rect.fromLTWH(0, 0, 360, 52 + inset),
      Paint()..color = const Color(0xcc061725),
    );
    label(canvas, 'SCORE $score', Offset(12, 8 + inset), size: 16);
    label(
      canvas,
      'LIVES ${combat.lives}   POWER ${combat.power}   STAGE ${combat.stage}',
      Offset(12, 30 + inset),
      size: 12,
    );
    if (combat.boss != null) {
      final boss = combat.boss!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(6, 54 + inset, 348, 54),
          const Radius.circular(8),
        ),
        Paint()..color = const Color(0xee091522),
      );
      label(
        canvas,
        'BOSS ${combat.stage}  ${boss.exposed ? (boss.core.health < boss.core.maxHealth / 2 ? 'ENRAGED' : 'CORE EXPOSED') : 'CORE SHIELDED'}',
        Offset(14, 59 + inset),
        size: 10,
        color: const Color(0xffffc06d),
      );
      Artwork.healthBar(
        canvas,
        Rect.fromLTWH(14, 78 + inset, 332, 10),
        boss.core.health,
        boss.core.maxHealth,
        shielded: !boss.exposed,
      );
      label(
        canvas,
        '${(boss.core.health * 100 / boss.core.maxHealth).ceil()}%',
        Offset(306, 59 + inset),
        size: 10,
      );
      final parts = boss.wings;
      for (var i = 0; i < 2; i++) {
        final part = parts[i];
        final x = 14 + i * 178.0;
        SpriteArt.draw(
          canvas,
          'bossTurret',
          Offset(x + 5, 99 + inset),
          const Size(10, 13),
          opacity: part.health <= 0 ? 0.25 : 1,
        );
        label(
          canvas,
          part.health <= 0 ? 'DESTROYED' : '${part.health}/${part.maxHealth}',
          Offset(x + 18, 91 + inset),
          size: 8,
        );
        Artwork.healthBar(
          canvas,
          Rect.fromLTWH(x + 65, 95 + inset, 88, 5),
          part.health,
          part.maxHealth,
        );
      }
    } else if (combat.stageTime < 3) {
      label(canvas, combat.stageName, const Offset(55, 240), size: 18);
    }
    canvas.restore();
  }
}
