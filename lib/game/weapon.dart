enum Weapon {
  pulse('PULSE', 'Rapid multishot cannon', 0),
  laser('LASER', 'Continuous piercing beam', 1),
  missiles('MISSILES', 'Homing explosive missiles', 2),
  plasma('PLASMA', 'Heavy three-way plasma cannon', 3);

  const Weapon(this.label, this.description, this.requiredStage);
  final String label;
  final String description;
  final int requiredStage;
}
