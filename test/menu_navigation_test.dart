import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planex/main.dart';
import 'package:planex/game/flight_game.dart';
import 'package:planex/game/sprite_art.dart';
import 'package:planex/services/player_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(SpriteArt.load);
  Future<PlayerProfile> mount(
    WidgetTester tester, {
    bool tutorialSeen = true,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final profile = PlayerProfile(await SharedPreferences.getInstance())
      ..tutorialSeen = tutorialSeen;
    await tester.pumpWidget(PlanexApp(profile: profile, enableAudio: false));
    await tester.pumpAndSettle();
    return profile;
  }

  Future<void> open(WidgetTester tester, String tooltip) async {
    await tester.ensureVisible(find.byTooltip(tooltip));
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  testWidgets('pages fit a small phone with enlarged text and cutouts', (
    tester,
  ) async {
    await mount(tester);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.padding = const FakeViewPadding(top: 30, bottom: 20);
    tester.view.viewPadding = const FakeViewPadding(top: 30, bottom: 20);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    for (final page in [
      'Controls',
      'Achievements',
      'High scores',
      'Tutorial',
      'Practice',
    ]) {
      await open(tester, page);
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byTooltip('Back to home')).top,
        greaterThanOrEqualTo(30),
      );
      await back(tester);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'home fills phone; separate pages preserve settings and return with Back',
    (tester) async {
      final profile = await mount(tester);
      expect(
        tester.getRect(find.byKey(const Key('home-screen'))),
        const Rect.fromLTWH(0, 0, 360, 800),
      );
      expect(find.byType(Card), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Mute audio'), findsNothing);
      await open(tester, 'Controls');
      expect(find.text('CONTROLS'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Bomb button on left'),
      );
      await tester.pumpAndSettle();
      expect(profile.leftHanded, isTrue);
      expect(PlayerProfile(profile.preferences).leftHanded, isTrue);
      await back(tester);
      expect(find.byKey(const Key('home-screen')), findsOneWidget);
      await open(tester, 'Achievements');
      expect(find.text('ACHIEVEMENTS'), findsOneWidget);
      expect(find.text('FIRST CONTACT'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await back(tester);
      await open(tester, 'High scores');
      expect(find.text('HIGH SCORES'), findsOneWidget);
      await back(tester);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Back from controls keeps a paused flight paused', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byTooltip('Start flight'));
    await tester.pump(const Duration(milliseconds: 16));
    final game = tester
        .widget<GameWidget<FlightGame>>(find.byType(GameWidget<FlightGame>))
        .game!;
    game.pauseFlight();
    await tester.pumpAndSettle();
    await open(tester, 'Controls');
    await back(tester);
    expect(game.active, isFalse);
    await tester.tap(find.byTooltip('Resume flight'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.active, isTrue);
    game.pauseFlight();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tutorial can be cancelled and practice opens as a full page', (
    tester,
  ) async {
    final profile = await mount(tester, tutorialSeen: false);
    await open(tester, 'Start flight');
    expect(find.text('FLIGHT GUIDE'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await back(tester);
    expect(profile.tutorialSeen, isFalse);
    await open(tester, 'Practice');
    expect(find.text('PRACTICE LEVEL'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.byTooltip('Practice level 1'));
    await tester.pump(const Duration(milliseconds: 400));
    final game = tester
        .widget<GameWidget<FlightGame>>(find.byType(GameWidget<FlightGame>))
        .game!;
    expect(game.active && game.combat.practice, isTrue);
    game.pauseFlight();
    await tester.pumpWidget(const SizedBox());
  });
}
