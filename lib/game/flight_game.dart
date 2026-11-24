import 'dart:async';
import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';

import '../services/game_audio.dart';
import '../services/player_profile.dart';
import 'artwork.dart';
import 'aircraft.dart';
import 'combat_state.dart';
import 'weapon.dart';
import 'sprite_art.dart';
import 'scenery.dart';
import 'campaign.dart';

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
  double get spriteYScale =>
      size.x <= 0 || size.y <= 0 ? 1 : (size.x / 360) / (size.y / 640);
  int? _pointer;
  int _hudHash = 0;
  bool _recorded = false;
  final List<String> earnedRewards = [];

  @override
  Future<void> onLoad() async {
    if (!SpriteArt.ready) await SpriteArt.load();
    overlays.add('menu');
    pauseEngine();
    if (enableAudio) unawaited(audio.initialize());
  }

  void startFlight() {
    if (!started || ended) {
      combat.reset(selected: profile.selected, challenge: profile.mode);
      _recorded = false;
      unawaited(profile.saveCheckpoint(combat.checkpoint()));
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
    if (combat.practice) return;
    if (combat.bossRush) {
      unawaited(profile.recordBossRush(score, combat.mode));
      return;
    }
    unawaited(
      profile.recordRun(
        score,
        combat.stageCleared || combat.boss?.dying == true
            ? combat.stage
            : combat.stage - 1,
        challenge: combat.mode,
        stats: combat.stats,
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
    if (!combat.stageCleared || combat.victory && !combat.practice) return;
    if (combat.practice) {
      startPractice(combat.stage);
      return;
    }
    combat.nextStage();
    if (combat.rankedCampaign) {
      unawaited(profile.saveCheckpoint(combat.checkpoint()));
    }
    startFlight();
  }

  void startPractice(int stage) {
    combat.reset(
      selected: profile.selected,
      challenge: profile.mode,
      startStage: stage.clamp(
        1,
        min(campaign.length, profile.clearedStage + 1),
      ),
      isPractice: true,
    );
    _recorded = false;
    started = true;
    startFlight();
    combat.announce('PRACTICE · NO RECORDS');
  }

  void startBossRush() {
    if (!profile.bossRushUnlocked) return;
    combat.reset(
      selected: profile.selected,
      challenge: profile.mode,
      isBossRush: true,
    );
    combat.power = 4;
    combat.stats.maxPower = 4;
    _recorded = false;
    earnedRewards.clear();
    started = true;
    startFlight();
    combat.announce('BOSS RUSH');
  }

  void continueCheckpoint() {
    final checkpoint = profile.checkpoint;
    if (checkpoint == null) return;
    combat.restore(checkpoint);
    profile.mode = checkpoint.mode;
    unawaited(profile.save());
    _recorded = false;
    started = true;
    startFlight();
    combat.announce('CHECKPOINT RESUMED');
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
      combat.boss?.dying,
      combat.mode,
      combat.practice,
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
    if (!profile.reducedMotion) scroll = (scroll + min(dt, 0.1) * 24) % 640;
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
      earnedRewards.clear();
      if (combat.bossRush) {
        if (combat.victory) _recordRun();
      } else if (!combat.practice) {
        final previous = Set<String>.of(profile.achievements);
        final planes = Aircraft.values.where(profile.unlocked).toSet();
        final rushUnlocked = profile.bossRushUnlocked;
        unawaited(
          profile.recordStage(
            combat.stage,
            challenge: combat.mode,
            stats: combat.stats,
            medal: combat.medal,
          ),
        );
        earnedRewards.addAll(
          Achievement.values
              .where(
                (a) =>
                    !previous.contains(a.name) &&
                    profile.achievements.contains(a.name),
              )
              .map((a) => a.title),
        );
        earnedRewards.addAll(
          Aircraft.values
              .where((p) => !planes.contains(p) && profile.unlocked(p))
              .map((p) => '${p.label} UNLOCKED'),
        );
        if (!rushUnlocked && profile.bossRushUnlocked) {
          earnedRewards.add('BOSS RUSH UNLOCKED');
        }
        if (combat.victory) {
          _recordRun();
          unawaited(profile.clearCheckpoint());
        } else {
          final next = CombatState()
            ..restore(combat.checkpoint())
            ..stageCleared = true;
          next.nextStage();
          unawaited(profile.saveCheckpoint(next.checkpoint()));
        }
      }
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

  void smoke(Canvas canvas, Offset at, double age) {
    for (var i = 0; i < 3; i++) {
      final progress = profile.reducedMotion ? i / 3 : (age * 0.8 + i / 3) % 1;
      canvas.drawCircle(
        at + Offset(sin(progress * 5) * 7, -progress * 35),
        4 + progress * 10,
        Paint()..color = Color.fromRGBO(48, 51, 61, (1 - progress) * 0.55),
      );
    }
  }

  void warning(
    Canvas canvas,
    Offset at,
    double angle,
    double charge, {
    bool spread = false,
  }) {
    final paint = Paint()
      ..color = const Color(0x99ffbf68)
      ..strokeWidth = 1;
    for (final offset in spread ? [-0.18, 0.0, 0.18] : [0.0]) {
      final direction = Offset(cos(angle + offset), sin(angle + offset));
      for (var i = 0; i < 5; i++) {
        canvas.drawLine(
          at + direction * (24 + i * 17),
          at + direction * (30 + i * 17),
          paint,
        );
      }
    }
    canvas.drawCircle(
      at,
      profile.reducedMotion ? 13 : 10 + charge * 20,
      Paint()
        ..color = const Color(0xffffc46b)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0 || size.y <= 0) return;
    final inset = (topInset * 640 / size.y).clamp(0.0, 32.0);
    canvas.save();
    canvas.scale(size.x / 360, size.y / 640);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 360, 640));
    Scenery.draw(canvas, combat.stage, scroll);
    if (combat.bombFlash > 0 && !profile.reducedMotion) {
      canvas.translate(
        sin(combat.bombFlash * 120) * 3,
        cos(combat.bombFlash * 90) * 3,
      );
    }
    if (active && combat.weapon == Weapon.laser && combat.boss?.dying != true) {
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
        if (shot.kind == Weapon.spread) {
          SpriteArt.draw(
            canvas,
            'pulse',
            point,
            const Size(12, 18),
            rotation: atan2(
              shot.velocity.x * size.x / 360,
              -shot.velocity.y * size.y / 640,
            ),
            tint: const Color(0xffa4ff68),
            yScale: spriteYScale,
          );
          continue;
        }
        if (shot.kind == Weapon.missiles) {
          SpriteArt.draw(
            canvas,
            'missile',
            point,
            const Size(16, 30),
            rotation: atan2(
              shot.velocity.x * size.x / 360,
              -shot.velocity.y * size.y / 640,
            ),
            tint: Color(combat.aircraft.weaponColor),
            yScale: spriteYScale,
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
            yScale: spriteYScale,
          );
          continue;
        }
        SpriteArt.draw(
          canvas,
          'pulse',
          point,
          const Size(8, 22),
          tint: Color(combat.aircraft.weaponColor),
          yScale: spriteYScale,
        );
      } else {
        SpriteArt.draw(
          canvas,
          'enemyBullet',
          point,
          const Size(12, 12),
          yScale: spriteYScale,
        );
      }
    }
    for (final enemy in combat.enemies) {
      final at = Offset(enemy.position.x, enemy.position.y);
      if (enemy.health * 2 <= enemy.maxHealth) {
        smoke(canvas, at - const Offset(0, 15), enemy.age);
      }
      Artwork.enemy(
        canvas,
        Offset(enemy.position.x, enemy.position.y),
        enemy.pattern,
        hit: !profile.reducedMotion && enemy.hitTime > 0.065,
        yScale: spriteYScale,
        age: enemy.age,
        motion: !profile.reducedMotion,
      );
      if (enemy.charge > 0) {
        warning(
          canvas,
          at + const Offset(0, 20),
          enemy.aimAngle,
          enemy.charge,
          spread:
              enemy.pattern == EnemyPattern.turret ||
              enemy.pattern == EnemyPattern.miniboss ||
              (combat.stage >= 2 && enemy.pattern == EnemyPattern.sine),
        );
      }
      if (enemy.hitTime > 0.065 && !profile.reducedMotion) {
        canvas.drawCircle(
          at,
          8,
          Paint()
            ..color = const Color(0xffffecaa)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      Artwork.healthBar(
        canvas,
        Rect.fromLTWH(enemy.position.x - 20, enemy.position.y - 36, 40, 5),
        enemy.health,
        enemy.maxHealth,
      );
    }
    if (combat.boss != null) {
      final boss = combat.boss!;
      final at = Offset(boss.position.x, boss.position.y);
      for (final part in boss.parts) {
        if (part.health * 2 <= part.maxHealth) {
          smoke(canvas, at + Offset(part.offsetX, -20), boss.age);
        }
      }
      Artwork.boss(
        canvas,
        boss,
        combat.stage,
        flashes: !profile.reducedMotion,
        yScale: spriteYScale,
      );
      if (boss.fanCharge > 0 && !boss.dying) {
        if (combat.stage == 4 || combat.stage == 5) {
          final volley = boss.volleys + 1;
          final count = combat.stage == 4 ? 12 : 7;
          for (var i = 0; i < count; i++) {
            final origin = Offset(
              combat.stage == 5
                  ? 80 + i * 32 + (volley.isEven ? 10 : -10)
                  : at.dx + (i.isEven ? -68 : 68),
              at.dy + 28,
            );
            warning(
              canvas,
              origin,
              combat.stage == 5
                  ? pi / 2
                  : atan2(1, (i.isEven ? 1 : -1) * (0.12 + (i ~/ 2) * 0.08)),
              boss.fanCharge,
            );
          }
        } else {
          final origin =
              at +
              Offset(
                combat.stage == 2 ? ((boss.volleys + 1).isEven ? -68 : 68) : 0,
                28,
              );
          canvas.drawArc(
            Rect.fromCircle(center: origin, radius: 45),
            combat.stage == 3 || combat.stage == 6
                ? 0
                : combat.stage == 2
                ? pi * 0.2
                : pi * 0.12,
            combat.stage == 3 || combat.stage == 6
                ? pi * 2
                : combat.stage == 2
                ? pi * 0.6
                : pi * 0.76,
            false,
            Paint()
              ..color = const Color(0xffffa365)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
      }
      if (boss.aimCharge > 0 && !boss.dying) {
        for (final wing in boss.exposed ? [boss.core] : boss.wings) {
          if (wing.health <= 0) continue;
          final origin = at + Offset(wing.offsetX, 20);
          for (final spread in boss.phase >= 2 ? [-0.08, 0.08] : [0.0]) {
            warning(
              canvas,
              origin,
              atan2(boss.aimY - origin.dy, boss.aimX - origin.dx) + spread,
              boss.aimCharge,
            );
          }
        }
      }
    }
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
          yScale: spriteYScale,
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
      Artwork.aircraft(
        canvas,
        player,
        combat.aircraft,
        hit: !profile.reducedMotion && combat.playerHitTime > 0.1,
        yScale: spriteYScale,
        age: combat.elapsed,
        motion: !profile.reducedMotion,
      );
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
      final color = Color(blast.color);
      canvas.drawCircle(
        center,
        radius * 0.65,
        Paint()..color = color.withValues(alpha: (1 - progress) * 0.45),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: 1 - progress)
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
              ..color = color.withValues(alpha: 1 - progress)
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
      'LIVES ${combat.lives}  P${combat.power}  L${combat.stage}  ${combat.practice
          ? 'PRACTICE'
          : combat.bossRush
          ? 'RUSH'
          : combat.mode.label}',
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
        '${boss.name} · ${boss.dying
            ? 'DOWN'
            : boss.exposed
            ? 'EXPOSED'
            : boss.phase == 2
            ? 'ENRAGED'
            : 'SHIELDED'}',
        Offset(14, 59 + inset),
        size: 9,
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
      if (!boss.dying && (boss.fanCharge > 0 || boss.aimCharge > 0)) {
        label(
          canvas,
          boss.fanCharge > 0 ? boss.attackName : 'AIMED SHOTS',
          Offset(120, 113 + inset),
          size: 10,
          color: const Color(0xffffc46b),
        );
      }
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
    } else if (combat.bossApproaching) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(40, 145, 280, 38),
          const Radius.circular(8),
        ),
        Paint()..color = const Color(0xe03d1a25),
      );
      label(
        canvas,
        'WARNING  ·  BOSS INCOMING',
        const Offset(55, 155),
        size: 12,
        color: const Color(0xffffc16b),
      );
    } else if (combat.stageTime < 3) {
      label(canvas, combat.stageName, const Offset(55, 240), size: 18);
    }
    if (combat.noticeTime > 0) {
      final notice = TextPainter(
        text: TextSpan(
          text: combat.notice,
          style: const TextStyle(
            color: Color(0xffffe9a4),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 290);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: const Offset(180, 450),
            width: notice.width + 28,
            height: 30,
          ),
          const Radius.circular(10),
        ),
        Paint()..color = const Color(0xdd081b2c),
      );
      notice.paint(canvas, Offset(180 - notice.width / 2, 441));
    }
    canvas.restore();
  }
}
