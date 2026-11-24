# Sonic Wings-Style Vertical Shooter (Flutter + Flame)

A complete offline 2D vertical-scrolling shoot 'em up (shmup) inspired by *Sonic Wings* (*Aero Fighters*), built with **Flutter** and the **Flame** game engine.

---

## 1. Tech Stack & Packages

Add the following dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flame: ^1.18.0
  flame_audio: ^2.10.0
  shared_preferences: ^2.3.0

flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/audio/
```

---

## 2. Project Folder Structure

```text
lib/
├── main.dart                  # App entry point & HUD overlays
├── game/
│   ├── sonic_wings_game.dart  # Main FlameGame loop, collisions & wave spawner
│   └── game_state.dart        # Score, bombs, power level & offline save logic
├── components/
│   ├── player_jet.dart        # Player fighter jet, drag controls & weapon upgrades
│   ├── bullet.dart            # Player & enemy projectiles (with object pooling)
│   ├── enemy_jet.dart         # Enemy ships & movement patterns
│   ├── boss_ship.dart         # Multi-part stage boss
│   ├── powerup.dart           # 'P' (Power) and 'B' (Bomb) drops
│   └── scrolling_bg.dart      # Parallax ocean/cloud background
└── overlays/
    ├── hud_overlay.dart       # Score, lives, and Bomb button UI
    └── game_over_overlay.dart # High score display & restart button
```

---

## 3. Core Game Systems

### A. Offline Persistence (`game_state.dart`)
Uses `shared_preferences` to save high scores and unlocked planes completely offline.

```dart
import 'package:shared_preferences/shared_preferences.dart';

class GameState {
  int score = 0;
  int highScore = 0;
  int powerLevel = 1; // 1 to 4
  int bombs = 2;
  int lives = 3;

  Future<void> loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    highScore = prefs.getInt('high_score') ?? 0;
  }

  Future<void> saveHighScore() async {
    if (score > highScore) {
      highScore = score;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('high_score', highScore);
    }
  }

  void reset() {
    score = 0;
    powerLevel = 1;
    bombs = 2;
    lives = 3;
  }
}
```

### B. Player Jet & Touch Controls (`player_jet.dart`)
Uses `DragCallbacks` so the player can slide their finger anywhere on the screen without covering the jet.

```dart
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import '../game/sonic_wings_game.dart';

class PlayerJet extends SpriteComponent
    with HasGameReference<SonicWingsGame>, DragCallbacks, CollisionCallbacks {
  double _fireTimer = 0;
  final double _fireRate = 0.15; // Seconds between shots

  PlayerJet() : super(size: Vector2(48, 64), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    sprite = await game.loadSprite('player_jet.png');
    position = Vector2(game.size.x / 2, game.size.y * 0.8);
    add(RectangleHitbox(size: Vector2(24, 32), position: Vector2(12, 16)));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _fireTimer += dt;
    if (_fireTimer >= _fireRate) {
      _fireTimer = 0;
      _shoot();
    }
  }

  void _shoot() {
    final level = game.state.powerLevel;
    if (level == 1) {
      game.spawnPlayerBullet(position + Vector2(0, -30), Vector2(0, -600));
    } else if (level == 2) {
      game.spawnPlayerBullet(position + Vector2(-12, -25), Vector2(0, -600));
      game.spawnPlayerBullet(position + Vector2(12, -25), Vector2(0, -600));
    } else {
      // Spread shot for Level 3+
      game.spawnPlayerBullet(position + Vector2(0, -30), Vector2(0, -650));
      game.spawnPlayerBullet(position + Vector2(-15, -20), Vector2(-120, -620));
      game.spawnPlayerBullet(position + Vector2(15, -20), Vector2(120, -620));
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    position += event.localDelta;
    // Keep jet inside screen bounds
    position.x = position.x.clamp(size.x / 2, game.size.x - size.x / 2);
    position.y = position.y.clamp(size.y / 2, game.size.y - size.y / 2);
  }
}
```

### C. Power-Ups & Screen-Clearing Bombs
* **Power-Up (`P`):** Dropped by red squadrons; increments `state.powerLevel` up to max level 4, or grants +1,000 bonus points if already maxed.
* **Bomb (`B`):** Triggered from a Flutter HUD button overlay:
  1. Decrements `state.bombs`.
  2. Clears all active enemy bullets on screen.
  3. Deals heavy AoE damage to all active enemies and bosses.
  4. Triggers a screen-shake / flash effect.

---

## 4. Development Milestones

- [ ] **Phase 1: Core Flight & Shooting**
  - Set up `FlameGame` with vertical `ParallaxComponent` clouds/water.
  - Implement `PlayerJet` drag movement and auto-firing bullets.
- [ ] **Phase 2: Enemies & Object Pooling**
  - Create reusable bullet pools to prevent garbage collection frame drops.
  - Add enemy wave spawners (straight flyers, sine-wave jets, and stationary turrets).
- [ ] **Phase 3: Power-Ups, Bombs & Audio**
  - Add `P` and `B` pickups with collision detection.
  - Integrate `flame_audio` for laser SFX, explosions, and looping arcade BGM.
- [ ] **Phase 4: Multi-Part Stage Boss**
  - Build a boss with destructible wing turrets and a central core.
  - Add bullet-hell radial firing patterns.
- [ ] **Phase 5: Offline UI & Polish**
  - Build Flutter overlays for Title Screen, Pilot Select, HUD, and High Score table using `shared_preferences`.

---

## 5. Performance Checklist for Mobile

1. **Hitbox Forgiveness:** Make the player's hitbox smaller than the jet sprite (classic arcade bullet-hell standard) so near-misses feel fair.
2. **Off-Screen Cleanup:** Always call `removeFromParent()` when bullets or enemies leave the viewport (`y < -50` or `y > game.size.y + 50`).
3. **Sprite Atlases:** Pack bullets, explosions, and planes into a single texture atlas to minimize draw calls.
