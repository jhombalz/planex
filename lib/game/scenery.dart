import 'package:flutter/painting.dart';

import 'sprite_art.dart';
import 'campaign.dart';

class Scenery {
  static void draw(Canvas canvas, int stage, double scroll) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 360, 640),
      Paint()..color = const Color(0xff073343),
    );
    final image = SpriteArt.backgrounds[campaign[stage - 1].background];
    if (image == null) return;
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final paint = Paint()..filterQuality = FilterQuality.low;
    final offset = scroll % 640;
    canvas.drawImageRect(
      image,
      source,
      Rect.fromLTWH(0, offset - 640, 360, 641),
      paint,
    );
    canvas.drawImageRect(
      image,
      source,
      Rect.fromLTWH(0, offset, 360, 641),
      paint,
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 360, 640),
      Paint()..color = const Color(0x18041824),
    );
  }
}
