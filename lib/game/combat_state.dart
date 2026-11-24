import 'dart:math';

import 'package:flame/game.dart';

enum BulletOwner { player, enemy }

enum EnemyPattern { straight, sine, turret }

class Bullet {
  final position = Vector2.zero();
  final velocity = Vector2.zero();
  BulletOwner owner = BulletOwner.player;
  bool active = false;
}

/// Fixed capacity: combat never allocates a projectile during an update.
class BulletPool {
  BulletPool(int capacity) : items = List.generate(capacity, (_) => Bullet());
  final List<Bullet> items;

  Bullet? spawn(double x, double y, double vx, double vy, BulletOwner owner) {
    for (final bullet in items) {
      if (bullet.active) continue;
      bullet.position.setValues(x, y);
      bullet.velocity.setValues(vx, vy);
      bullet.owner = owner;
      bullet.active = true;
      return bullet;
    }
    return null;
  }

  void clear() {
    for (final bullet in items) {
      bullet.active = false;
    }
  }
}

class Enemy {
  Enemy(double x, double y, this.pattern, this.speed)
    : originX = x,
      position = Vector2(x, y);
  final Vector2 position;
  final EnemyPattern pattern;
  final double originX;
  final double speed;
  double age = 0;
  double fireTime = 0;
  int health = 2;
}

class CombatState {
  CombatState({Random? random}) : random = random ?? Random();
  final Random random;
  final player = Vector2(180, 530);
  final bullets = BulletPool(192);
  final enemies = <Enemy>[];
  int score = 0;
  int lives = 3;
  int wave = 0;
  double elapsed = 0;
  double protection = 2;
  double fireTime = 0;
  double waveTime = 0;
  bool ended = false;
  int get difficulty => min(6, 1 + elapsed ~/ 25);

  void reset() {
    player.setValues(180, 530);
    bullets.clear();
    enemies.clear();
    score = wave = 0;
    lives = 3;
    elapsed = fireTime = waveTime = 0;
    protection = 2;
    ended = false;
  }

  void update(double dt) {
    // Substeps keep fast projectiles from skipping through small hitboxes.
    var remaining = dt.clamp(0.0, 0.1);
    while (remaining > 0 && !ended) {
      final step = min(remaining, 1 / 120);
      _step(step);
      remaining -= step;
    }
  }

  void _step(double dt) {
    elapsed += dt;
    protection = max(0, protection - dt);
    fireTime += dt;
    waveTime += dt;
    if (fireTime >= 0.15) {
      fireTime -= 0.15;
      bullets.spawn(player.x, player.y - 25, 0, -600, BulletOwner.player);
    }
    if (waveTime >= max(1.5, 3.2 - difficulty * 0.22)) {
      waveTime = 0;
      spawnWave();
    }
    for (final enemy in enemies) {
      enemy.age += dt;
      if (enemy.pattern == EnemyPattern.turret &&
          enemy.position.y >= 120 &&
          enemy.age < 7) {
        enemy.position.y = 120;
      } else {
        enemy.position.y += enemy.speed * dt;
      }
      if (enemy.pattern == EnemyPattern.sine) {
        enemy.position.x = enemy.originX + sin(enemy.age * 2.6) * 35;
      }
      enemy.fireTime += dt;
      if (enemy.position.y > 20 &&
          enemy.position.y < 480 &&
          enemy.fireTime >= max(0.65, 2.3 - difficulty * 0.2)) {
        enemy.fireTime = 0;
        final dx = player.x - enemy.position.x;
        final dy = player.y - enemy.position.y;
        final length = sqrt(dx * dx + dy * dy);
        final speed = 130 + difficulty * 15;
        bullets.spawn(
          enemy.position.x,
          enemy.position.y + 20,
          length > 0 ? dx / length * speed : 0,
          length > 0 ? dy / length * speed : speed.toDouble(),
          BulletOwner.enemy,
        );
      }
    }
    for (final bullet in bullets.items) {
      if (!bullet.active) continue;
      bullet.position.x += bullet.velocity.x * dt;
      bullet.position.y += bullet.velocity.y * dt;
      if (bullet.position.x < -30 ||
          bullet.position.x > 390 ||
          bullet.position.y < -40 ||
          bullet.position.y > 680) {
        bullet.active = false;
        continue;
      }
      if (bullet.owner == BulletOwner.player) {
        for (final enemy in enemies) {
          if (enemy.health <= 0) continue;
          if (_near(bullet.position, enemy.position, 23)) {
            bullet.active = false;
            enemy.health--;
            if (enemy.health == 0) {
              score += enemy.pattern == EnemyPattern.turret ? 250 : 100;
            }
            break;
          }
        }
      } else if (_near(bullet.position, player, 10)) {
        bullet.active = false;
        damagePlayer();
      }
    }
    for (final enemy in enemies) {
      if (enemy.health > 0 && _near(enemy.position, player, 22)) {
        damagePlayer();
      }
    }
    enemies.removeWhere((enemy) => enemy.health <= 0 || enemy.position.y > 680);
  }

  bool _near(Vector2 a, Vector2 b, double radius) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return dx * dx + dy * dy <= radius * radius;
  }

  void damagePlayer() {
    if (protection > 0 || ended) return;
    lives--;
    if (lives == 0) {
      ended = true;
      return;
    }
    player.setValues(180, 530);
    protection = 2;
    for (final bullet in bullets.items) {
      if (bullet.owner == BulletOwner.enemy) bullet.active = false;
    }
  }

  void spawnWave() {
    final pattern = EnemyPattern.values[wave % EnemyPattern.values.length];
    wave++;
    final count = pattern == EnemyPattern.turret ? 2 : min(5, 2 + difficulty);
    final offset = random.nextDouble() * 16 - 8;
    for (var i = 0; i < count && enemies.length < 32; i++) {
      enemies.add(
        Enemy(
          50 + i * 260 / max(1, count - 1) + offset,
          -30 - i * 35,
          pattern,
          85 + difficulty * 12.0,
        )..health = pattern == EnemyPattern.turret ? 5 : 2,
      );
    }
  }
}
