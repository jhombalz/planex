enum Aircraft {
  swift('SWIFT', 'Agile interceptor · cyan weapon effects', 1.1, 1, 0xff68e6ff),
  striker(
    'STRIKER',
    'Level 2 fighter · amber weapon effects · power 2',
    0.9,
    2,
    0xffffaa55,
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
}
