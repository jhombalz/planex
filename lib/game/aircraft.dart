enum Aircraft {
  swift('SWIFT', 'Agile interceptor', 1.1, 1),
  striker('STRIKER', 'Heavy fighter · starts at power 2', 0.9, 2);

  const Aircraft(
    this.label,
    this.description,
    this.handling,
    this.startingPower,
  );
  final String label;
  final String description;
  final double handling;
  final int startingPower;
}
