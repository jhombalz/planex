import 'dart:math';

import 'package:flutter/material.dart';

enum GameAction { play, pause, next, home, retry, practice, resume, help }

class ArcadeGlyph extends StatelessWidget {
  const ArcadeGlyph(this.action, {super.key, this.size = 28});
  final GameAction action;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _Glyph(action)),
    ),
  );
}

class _Glyph extends CustomPainter {
  _Glyph(this.action);
  final GameAction action;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    final line = Paint()
      ..color = const Color(0xff72e8ec)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = const Color(0xffffcf78);
    final frame = Path()
      ..moveTo(8, 1)
      ..lineTo(24, 1)
      ..lineTo(31, 8)
      ..lineTo(31, 24)
      ..lineTo(24, 31)
      ..lineTo(8, 31)
      ..lineTo(1, 24)
      ..lineTo(1, 8)
      ..close();
    canvas.drawPath(frame, line);
    switch (action) {
      case GameAction.play:
        canvas.drawPath(
          Path()
            ..moveTo(12, 8)
            ..lineTo(24, 16)
            ..lineTo(12, 24)
            ..close(),
          fill,
        );
      case GameAction.pause:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(10, 8, 4, 16),
            const Radius.circular(1),
          ),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(18, 8, 4, 16),
            const Radius.circular(1),
          ),
          fill,
        );
      case GameAction.next:
        for (final x in [8.0, 16.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(x, 8)
              ..lineTo(x + 8, 16)
              ..lineTo(x, 24),
            line
              ..color = const Color(0xffffcf78)
              ..strokeWidth = 3,
          );
        }
      case GameAction.home:
        canvas.drawPath(
          Path()
            ..moveTo(7, 15)
            ..lineTo(16, 7)
            ..lineTo(25, 15)
            ..lineTo(25, 25)
            ..lineTo(20, 25)
            ..lineTo(20, 17)
            ..lineTo(12, 17)
            ..lineTo(12, 25)
            ..lineTo(7, 25)
            ..close(),
          line..color = const Color(0xffffcf78),
        );
      case GameAction.retry:
        canvas.drawArc(
          const Rect.fromLTWH(8, 8, 16, 16),
          -pi / 3,
          pi * 1.7,
          false,
          line
            ..color = const Color(0xffffcf78)
            ..strokeWidth = 2.5,
        );
        canvas.drawPath(
          Path()
            ..moveTo(20, 5)
            ..lineTo(26, 9)
            ..lineTo(19, 12)
            ..close(),
          fill,
        );
      case GameAction.practice:
        canvas.drawCircle(const Offset(16, 16), 7, line);
        for (final p in [
          const Offset(16, 5),
          const Offset(16, 27),
          const Offset(5, 16),
          const Offset(27, 16),
        ]) {
          canvas.drawLine(
            p,
            Offset(16 + (p.dx - 16) * 0.55, 16 + (p.dy - 16) * 0.55),
            line,
          );
        }
        canvas.drawCircle(const Offset(16, 16), 2, fill);
      case GameAction.resume:
        canvas.drawLine(const Offset(8, 24), const Offset(24, 24), line);
        canvas.drawPath(
          Path()
            ..moveTo(16, 7)
            ..lineTo(23, 15)
            ..lineTo(19, 15)
            ..lineTo(19, 21)
            ..lineTo(13, 21)
            ..lineTo(13, 15)
            ..lineTo(9, 15)
            ..close(),
          fill,
        );
      case GameAction.help:
        final text = TextPainter(
          text: const TextSpan(
            text: '?',
            style: TextStyle(
              color: Color(0xffffcf78),
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, Offset(16 - text.width / 2, 3));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Glyph oldDelegate) => oldDelegate.action != action;
}
