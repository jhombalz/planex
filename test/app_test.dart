import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planex/main.dart';
import 'package:planex/game/flight_game.dart';
import 'package:planex/game/combat_state.dart';
import 'package:planex/game/weapon.dart';
import 'package:planex/game/sprite_art.dart';
import 'package:planex/services/player_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(SpriteArt.load);
  testWidgets(
    'unlocked weapon button cycles during flight and persists selection',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final profile = PlayerProfile(await SharedPreferences.getInstance());
      await profile.recordStage(3);
      await tester.pumpWidget(PlanexApp(profile: profile, enableAudio: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start flight'));
      await tester.pump(const Duration(milliseconds: 16));
      final game = tester
          .widget<GameWidget<FlightGame>>(find.byType(GameWidget<FlightGame>))
          .game!;
      expect(game.combat.weapon, Weapon.plasma);
      await tester.tap(find.text('PLASMA'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.combat.weapon, Weapon.pulse);
      await tester.tap(find.text('PULSE'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.combat.weapon, Weapon.laser);
      expect(profile.selectedWeapon, Weapon.laser);
      game.pauseFlight();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'start, steer and bomb with a second finger, then lifecycle pause',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final profile = PlayerProfile(await SharedPreferences.getInstance());
      await tester.pumpWidget(PlanexApp(profile: profile, enableAudio: false));
      await tester.pumpAndSettle();
      expect(find.text('PLANEX'), findsOneWidget);
      await tester.tap(find.text('Start flight'));
      await tester.pump(const Duration(milliseconds: 16));
      final game = tester
          .widget<GameWidget<FlightGame>>(find.byType(GameWidget<FlightGame>))
          .game!;
      expect(game.active, isTrue);
      final steering = await tester.startGesture(
        const Offset(200, 350),
        pointer: 1,
      );
      await steering.moveBy(const Offset(45, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final x = game.combat.player.x;
      expect(x, greaterThan(180));
      await tester.tap(find.text('BOMB 2'), pointer: 2);
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.combat.bombs, 1);
      expect(game.combat.player.x, x);
      await steering.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.combat.player.x, lessThan(x));
      await steering.up();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(game.active, isFalse);
      expect(game.useBomb(), isFalse);
      final elapsed = game.combat.elapsed;
      await tester.pump(const Duration(seconds: 3));
      expect(game.combat.elapsed, elapsed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(game.active, isFalse);
      await tester.tap(find.text('Resume flight'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.active, isTrue);
      game.pauseFlight();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'stage clear shows next stage and saves unlock; victory saves score',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final profile = PlayerProfile(await SharedPreferences.getInstance());
      await tester.pumpWidget(PlanexApp(profile: profile, enableAudio: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start flight'));
      await tester.pump(const Duration(milliseconds: 16));
      final game = tester
          .widget<GameWidget<FlightGame>>(find.byType(GameWidget<FlightGame>))
          .game!;
      for (var stage = 1; stage <= 3; stage++) {
        final boss = StageBoss(stage)..position.setValues(180, 110);
        game.combat.boss = boss;
        for (final part in boss.parts) {
          game.combat.damageBossPart(part, 10000);
        }
        await tester.pump(const Duration(milliseconds: 32));
        await tester.pumpAndSettle();
        expect(game.active, isFalse);
        expect(profile.strikerUnlocked, isTrue);
        if (stage < 3) {
          expect(find.text('STAGE $stage CLEAR'), findsOneWidget);
          await tester.tap(find.text('Next stage · +1 bomb'));
          await tester.pump(const Duration(milliseconds: 16));
          expect(game.combat.stage, stage + 1);
        }
      }
      expect(find.text('CAMPAIGN COMPLETE'), findsOneWidget);
      expect(profile.highScore, game.score);
      expect(profile.clearedStage, 3);
      await tester.tap(find.text('Return to hangar'));
      await tester.pumpAndSettle();
      expect(profile.scores.length, 1);
      expect(find.text('Start flight'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
