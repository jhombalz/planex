import 'aircraft.dart';

enum Challenge {
  easy('EASY', 0.8, 0.82, 1.25),
  normal('NORMAL', 1, 1, 1),
  expert('EXPERT', 1.25, 1.18, 0.82);

  const Challenge(this.label, this.health, this.speed, this.fire);
  final String label;
  final double health, speed, fire;
}

enum Medal { bronze, silver, gold }

class CampaignLevel {
  const CampaignLevel(this.name, this.background, this.boss, this.attack);
  final String name, background, boss, attack;
}

const campaign = [
  CampaignLevel('CORAL APPROACH', 'coral', 'REEF REAPER', 'WIDE FAN'),
  CampaignLevel('IRON HARBOR', 'harbor', 'HARBOR HAMMER', 'CROSSFIRE'),
  CampaignLevel('STORM CITADEL', 'storm', 'STORM EMPEROR', 'ROTATING SPIRAL'),
  CampaignLevel('SUNSET BASTION', 'sunset', 'DUNE SENTINEL', 'PINCER BARRAGE'),
  CampaignLevel(
    'FROZEN CONVOY',
    'arctic',
    'FROST DREADNOUGHT',
    'SWEEPING LANES',
  ),
  CampaignLevel('EMBER FORTRESS', 'volcano', 'EMBER SOVEREIGN', 'DOUBLE HELIX'),
];

enum Achievement {
  firstKill('FIRST CONTACT', 'Destroy your first enemy'),
  comboAce('COMBO ACE', 'Chain eight kills'),
  powerMaster('POWER MASTER', 'Reach power 4'),
  untouchable('UNTOUCHABLE', 'Earn a gold level medal'),
  bossHunter('BOSS HUNTER', 'Clear three levels'),
  campaignHero('SKY GUARDIAN', 'Finish all six levels'),
  expertPilot('EXPERT PILOT', 'Finish the campaign on Expert'),
  arsenal('ARSENAL', 'Collect all three bonus weapons'),
  noBombs('PRECISION PILOT', 'Complete a campaign without bombs');

  const Achievement(this.title, this.description);
  final String title, description;
}

class RunStats {
  int kills = 0,
      currentCombo = 0,
      maxCombo = 0,
      damage = 0,
      bombs = 0,
      shots = 0,
      hits = 0,
      maxPower = 1;
  final Set<String> weapons = {};
  double? get accuracy => shots == 0 ? null : (hits / shots).clamp(0, 1);
  Map<String, dynamic> toJson() => {
    'kills': kills,
    'combo': maxCombo,
    'damage': damage,
    'bombs': bombs,
    'shots': shots,
    'hits': hits,
    'power': maxPower,
    'weapons': weapons.toList(),
  };
  static RunStats fromJson(dynamic raw) {
    final s = RunStats();
    if (raw is! Map) return s;
    int value(String key) =>
        raw[key] is int ? (raw[key] as int).clamp(0, 100000000) : 0;
    s.kills = value('kills');
    s.maxCombo = value('combo');
    s.damage = value('damage');
    s.bombs = value('bombs');
    s.shots = value('shots');
    s.hits = value('hits');
    s.maxPower = value('power').clamp(1, 4);
    if (raw['weapons'] is List) {
      s.weapons.addAll(
        (raw['weapons'] as List).whereType<String>().where(
          (v) => ['laser', 'missiles', 'plasma', 'spread'].contains(v),
        ),
      );
    }
    return s;
  }
}

class RunCheckpoint {
  RunCheckpoint({
    required this.stage,
    required this.lives,
    required this.bombs,
    required this.power,
    required this.score,
    required this.aircraft,
    required this.mode,
    required this.stats,
    this.elapsed = 0,
  });
  final int stage, lives, bombs, power, score;
  final Aircraft aircraft;
  final Challenge mode;
  final RunStats stats;
  final double elapsed;
  Map<String, dynamic> toJson() => {
    'version': 2,
    'stage': stage,
    'lives': lives,
    'bombs': bombs,
    'power': power,
    'score': score,
    'aircraft': aircraft.name,
    'mode': mode.name,
    'stats': stats.toJson(),
    'elapsed': elapsed,
  };
  static RunCheckpoint? fromJson(dynamic raw) {
    if (raw is! Map || raw['version'] != 2) return null;
    bool valid(String key, int low, int high) =>
        raw[key] is int &&
        (raw[key] as int) >= low &&
        (raw[key] as int) <= high;
    if (!valid('stage', 1, campaign.length) ||
        !valid('lives', 1, 5) ||
        !valid('bombs', 0, 5) ||
        !valid('power', 1, 4) ||
        !valid('score', 0, 1000000000)) {
      return null;
    }
    final planes = Aircraft.values.where((p) => p.name == raw['aircraft']);
    final modes = Challenge.values.where((m) => m.name == raw['mode']);
    if (planes.isEmpty || modes.isEmpty) return null;
    final elapsed = raw['elapsed'] ?? 0;
    if (elapsed is! num ||
        !elapsed.isFinite ||
        elapsed < 0 ||
        elapsed > 10000000) {
      return null;
    }
    return RunCheckpoint(
      stage: raw['stage'] as int,
      lives: raw['lives'] as int,
      bombs: raw['bombs'] as int,
      power: raw['power'] as int,
      score: raw['score'] as int,
      aircraft: planes.first,
      mode: modes.first,
      stats: RunStats.fromJson(raw['stats']),
      elapsed: elapsed.toDouble(),
    );
  }
}
