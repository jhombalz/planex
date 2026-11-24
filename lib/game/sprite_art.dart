import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'weapon.dart';
import 'campaign.dart';

/// One decoded transparent atlas shared by gameplay, hangar and weapon controls.
class SpriteArt {
  static ui.Image? _image;
  static final Map<String, ui.Image> _sheets = {};
  static final Map<String, Rect> regions = {};
  static final Map<String, ui.Image> backgrounds = {};
  static Future<void>? _loading;
  static final Map<(int?, int, int), Paint> _paints = {};
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
      final extraManifest = jsonDecode(
        await rootBundle.loadString('assets/images/expansion_atlas.json'),
      ) as Map<String, dynamic>;
      final extraBytes = await rootBundle.load(
        'assets/images/expansion_atlas.png',
      );
      final extraCodec = await ui.instantiateImageCodec(
        extraBytes.buffer.asUint8List(),
      );
      try {
        final extra = (await extraCodec.getNextFrame()).image;
        if (extra.width != extraManifest['width'] ||
            extra.height != extraManifest['height']) {
          throw StateError('Expansion sprite dimensions mismatch');
        }
        for (final entry
            in (extraManifest['sprites'] as Map<String, dynamic>).entries) {
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
              rect.right > extra.width ||
              rect.bottom > extra.height) {
            throw StateError('Invalid expansion region');
          }
          regions[entry.key] = rect;
          _sheets[entry.key] = extra;
        }
      } finally {
        extraCodec.dispose();
      }
      for (final name in campaign.map((level) => level.background)) {
        final bytes = await rootBundle.load(
          'assets/images/background_$name.png',
        );
        final backgroundCodec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          targetWidth: 512,
        );
        try {
          backgrounds[name] = (await backgroundCodec.getNextFrame()).image;
        } finally {
          backgroundCodec.dispose();
        }
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
    Weapon.spread => 'spread',
  };

  static void draw(
    Canvas canvas,
    String sprite,
    Offset center,
    Size size, {
    double rotation = 0,
    bool stretch = false,
    double opacity = 1,
    Color? tint,
    double tintStrength = 0.55,
    double yScale = 1,
  }) {
    if (sprite == 'spread') {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1, yScale);
      canvas.rotate(rotation);
      for (final side in [-1.0, 0.0, 1.0]) {
        draw(
          canvas,
          'pulse',
          Offset(side * size.width * 0.25, 0),
          Size(size.width * 0.3, size.height * 0.85),
          rotation: side * 0.45,
          tint: const Color(0xffa4ff68),
          tintStrength: 0.85,
          opacity: opacity,
        );
      }
      canvas.restore();
      return;
    }
    final image = _sheets[sprite] ?? _image;
    final source = regions[sprite];
    if (image == null || source == null) return;
    final fitted = stretch
        ? size
        : applyBoxFit(BoxFit.contain, source.size, size).destination;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1, yScale);
    if (rotation != 0) canvas.rotate(rotation);
    canvas.drawImageRect(
      image,
      source,
      Rect.fromCenter(
        center: Offset.zero,
        width: fitted.width,
        height: fitted.height,
      ),
      _paint(tint, opacity, tintStrength),
    );
    canvas.restore();
  }

  static Paint _paint(Color? tint, double opacity, double strength) {
    final key = (
      tint?.toARGB32(),
      (opacity * 255).round().clamp(0, 255),
      (strength * 255).round().clamp(0, 255),
    );
    final cached = _paints[key];
    if (cached != null) return cached;
    if (_paints.length >= 64) _paints.clear();
    final paint = Paint()
      ..filterQuality = FilterQuality.low
      ..colorFilter = tint == null
          ? null
          : ColorFilter.mode(
              tint.withValues(alpha: strength),
              BlendMode.srcATop,
            )
      ..color = Color.fromARGB(key.$2, 255, 255, 255);
    _paints[key] = paint;
    return paint;
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
