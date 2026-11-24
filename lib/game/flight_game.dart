import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'combat_state.dart';

/// Procedural art keeps the first playable phase entirely offline.
class FlightGame extends FlameGame with DragCallbacks {
  final combat = CombatState();
  Vector2 get player => combat.player;
  bool started = false;
  bool get ended => combat.ended;
  bool active = false;
  int get score => combat.score;
  double scroll = 0;

  @override
  Future<void> onLoad() async {
    overlays.add('menu');
    pauseEngine();
  }

  void startFlight() {
    if (!started || ended) {
      combat.reset();
    }
    started = active = true;
    overlays.remove('menu');
    overlays.add('pause');
    resumeEngine();
  }

  void pauseFlight() {
    if (!active) return;
    active = false;
    pauseEngine();
    overlays.remove('pause');
    overlays.add('menu');
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!active) return;
    final scale = min(size.x / 360, size.y / 640);
    if (scale <= 0) return;
    player.add(event.localDelta / scale);
    player.x = player.x.clamp(20, 340);
    player.y = player.y.clamp(60, 616);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!active) return;
    final step = min(dt, 0.05);
    scroll = (scroll + step * 60) % 40;
    combat.update(dt);
    if (ended) pauseFlight();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final scale = min(size.x / 360, size.y / 640);
    canvas.save();
    canvas.translate((size.x - 360 * scale) / 2, (size.y - 640 * scale) / 2);
    canvas.scale(scale);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 360, 640));
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 360, 640),
      Paint()..color = const Color(0xff082c42),
    );
    final grid = Paint()
      ..color = const Color(0xff10445a)
      ..strokeWidth = 1;
    for (double y = scroll - 40; y < 640; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(360, y), grid);
    }
    for (final shot in combat.bullets.items) {
      if (!shot.active) continue;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(shot.position.x, shot.position.y),
          width: shot.owner == BulletOwner.player ? 4 : 9,
          height: shot.owner == BulletOwner.player ? 18 : 9,
        ),
        Paint()
          ..color = shot.owner == BulletOwner.player
              ? const Color(0xff79ffe1)
              : const Color(0xffffce67),
      );
    }
    for (final enemy in combat.enemies) {
      drawJet(canvas, enemy.position, switch (enemy.pattern) {
        EnemyPattern.straight => const Color(0xffff8066),
        EnemyPattern.sine => const Color(0xffd9a0ff),
        EnemyPattern.turret => const Color(0xffffce67),
      }, true);
    }
    if (combat.protection <= 0 || (combat.protection * 8).floor().isEven) {
      drawJet(canvas, player, const Color(0xff7ae6ff), false);
    }
    if (combat.protection > 0) {
      canvas.drawCircle(
        Offset(player.x, player.y),
        28,
        Paint()
          ..color = const Color(0x887ae6ff)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    final label = TextPainter(
      text: TextSpan(
        text:
            'SCORE  $score\nLIVES  ${combat.lives}    LEVEL  ${combat.difficulty}',
        style: const TextStyle(
          color: Color(0xffffffff),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, const Offset(16, 16));
    canvas.restore();
  }

  void drawJet(Canvas canvas, Vector2 position, Color color, bool reverse) {
    canvas.save();
    canvas.translate(position.x, position.y);
    if (reverse) canvas.rotate(pi);
    final path = Path()
      ..moveTo(0, -24)
      ..lineTo(7, -3)
      ..lineTo(20, 12)
      ..lineTo(7, 9)
      ..lineTo(5, 22)
      ..lineTo(-5, 22)
      ..lineTo(-7, 9)
      ..lineTo(-20, 12)
      ..lineTo(-7, -3)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawOval(
      const Rect.fromLTWH(-3, -10, 6, 14),
      Paint()..color = const Color(0xff12334b),
    );
    canvas.restore();
  }
}
