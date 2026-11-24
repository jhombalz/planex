import 'dart:math';

import 'package:flame/game.dart';

import 'aircraft.dart';
import 'weapon.dart';

enum BulletOwner { player, enemy }

enum EnemyPattern { straight, sine, turret }

enum PickupKind { power, bomb }

enum CombatSound { shot, explosion, pickup, bomb, clear }

class Pickup {
  Pickup(double x, double y, this.kind) : position = Vector2(x, y);
  final Vector2 position;
  final PickupKind kind;
}

class Blast {
  Blast(double x, double y, {this.large = false, this.delay = 0})
    : position = Vector2(x, y);
  final Vector2 position;
  final bool large;
  final double delay;
  double get duration => large ? 0.8 : 0.55;
  double age = 0;
}

class BombWave {
  BombWave(double x, double y) : position = Vector2(x, y);
  final Vector2 position;
  double age = 0;
}

class BossPart {
  BossPart(this.offsetX, this.maxHealth) : health = maxHealth;
  final double offsetX;
  final int maxHealth;
  int health;
}

class StageBoss {
  StageBoss(int stage)
    : core = BossPart(0, 140 + stage * 55),
      wings = [BossPart(-68, 35 + stage * 14), BossPart(68, 35 + stage * 14)];
  final position = Vector2(180, -90);
  final BossPart core;
  final List<BossPart> wings;
  double age = 0;
  double radialTime = 0;
  double aimedTime = 0;
  bool get exposed => wings.every((part) => part.health <= 0);
  late final List<BossPart> parts = List.unmodifiable([...wings, core]);
}

/// Authored encounter times within each 45-second approach.
const stageWaves = <List<(double, EnemyPattern)>>[
  [
    (2, EnemyPattern.straight),
    (7, EnemyPattern.sine),
    (12, EnemyPattern.straight),
    (18, EnemyPattern.turret),
    (24, EnemyPattern.sine),
    (31, EnemyPattern.straight),
    (37, EnemyPattern.sine),
    (41, EnemyPattern.straight),
  ],
  [
    (2, EnemyPattern.sine),
    (6, EnemyPattern.turret),
    (9, EnemyPattern.sine),
    (12, EnemyPattern.straight),
    (17, EnemyPattern.sine),
    (23, EnemyPattern.turret),
    (29, EnemyPattern.sine),
    (36, EnemyPattern.straight),
    (40, EnemyPattern.turret),
  ],
  [
    (2, EnemyPattern.turret),
    (6, EnemyPattern.sine),
    (8, EnemyPattern.straight),
    (11, EnemyPattern.straight),
    (16, EnemyPattern.turret),
    (19, EnemyPattern.sine),
    (22, EnemyPattern.sine),
    (28, EnemyPattern.straight),
    (31, EnemyPattern.sine),
    (35, EnemyPattern.turret),
    (39, EnemyPattern.straight),
  ],
];

class Bullet {
  final position = Vector2.zero();
  final velocity = Vector2.zero();
  BulletOwner owner = BulletOwner.player;
  bool active = false;
  Weapon kind = Weapon.pulse;
  int damage = 1;
}

/// Fixed capacity: combat never allocates a projectile during an update.
class BulletPool {
  BulletPool(int capacity) : items = List.generate(capacity, (_) => Bullet());
  final List<Bullet> items;

  Bullet? spawn(
    double x,
    double y,
    double vx,
    double vy,
    BulletOwner owner, {
    Weapon kind = Weapon.pulse,
    int damage = 1,
  }) {
    for (final bullet in items) {
      if (bullet.active) continue;
      bullet.position.setValues(x, y);
      bullet.velocity.setValues(vx, vy);
      bullet.owner = owner;
      bullet.kind = kind;
      bullet.damage = damage;
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
  Enemy(double x, double y, this.pattern, this.speed, {int health = 2})
    : originX = x,
      maxHealth = health,
      health = health,
      position = Vector2(x, y);
  final Vector2 position;
  final EnemyPattern pattern;
  final double originX;
  final double speed;
  double age = 0;
  double fireTime = 0;
  final int maxHealth;
  int health;
}

class CombatState {
  CombatState({Random? random}) : random = random ?? Random();
  final Random random;
  final player = Vector2(180, 530);
  final bullets = BulletPool(192);
  final enemies = <Enemy>[];
  final pickups = <Pickup>[];
  final blasts = <Blast>[];
  final bombWaves = <BombWave>[];
  final sounds = <CombatSound>{};
  Aircraft aircraft = Aircraft.swift;
  Weapon weapon = Weapon.pulse;
  int unlockedStage = 0;
  double laserTime = 0;
  double get laserWidth => 5 + power * 2.0;
  List<Weapon> get availableWeapons => Weapon.values
      .where((w) => w.requiredStage <= max(unlockedStage, stage - 1))
      .toList();
  int power = 1;
  int bombs = 2;
  int stage = 1;
  double stageTime = 0;
  int cue = 0;
  int kills = 0;
  double bombFlash = 0;
  StageBoss? boss;
  bool stageCleared = false;
  bool get victory => stageCleared && stage == 3;
  String get stageName =>
      const ['CORAL APPROACH', 'IRON HARBOR', 'STORM CITADEL'][stage - 1];
  int score = 0;
  int lives = 3;
  int wave = 0;
  double elapsed = 0;
  double protection = 2;
  double fireTime = 0;
  double waveTime = 0;
  bool ended = false;
  int get difficulty => min(6, 1 + elapsed ~/ 25);

  void reset({
    Aircraft selected = Aircraft.swift,
    int unlocked = 0,
    Weapon selectedWeapon = Weapon.pulse,
  }) {
    player.setValues(180, 530);
    bullets.clear();
    enemies.clear();
    pickups.clear();
    blasts.clear();
    bombWaves.clear();
    sounds.clear();
    aircraft = selected;
    power = selected.startingPower;
    bombs = 2;
    stage = 1;
    unlockedStage = unlocked.clamp(0, 3);
    weapon = selectedWeapon.requiredStage <= unlockedStage
        ? selectedWeapon
        : Weapon.pulse;
    laserTime = 0;
    stageTime = bombFlash = 0;
    cue = kills = 0;
    boss = null;
    stageCleared = false;
    score = wave = 0;
    lives = 3;
    elapsed = fireTime = waveTime = 0;
    protection = 2;
    ended = false;
  }

  void update(double dt) {
    // Substeps keep fast projectiles from skipping through small hitboxes.
    var remaining = dt.clamp(0.0, 0.1);
    while (remaining > 0 && !ended && !stageCleared) {
      final step = min(remaining, 1 / 120);
      _step(step);
      remaining -= step;
    }
  }

  void _step(double dt) {
    elapsed += dt;
    stageTime += dt;
    bombFlash = max(0, bombFlash - dt);
    for (final blast in blasts) {
      blast.age += dt;
    }
    blasts.removeWhere((blast) => blast.age >= blast.delay + blast.duration);
    for (final wave in bombWaves) {
      wave.age += dt;
    }
    bombWaves.removeWhere((wave) => wave.age >= 1);
    for (final pickup in pickups) {
      pickup.position.y += dt * 65;
      if (_near(pickup.position, player, 30)) {
        collect(pickup.kind);
        pickup.position.y = 900;
      }
    }
    pickups.removeWhere((pickup) => pickup.position.y > 680);
    protection = max(0, protection - dt);
    fireTime += dt;
    waveTime += dt;
    final interval = switch (weapon) {
      Weapon.missiles => 0.45,
      Weapon.plasma => 0.3,
      _ => 0.15,
    };
    if (fireTime >= interval) {
      fireTime -= interval;
      shoot();
    }
    final schedule = stageWaves[stage - 1];
    if (boss == null &&
        cue < schedule.length &&
        stageTime >= schedule[cue].$1) {
      spawnWave(pattern: schedule[cue].$2);
      cue++;
    }
    if (boss == null && stageTime >= 45) {
      boss = StageBoss(stage);
      enemies.clear();
      clearEnemyBullets();
    }
    _updateBoss(dt);
    if (weapon == Weapon.laser) {
      laserTime += dt;
      if (laserTime >= 0.1) {
        laserTime -= 0.1;
        _laserDamage();
      }
    }
    if (stageCleared) return;
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
          enemy.fireTime >= max(0.5, 1.9 - difficulty * 0.16 - stage * 0.08)) {
        enemy.fireTime = 0;
        final dx = player.x - enemy.position.x;
        final dy = player.y - enemy.position.y;
        final length = sqrt(dx * dx + dy * dy);
        final speed = 145 + difficulty * 17 + stage * 8;
        final vx = length > 0 ? dx / length * speed : 0.0;
        final vy = length > 0 ? dy / length * speed : speed.toDouble();
        final spread =
            enemy.pattern == EnemyPattern.turret ||
            (stage >= 2 && enemy.pattern == EnemyPattern.sine);
        for (final angle in spread ? [-0.18, 0.0, 0.18] : [0.0]) {
          bullets.spawn(
            enemy.position.x,
            enemy.position.y + 20,
            vx * cos(angle) - vy * sin(angle),
            vx * sin(angle) + vy * cos(angle),
            BulletOwner.enemy,
          );
        }
      }
    }
    for (final bullet in bullets.items) {
      if (!bullet.active) continue;
      if (bullet.owner == BulletOwner.player &&
          bullet.kind == Weapon.missiles) {
        _guideMissile(bullet, dt);
      }
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
            enemy.health = max(0, enemy.health - bullet.damage);
            if (bullet.kind == Weapon.missiles) {
              explode(bullet.position.x, bullet.position.y, large: true);
            }
            if (enemy.health == 0) {
              destroyEnemy(enemy);
            }
            break;
          }
        }
        final target = boss;
        if (bullet.active && target != null && target.position.y >= 90) {
          for (final part in target.parts) {
            if (part.health <= 0) continue;
            final dx = bullet.position.x - target.position.x - part.offsetX;
            final dy = bullet.position.y - target.position.y;
            if (dx.abs() < (part == target.core ? 29 : 24) && dy.abs() < 32) {
              bullet.active = false;
              if (part != target.core || target.exposed) {
                damageBossPart(part, bullet.damage);
                if (bullet.kind == Weapon.missiles) {
                  explode(bullet.position.x, bullet.position.y, large: true);
                }
              }
              break;
            }
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
    final target = boss;
    if (target != null && target.position.y >= 90) {
      for (final part in target.parts) {
        if (part.health > 0 &&
            (player.x - target.position.x - part.offsetX).abs() < 32 &&
            (player.y - target.position.y).abs() < 40) {
          damagePlayer();
        }
      }
    }
  }

  void shoot() {
    sounds.add(CombatSound.shot);
    if (weapon == Weapon.laser) return;
    if (weapon == Weapon.missiles) {
      for (final offset in power >= 3 ? [-12.0, 12.0] : [0.0]) {
        bullets.spawn(
          player.x + offset,
          player.y - 25,
          offset * 3,
          -360,
          BulletOwner.player,
          kind: Weapon.missiles,
          damage: 4 + power,
        );
      }
      return;
    }
    if (weapon == Weapon.plasma) {
      for (final vx in [-90.0, 0.0, 90.0]) {
        bullets.spawn(
          player.x + vx / 8,
          player.y - 25,
          vx,
          -440,
          BulletOwner.player,
          kind: Weapon.plasma,
          damage: 2 + power,
        );
      }
      return;
    }
    void shot(double offset, double vx) => bullets.spawn(
      player.x + offset,
      player.y - 25,
      vx,
      -600,
      BulletOwner.player,
    );
    if (power == 1) {
      shot(0, 0);
    } else if (power == 2) {
      shot(-9, 0);
      shot(9, 0);
    } else if (power == 3) {
      shot(0, 0);
      shot(-12, -100);
      shot(12, 100);
    } else {
      shot(0, 0);
      shot(-9, -65);
      shot(9, 65);
      shot(-18, -160);
      shot(18, 160);
    }
  }

  void cycleWeapon() {
    if (ended || stageCleared) return;
    final choices = availableWeapons;
    weapon = choices[(choices.indexOf(weapon) + 1) % choices.length];
    fireTime = laserTime = 0;
  }

  void _laserDamage() {
    final damage = power >= 3 ? 2 : 1;
    for (final enemy in enemies) {
      if (enemy.health <= 0 || enemy.position.y >= player.y - 24) continue;
      if ((enemy.position.x - player.x).abs() <= 18 + laserWidth / 2) {
        enemy.health = max(0, enemy.health - damage);
        if (enemy.health == 0) destroyEnemy(enemy);
      }
    }
    final target = boss;
    if (target == null ||
        target.position.y < 90 ||
        target.position.y >= player.y - 24) {
      return;
    }
    for (final part in target.parts) {
      if (part.health > 0 &&
          (target.position.x + part.offsetX - player.x).abs() <
              22 + laserWidth / 2) {
        damageBossPart(part, damage);
      }
    }
  }

  void _guideMissile(Bullet bullet, double dt) {
    var nearest = double.infinity;
    double? targetX;
    double? targetY;
    void consider(double x, double y) {
      if (y > bullet.position.y + 30) return;
      final dx = x - bullet.position.x;
      final dy = y - bullet.position.y;
      final distance = dx * dx + dy * dy;
      if (distance < nearest) {
        nearest = distance;
        targetX = x;
        targetY = y;
      }
    }

    for (final enemy in enemies) {
      if (enemy.health > 0) consider(enemy.position.x, enemy.position.y);
    }
    final target = boss;
    if (target != null && target.position.y >= 90) {
      for (final part in target.parts) {
        if (part.health > 0 && (part != target.core || target.exposed)) {
          consider(target.position.x + part.offsetX, target.position.y);
        }
      }
    }
    if (targetX == null || targetY == null) return;
    final dx = targetX! - bullet.position.x;
    final dy = targetY! - bullet.position.y;
    final length = max(1.0, sqrt(dx * dx + dy * dy));
    final turn = min(1.0, dt * 6);
    bullet.velocity.x += (dx / length * 420 - bullet.velocity.x) * turn;
    bullet.velocity.y += (dy / length * 420 - bullet.velocity.y) * turn;
  }

  void collect(PickupKind kind) {
    sounds.add(CombatSound.pickup);
    if (kind == PickupKind.power) {
      if (power < 4) {
        power++;
      } else {
        score += 1000;
      }
    } else {
      if (bombs < 5) {
        bombs++;
      } else {
        score += 500;
      }
    }
  }

  void explode(double x, double y, {bool large = false, double delay = 0}) {
    if (blasts.length >= 32) blasts.removeAt(0);
    blasts.add(Blast(x, y, large: large, delay: delay));
    sounds.add(CombatSound.explosion);
  }

  void destroyEnemy(Enemy enemy) {
    score += enemy.pattern == EnemyPattern.turret ? 250 : 100;
    explode(enemy.position.x, enemy.position.y);
    kills++;
    // Predictable supplies reward clearing formations rather than random luck.
    if (kills % 3 == 0 && pickups.length < 12) {
      pickups.add(
        Pickup(
          enemy.position.x,
          enemy.position.y,
          kills % 9 == 0 ? PickupKind.bomb : PickupKind.power,
        ),
      );
    }
  }

  void clearEnemyBullets() {
    for (final bullet in bullets.items) {
      if (bullet.owner == BulletOwner.enemy) bullet.active = false;
    }
  }

  bool useBomb() {
    if (bombs <= 0 || ended || stageCleared) return false;
    bombs--;
    if (bombWaves.length >= 3) bombWaves.removeAt(0);
    bombWaves.add(BombWave(player.x, player.y));
    explode(player.x, player.y, large: true);
    for (var i = 0; i < 9; i++) {
      explode(
        40 + (i % 3) * 140.0,
        130 + (i ~/ 3) * 165.0,
        large: true,
        delay: i * 0.035,
      );
    }
    bombFlash = 0.35;
    protection = max(protection, 1.5);
    sounds.add(CombatSound.bomb);
    clearEnemyBullets();
    for (final enemy in enemies) {
      if (enemy.health <= 0) continue;
      enemy.health -= 30;
      if (enemy.health <= 0) destroyEnemy(enemy);
    }
    enemies.removeWhere((enemy) => enemy.health <= 0);
    final target = boss;
    if (target != null && target.position.y >= 90) {
      for (final wing in target.wings) {
        damageBossPart(wing, 28);
      }
      if (target.exposed) damageBossPart(target.core, 40);
    }
    return true;
  }

  void damageBossPart(BossPart part, int damage) {
    final target = boss;
    if (target == null || part.health <= 0) return;
    if (!target.parts.contains(part) ||
        (part == target.core && !target.exposed)) {
      return;
    }
    part.health = max(0, part.health - damage);
    if (part.health > 0) return;
    explode(target.position.x + part.offsetX, target.position.y, large: true);
    score += part == target.core ? 3000 * stage : 500;
    if (part == target.core) {
      stageCleared = true;
      ended = stage == 3;
      bullets.clear();
      enemies.clear();
      pickups.clear();
      sounds.add(CombatSound.clear);
    }
  }

  void _updateBoss(double dt) {
    final target = boss;
    if (target == null) return;
    target.age += dt;
    target.position.x = 180 + sin(target.age * 0.65) * 55;
    target.position.y = min(215, target.position.y + dt * 65);
    if (target.position.y < 90) return;
    target.radialTime += dt;
    target.aimedTime += dt;
    final enraged = target.core.health < target.core.maxHealth / 2;
    if (target.radialTime >= (target.exposed ? (enraged ? 0.55 : 0.75) : 1.1)) {
      target.radialTime = 0;
      final count = 7 + stage * 2;
      for (var i = 0; i < count; i++) {
        final angle = pi * (0.12 + 0.76 * i / (count - 1));
        final speed = 115 + stage * 16.0;
        bullets.spawn(
          target.position.x,
          target.position.y + 28,
          cos(angle) * speed,
          sin(angle) * speed,
          BulletOwner.enemy,
        );
      }
    }
    if (target.aimedTime >= max(0.55, 1.1 - stage * 0.12)) {
      target.aimedTime = 0;
      for (final wing in target.wings) {
        if (wing.health <= 0) continue;
        final x = target.position.x + wing.offsetX;
        final dx = player.x - x;
        final dy = player.y - target.position.y;
        final distance = max(1.0, sqrt(dx * dx + dy * dy));
        bullets.spawn(
          x,
          target.position.y + 20,
          dx / distance * 170,
          dy / distance * 170,
          BulletOwner.enemy,
        );
      }
    }
  }

  void nextStage() {
    if (!stageCleared || stage >= 3) return;
    stage++;
    unlockedStage = max(unlockedStage, stage - 1);
    weapon = Weapon.values[unlockedStage];
    laserTime = 0;
    stageTime = waveTime = fireTime = 0;
    cue = 0;
    boss = null;
    stageCleared = false;
    bullets.clear();
    enemies.clear();
    blasts.clear();
    bombWaves.clear();
    sounds.clear();
    pickups.clear();
    player.setValues(180, 530);
    protection = 3;
    bombs = min(5, bombs + 1);
  }

  bool _near(Vector2 a, Vector2 b, double radius) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return dx * dx + dy * dy <= radius * radius;
  }

  void damagePlayer() {
    if (protection > 0 || ended) return;
    lives--;
    explode(player.x, player.y, large: true);
    power = max(1, power - 1);
    if (lives == 0) {
      ended = true;
      return;
    }
    player.setValues(180, 530);
    protection = 2;
    clearEnemyBullets();
  }

  void spawnWave({EnemyPattern? pattern}) {
    pattern ??= EnemyPattern.values[wave % EnemyPattern.values.length];
    wave++;
    final count = pattern == EnemyPattern.turret
        ? min(3, 1 + stage)
        : min(6, 3 + difficulty);
    final offset = random.nextDouble() * 16 - 8;
    for (var i = 0; i < count && enemies.length < 32; i++) {
      enemies.add(
        Enemy(
          50 + i * 260 / max(1, count - 1) + offset,
          -30 - i * 35,
          pattern,
          100 + difficulty * 14.0 + stage * 8,
          health: pattern == EnemyPattern.turret ? 6 + stage * 2 : 2 + stage,
        ),
      );
    }
  }
}
