import 'package:flutter_test/flutter_test.dart';
import 'package:planex/game/flight_game.dart';
import 'package:flame/game.dart';

void main() {
  test('a shot scores once and removes the enemy', () {
    final game = FlightGame()..active = true;
    game.enemies.add(Vector2(100, 100));
    game.shots.add(Vector2(100, 100));
    game.update(0);
    expect(game.score, 100);
    expect(game.enemies, isEmpty);
    expect(game.shots, isEmpty);
  });
  test('offscreen entities are cleaned up', () {
    final game = FlightGame()..active = true;
    game.enemies.add(Vector2(100, 700));
    game.shots.add(Vector2(100, -40));
    game.update(0);
    expect(game.enemies, isEmpty);
    expect(game.shots, isEmpty);
  });
}
