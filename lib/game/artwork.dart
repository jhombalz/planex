import 'package:flutter/material.dart';

import 'aircraft.dart';
import 'combat_state.dart';
import 'sprite_art.dart';

class Artwork {
  static void healthBar(
    Canvas canvas,
    Rect rect,
    int health,
    int maximum, {
    bool shielded = false,
  }) {
    final ratio = maximum <= 0 ? 0.0 : (health / maximum).clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(1), const Radius.circular(3)),
      Paint()..color = const Color(0xee06121e),
    );
    if (ratio > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left, rect.top, rect.width * ratio, rect.height),
          const Radius.circular(2),
        ),
        Paint()
          ..color = shielded
              ? const Color(0xff66bfff)
              : ratio < 0.3
              ? const Color(0xffff6f77)
              : const Color(0xff8effc4),
      );
    }
  }

  static void aircraft(
    Canvas canvas,
    Offset at,
    Aircraft type, {
    double rotation = 0,
    double scale = 1,
  }) {
    SpriteArt.draw(
      canvas,
      type == Aircraft.swift ? 'swift' : 'striker',
      at,
      Size((type == Aircraft.swift ? 48 : 54) * scale, 60 * scale),
      rotation: rotation,
    );
  }

  static void enemy(Canvas canvas, Offset at, EnemyPattern pattern) {
    SpriteArt.draw(
      canvas,
      switch (pattern) {
        EnemyPattern.straight => 'enemyScout',
        EnemyPattern.sine => 'enemyInterceptor',
        EnemyPattern.turret => 'enemyGunship',
      },
      at,
      Size(pattern == EnemyPattern.turret ? 54 : 48, 56),
    );
  }

  static void boss(Canvas canvas, StageBoss boss, int stage) {
    final center = Offset(boss.position.x, boss.position.y);
    SpriteArt.draw(
      canvas,
      ['bossCoral', 'bossHarbor', 'bossStorm'][stage - 1],
      center,
      const Size(214, 140),
      stretch: true,
    );
    for (final part in boss.parts) {
      final at = center + Offset(part.offsetX, 0);
      if (part.health <= 0) {
        canvas.drawOval(
          Rect.fromCenter(center: at, width: 30, height: 28),
          Paint()..color = const Color(0xdd15202a),
        );
        canvas.drawLine(
          at - const Offset(7, 6),
          at + const Offset(7, 6),
          Paint()
            ..color = const Color(0xff734536)
            ..strokeWidth = 3,
        );
      } else {
        SpriteArt.draw(
          canvas,
          part == boss.core ? 'bossCore' : 'bossTurret',
          at,
          part == boss.core ? const Size(32, 44) : const Size(28, 38),
        );
      }
    }
    if (!boss.exposed) {
      canvas.drawCircle(
        center,
        32,
        Paint()
          ..color = const Color(0xff79dafa)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }
}

class AircraftPreview extends StatelessWidget {
  const AircraftPreview(this.aircraft, {super.key});
  final Aircraft aircraft;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${aircraft.label} aircraft',
    child: SizedBox(
      width: 120,
      height: 80,
      child: CustomPaint(painter: _Preview(aircraft)),
    ),
  );
}

class _Preview extends CustomPainter {
  _Preview(this.aircraft);
  final Aircraft aircraft;
  @override
  void paint(Canvas canvas, Size size) => Artwork.aircraft(
    canvas,
    Offset(size.width / 2, size.height / 2),
    aircraft,
    scale: 1.15,
  );
  @override
  bool shouldRepaint(_Preview oldDelegate) => oldDelegate.aircraft != aircraft;
}
