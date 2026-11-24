import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'weapon.dart';

/// One decoded transparent atlas shared by gameplay, hangar and weapon controls.
class SpriteArt {
  static ui.Image? _image;
  static final Map<String, Rect> regions = {};
  static Future<void>? _loading;
  static bool get ready => _image != null;
  static Future<void> load() => _loading ??= _load();

  static Future<void> _load() async {
    final manifest = jsonDecode(
      await rootBundle.loadString('assets/images/arcade_atlas.json'),
    ) as Map<String, dynamic>;
    final data = await rootBundle.load('assets/images/arcade_atlas.png');
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    try {
      final image = (await codec.getNextFrame()).image;
      if (image.width != manifest['width'] ||
          image.height != manifest['height']) {
        image.dispose();
        throw StateError('Sprite atlas dimensions do not match its manifest.');
      }
      final entries = manifest['sprites'] as Map<String, dynamic>;
      for (final entry in entries.entries) {
        final v = (entry.value as List).cast<num>();
        final rect = Rect.fromLTWH(
          v[0].toDouble(),
          v[1].toDouble(),
          v[2].toDouble(),
          v[3].toDouble(),
        );
        if (rect.isEmpty ||
            rect.left < 0 ||
            rect.top < 0 ||
            rect.right > image.width ||
            rect.bottom > image.height) {
          image.dispose();
          throw StateError('Invalid sprite region: ${entry.key}');
        }
        regions[entry.key] = rect;
      }
      _image = image;
    } finally {
      codec.dispose();
    }
  }

  static String weaponSprite(Weapon weapon) => switch (weapon) {
    Weapon.pulse => 'pulse',
    Weapon.laser => 'laser',
    Weapon.missiles => 'missile',
    Weapon.plasma => 'plasma',
  };

  static void draw(
    Canvas canvas,
    String sprite,
    Offset center,
    Size size, {
    double rotation = 0,
    bool stretch = false,
    double opacity = 1,
  }) {
    final image = _image;
    final source = regions[sprite];
    if (image == null || source == null) return;
    final fitted = stretch
        ? size
        : applyBoxFit(BoxFit.contain, source.size, size).destination;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (rotation != 0) canvas.rotate(rotation);
    canvas.drawImageRect(
      image,
      source,
      Rect.fromCenter(
        center: Offset.zero,
        width: fitted.width,
        height: fitted.height,
      ),
      Paint()
        ..filterQuality = FilterQuality.low
        ..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    canvas.restore();
  }
}

class SpriteIcon extends StatelessWidget {
  const SpriteIcon(this.sprite, {super.key, this.size = 28});
  final String sprite;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _IconPainter(sprite)),
    ),
  );
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.sprite);
  final String sprite;
  @override
  void paint(Canvas canvas, Size size) => SpriteArt.draw(
    canvas,
    sprite,
    Offset(size.width / 2, size.height / 2),
    size,
  );
  @override
  bool shouldRepaint(_IconPainter oldDelegate) => oldDelegate.sprite != sprite;
}
