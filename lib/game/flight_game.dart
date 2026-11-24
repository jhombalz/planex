import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

/// Procedural art keeps the first playable phase entirely offline.
class FlightGame extends FlameGame with DragCallbacks {
  final player = Vector2(180, 530);
  final shots = <Vector2>[];
  final enemies = <Vector2>[];
  final random = Random();
  bool started = false;
  bool ended = false;
  bool active = false;
  int score = 0;
  double fireTime = 0;
  double waveTime = 0;
  double scroll = 0;

  @override
  Future<void> onLoad() async {
    overlays.add('menu');
    pauseEngine();
  }

  void startFlight() {
    if (!started || ended) {
      shots.clear();
      enemies.clear();
      player.setValues(180, 530);
      score = 0;
      fireTime = waveTime = 0;
    }
    started = active = true;
    ended = false;
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
    fireTime += step;
    waveTime += step;
    while (fireTime >= 0.15) {
      fireTime -= 0.15;
      shots.add(Vector2(player.x, player.y - 24));
    }
    if (waveTime >= 0.65) {
      waveTime -= 0.65;
      enemies.add(Vector2(22 + random.nextDouble() * 316, -25));
    }
    for (final shot in shots) {
      shot.y -= step * 600;
    }
    for (final enemy in enemies) {
      enemy.y += step * 130;
    }
    for (final enemy in enemies.toList()) {
      final hit = shots.indexWhere((shot) => (shot - enemy).length2 < 24 * 24);
      if (hit >= 0) {
        shots.removeAt(hit);
        enemies.remove(enemy);
        score += 100;
      } else if ((enemy - player).length2 < 20 * 20) {
        ended = true;
        pauseFlight();
        break;
      }
    }
    shots.removeWhere((shot) => shot.y < -30);
    enemies.removeWhere((enemy) => enemy.y > 680);
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
    for (final shot in shots) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(shot.x, shot.y), width: 4, height: 18),
        Paint()..color = const Color(0xff79ffe1),
      );
    }
    for (final enemy in enemies) {
      drawJet(canvas, enemy, const Color(0xffff8066), true);
    }
    drawJet(canvas, player, const Color(0xff7ae6ff), false);
    final label = TextPainter(
      text: TextSpan(
        text: 'SCORE  $score',
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
