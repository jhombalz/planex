import 'dart:math';

import 'package:flutter/material.dart';

import 'aircraft.dart';
import 'combat_state.dart';

/// Original vector sprites, rendered at logical resolution on every screen size.
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
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(rotation);
    canvas.scale(scale);
    final heavy = type == Aircraft.striker;
    final body = Path()
      ..moveTo(0, -27)
      ..lineTo(7, -7)
      ..lineTo(heavy ? 25 : 20, 10)
      ..lineTo(heavy ? 25 : 17, 17)
      ..lineTo(8, 11)
      ..lineTo(6, 23)
      ..lineTo(12, 27)
      ..lineTo(-12, 27)
      ..lineTo(-6, 23)
      ..lineTo(-8, 11)
      ..lineTo(heavy ? -25 : -17, 17)
      ..lineTo(heavy ? -25 : -20, 10)
      ..lineTo(-7, -7)
      ..close();
    canvas.drawPath(
      body.shift(const Offset(2, 4)),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = heavy ? const Color(0xffffc06d) : const Color(0xff83efff),
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xffe9ffff)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3, -16, 6, 18),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xff153753),
    );
    canvas.drawRect(
      const Rect.fromLTWH(-2, 6, 4, 14),
      Paint()..color = const Color(0xff39677f),
    );
    for (final x in [-6.0, 6.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 28), width: 5, height: 12),
        Paint()..color = const Color(0xff6cbcff),
      );
    }
    canvas.restore();
  }

  static void enemy(Canvas canvas, Offset at, EnemyPattern pattern) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    final color = switch (pattern) {
      EnemyPattern.straight => const Color(0xffff8066),
      EnemyPattern.sine => const Color(0xffd9a0ff),
      EnemyPattern.turret => const Color(0xffe6b16a),
    };
    if (pattern == EnemyPattern.turret) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-22, -25, 44, 50),
          const Radius.circular(12),
        ),
        Paint()..color = const Color(0xff364653),
      );
      canvas.drawCircle(Offset.zero, 17, Paint()..color = color);
      canvas.drawRect(
        const Rect.fromLTWH(-4, 0, 8, 28),
        Paint()..color = const Color(0xffb3ccd1),
      );
    } else {
      canvas.rotate(pi);
      final path = Path()
        ..moveTo(0, -23)
        ..lineTo(9, -2)
        ..lineTo(22, 16)
        ..lineTo(5, 10)
        ..lineTo(0, 21)
        ..lineTo(-5, 10)
        ..lineTo(-22, 16)
        ..lineTo(-9, -2)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawRect(
        const Rect.fromLTWH(-3, -10, 6, 12),
        Paint()..color = const Color(0xff342f48),
      );
    }
    canvas.restore();
  }

  static void boss(Canvas canvas, StageBoss boss) {
    canvas.save();
    canvas.translate(boss.position.x, boss.position.y);
    final hull = Path()
      ..moveTo(-100, -20)
      ..lineTo(-28, -40)
      ..lineTo(28, -40)
      ..lineTo(100, -20)
      ..lineTo(105, 22)
      ..lineTo(30, 16)
      ..lineTo(20, 38)
      ..lineTo(-20, 38)
      ..lineTo(-30, 16)
      ..lineTo(-105, 22)
      ..close();
    canvas.drawPath(hull, Paint()..color = const Color(0xff33485e));
    canvas.drawPath(
      hull,
      Paint()
        ..color = const Color(0xffa6b7c5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final part in boss.parts) {
      final core = part == boss.core;
      final rect = Rect.fromCenter(
        center: Offset(part.offsetX, 0),
        width: core ? 48 : 36,
        height: 48,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(7)),
        Paint()
          ..color = part.health <= 0
              ? const Color(0xff142230)
              : core
              ? const Color(0xfff0758e)
              : const Color(0xffffc06d),
      );
      if (part.health > 0) {
        canvas.drawRect(
          Rect.fromLTWH(part.offsetX - 17, -34, 34, 4),
          Paint()..color = const Color(0xff142230),
        );
        canvas.drawRect(
          Rect.fromLTWH(
            part.offsetX - 17,
            -34,
            34 * part.health / part.maxHealth,
            4,
          ),
          Paint()..color = const Color(0xff8effc4),
        );
      }
    }
    if (!boss.exposed) {
      canvas.drawCircle(
        Offset.zero,
        34,
        Paint()
          ..color = const Color(0xff79dafa)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
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
