import 'dart:math';

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
    bool hit = false,
    double yScale = 1,
    double age = 0,
    bool motion = true,
  }) {
    SpriteArt.draw(
      canvas,
      type == Aircraft.swift ? 'swift' : 'striker',
      at,
      Size((type == Aircraft.swift ? 48 : 54) * scale, 60 * scale),
      rotation: rotation,
      tint: hit ? Colors.white : null,
      tintStrength: 0.85,
      yScale: yScale,
    );
    if (type == Aircraft.striker) {
      for (final x in [-13.0, 13.0]) {
        propeller(
          canvas,
          at + Offset(x * scale, -18 * scale * yScale),
          age,
          yScale: yScale,
          motion: motion,
        );
      }
    }
  }

  static void enemy(
    Canvas canvas,
    Offset at,
    EnemyPattern pattern, {
    bool hit = false,
    double yScale = 1,
    double age = 0,
    bool motion = true,
  }) {
    SpriteArt.draw(
      canvas,
      switch (pattern) {
        EnemyPattern.straight => 'enemyScout',
        EnemyPattern.sine => 'enemyInterceptor',
        EnemyPattern.turret => 'enemyGunship',
      },
      at,
      Size(pattern == EnemyPattern.turret ? 54 : 48, 56),
      tint: hit ? Colors.white : null,
      tintStrength: 0.85,
      yScale: yScale,
    );
    if (pattern == EnemyPattern.straight) {
      propeller(
        canvas,
        at + Offset(0, 22 * yScale),
        age,
        yScale: yScale,
        motion: motion,
      );
    }
    if (pattern == EnemyPattern.turret) {
      for (final x in [-14.0, 14.0]) {
        propeller(
          canvas,
          at + Offset(x, 12 * yScale),
          age,
          yScale: yScale,
          motion: motion,
        );
      }
    }
  }

  static void boss(
    Canvas canvas,
    StageBoss boss,
    int stage, {
    bool flashes = true,
    double yScale = 1,
  }) {
    final center = Offset(boss.position.x, boss.position.y);
    SpriteArt.draw(
      canvas,
      ['bossCoral', 'bossHarbor', 'bossStorm'][stage - 1],
      center,
      const Size(214, 140),
      stretch: true,
      tint: flashes && boss.core.hitTime > 0.065 ? Colors.white : null,
      tintStrength: 0.7,
      opacity: boss.dying ? (1 - boss.deathTime / 1.4 * 0.8).clamp(0.1, 1) : 1,
      rotation: boss.dying && stage == 2 && flashes ? boss.deathTime * 0.1 : 0,
      yScale: yScale,
    );
    if (!boss.dying) {
      for (final x in [-72.0, -36.0, 36.0, 72.0]) {
        propeller(
          canvas,
          center + Offset(x, 28 * yScale),
          boss.age,
          yScale: yScale,
          motion: flashes,
        );
      }
    }
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
          tint: flashes && part.hitTime > 0.065 ? Colors.white : null,
          tintStrength: 0.85,
          yScale: yScale,
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

  static void propeller(
    Canvas canvas,
    Offset at,
    double age, {
    double yScale = 1,
    bool motion = true,
  }) {
    final angle = motion ? age * 70 : 0.0;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(1, yScale);
    canvas.drawOval(
      const Rect.fromLTWH(-8, -2, 16, 4),
      Paint()..color = const Color(0x2279dce9),
    );
    canvas.drawLine(
      Offset(-8 * cos(angle), -2 * sin(angle)),
      Offset(8 * cos(angle), 2 * sin(angle)),
      Paint()
        ..color = const Color(0x99e0e9e7)
        ..strokeWidth = 1.2,
    );
    canvas.restore();
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
