import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planex/main.dart';
import 'package:planex/game/flight_game.dart';
import 'package:planex/game/combat_state.dart';
import 'package:planex/game/weapon.dart';
import 'package:planex/game/aircraft.dart';
import 'package:planex/game/sprite_art.dart';
import 'package:planex/services/player_profile.dart';

FlightGame currentGame(WidgetTester tester) => tester
    .widget<GameWidget<FlightGame>>(find.byType(GameWidget<FlightGame>))
    .game!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(SpriteArt.load);
  testWidgets(
    'controls respect display cutouts while scenery remains fullscreen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 40, bottom: 24);
      tester.view.viewPadding = const FakeViewPadding(top: 40, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      SharedPreferences.setMockInitialValues({});
      final profile = PlayerProfile(await SharedPreferences.getInstance());
      await tester.pumpWidget(PlanexApp(profile: profile, enableAudio: false));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Start flight'));
      await tester.pump(const Duration(milliseconds: 16));
      final game = currentGame(tester);
      expect(game.size.y, 800);
      expect(game.topInset, 40);
      expect(
        tester.getRect(find.byTooltip('Pause flight')).top,
        greaterThanOrEqualTo(40),
      );
      expect(
        tester.getRect(find.byKey(const Key('bomb-button'))).bottom,
        lessThanOrEqualTo(776),
      );
      game.pauseFlight();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'quitting during boss destruction saves the cleared level reward',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final profile = PlayerProfile(await SharedPreferences.getInstance());
      await tester.pumpWidget(PlanexApp(profile: profile, enableAudio: false));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Start flight'));
      await tester.pump(const Duration(milliseconds: 16));
      final game = currentGame(tester);
      game.combat.boss = StageBoss(1)..position.setValues(180, 215);
      for (final part in game.combat.boss!.parts) {
        game.combat.damageBossPart(part, 10000);
      }
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.combat.stageCleared, isFalse);
      game.pauseFlight();
      await tester.pump();
      await tester.tap(find.byTooltip('End flight and save score'));
      await tester.pumpAndSettle();
      expect(profile.clearedStage, 1);
      expect(profile.strikerUnlocked, isTrue);
      expect(profile.scores.length, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'fullscreen playfield has no weapon switch; bonuses come from drops',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final profile = PlayerProfile(await SharedPreferences.getInstance());
      await profile.recordStage(3);
      await tester.pumpWidget(PlanexApp(profile: profile, enableAudio: false));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Start flight'));
      await tester.pump(const Duration(milliseconds: 16));
      final game = currentGame(tester);
      expect(game.combat.weapon, Weapon.pulse);
      expect(find.byTooltip('Switch weapon'), findsNothing);
      expect(find.text('BOMB 2'), findsNothing);
      expect(
        game.size.x,
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
      );
      expect(
        game.size.y,
        tester.view.physicalSize.height / tester.view.devicePixelRatio,
      );
      game.combat.pickups.add(
        Pickup(180, 530, PickupKind.bonus, weapon: Weapon.laser),
      );
      await tester.pump(const Duration(milliseconds: 32));
      expect(game.combat.weapon, Weapon.laser);
      game.pauseFlight();
      final seconds = game.combat.bonusTime;
      await tester.pump(const Duration(seconds: 2));
      expect(game.combat.bonusTime, seconds);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('icon-only bomb works with a steering finger; lifecycle pauses', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final profile = PlayerProfile(await SharedPreferences.getInstance());
    await tester.pumpWidget(PlanexApp(profile: profile, enableAudio: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Start flight'));
    await tester.pump(const Duration(milliseconds: 16));
    final game = currentGame(tester);
    final steering = await tester.startGesture(
      const Offset(200, 350),
      pointer: 1,
    );
    await steering.moveBy(const Offset(45, 0));
    await tester.pump(const Duration(milliseconds: 16));
    final x = game.combat.player.x;
    expect(x, greaterThan(180));
    await tester.tap(find.byKey(const Key('bomb-button')), pointer: 2);
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.combat.bombs, 1);
    expect(game.combat.player.x, x);
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
    await tester.tap(find.byTooltip('Resume flight'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.active, isTrue);
    game.pauseFlight();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('level 2 unlock and final score flow use icon actions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final profile = PlayerProfile(await SharedPreferences.getInstance());
    await tester.pumpWidget(PlanexApp(profile: profile, enableAudio: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Start flight'));
    await tester.pump(const Duration(milliseconds: 16));
    final game = currentGame(tester);
    for (var stage = 1; stage <= 3; stage++) {
      final boss = StageBoss(stage)..position.setValues(180, 215);
      game.combat.boss = boss;
      for (final part in boss.parts) {
        game.combat.damageBossPart(part, 10000);
      }
      await tester.pump(const Duration(milliseconds: 32));
      await tester.pumpAndSettle();
      expect(game.active, isFalse);
      expect(profile.strikerUnlocked, isTrue);
      if (stage < 3) {
        expect(find.text('LEVEL $stage CLEAR'), findsOneWidget);
        await tester.tap(find.byTooltip('Next level'));
        await tester.pump(const Duration(milliseconds: 16));
        expect(game.combat.weapon, Weapon.pulse);
        expect(game.combat.aircraft, Aircraft.striker);
      }
    }
    expect(find.text('CAMPAIGN COMPLETE'), findsOneWidget);
    expect(profile.highScore, game.score);
    expect(profile.clearedStage, 3);
    await tester.tap(find.byTooltip('Return to hangar'));
    await tester.pumpAndSettle();
    expect(profile.scores.length, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
