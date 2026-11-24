enum Weapon {
  pulse('PULSE', 'Default multishot cannon'),
  laser('LASER', 'Bonus multibeam laser'),
  missiles('MISSILES', 'Bonus homing missiles'),
  plasma('PLASMA', 'Bonus plasma cannon');

  const Weapon(this.label, this.description);
  final String label;
  final String description;
}
