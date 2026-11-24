enum Aircraft {
  swift('SWIFT', 'Agile interceptor · cyan weapon effects', 1.1, 1, 0xff68e6ff),
  striker(
    'STRIKER',
    'Level 2 fighter · amber weapon effects · power 2',
    0.9,
    2,
    0xffffaa55,
  ),
  wraith(
    'WRAITH',
    'Level 4 stealth fighter · faster fire · longer bonuses',
    1.2,
    1,
    0xffc18aff,
  );

  const Aircraft(
    this.label,
    this.description,
    this.handling,
    this.startingPower,
    this.weaponColor,
  );
  final String label;
  final String description;
  final double handling;
  final int startingPower;
  final int weaponColor;
  int get startingBombs => this == Aircraft.wraith ? 1 : 2;
  double get fireMultiplier => this == Aircraft.wraith ? 0.85 : 1;
  double get bonusSeconds => this == Aircraft.wraith ? 22 : 18;
  double get bombMultiplier => this == Aircraft.striker ? 1.25 : 1;
}
