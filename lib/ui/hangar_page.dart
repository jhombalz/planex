import 'dart:async';

import 'package:flutter/material.dart';

import '../game/aircraft.dart';
import '../game/artwork.dart';
import '../game/flight_game.dart';
import '../game/sprite_art.dart';
import 'arcade_glyph.dart';
import 'v2_panels.dart';

class Hangar extends StatelessWidget {
  const Hangar({super.key, required this.game});
  final FlightGame game;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: game.profile,
    builder: (context, _) {
      final profile = game.profile;
      final paused = game.started && !game.ended;
      return Scaffold(
        key: const Key('home-screen'),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xff12384b), Color(0xff061725)],
            ),
          ),
          child: SafeArea(
            child: SizedBox.expand(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        const Text(
                          'PLANEX',
                          style: TextStyle(
                            fontSize: 38,
                            letterSpacing: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          paused ? 'FLIGHT PAUSED' : 'PULSE. COLLECT. SURVIVE.',
                          style: const TextStyle(
                            color: Color(0xff86eadc),
                            letterSpacing: 2,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'BEST ${profile.highScore}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (game.ended)
                          Text('Flight complete · Score ${game.score}'),
                        if (!paused) ...[
                          AircraftPreview(profile.selected),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            children: Aircraft.values.map((plane) {
                              final locked = !profile.unlocked(plane);
                              return Tooltip(
                                message: locked
                                    ? 'Clear level ${plane == Aircraft.striker ? 1 : 3} to unlock ${plane.label}'
                                    : plane.description,
                                child: ChoiceChip(
                                  avatar: SpriteIcon(plane.name, size: 28),
                                  label: Icon(
                                    locked ? Icons.lock_outline : Icons.flight,
                                    size: 18,
                                  ),
                                  selected: profile.selected == plane,
                                  onSelected: locked
                                      ? null
                                      : (_) => unawaited(profile.select(plane)),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            profile.selected.description,
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.filled(
                              tooltip: paused
                                  ? 'Resume flight'
                                  : game.ended
                                  ? 'Fly again'
                                  : 'Start flight',
                              style: IconButton.styleFrom(
                                minimumSize: const Size(72, 72),
                              ),
                              icon: ArcadeGlyph(
                                game.ended ? GameAction.retry : GameAction.play,
                                size: 42,
                              ),
                              onPressed: paused || profile.tutorialSeen
                                  ? game.startFlight
                                  : () => showFlightGuide(
                                      context,
                                      game,
                                      onFinish: game.startFlight,
                                    ),
                            ),
                            if (paused) ...[
                              const SizedBox(width: 20),
                              IconButton.outlined(
                                tooltip: 'End flight and save score',
                                onPressed: game.returnToHangar,
                                icon: const ArcadeGlyph(GameAction.home),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (!paused) V2HangarPanel(game),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 24,
                          runSpacing: 12,
                          children: [
                            IconButton.outlined(
                              tooltip: 'Controls',
                              onPressed: () =>
                                  openGamePage(context, ControlsPage(game)),
                              icon: const Icon(Icons.tune),
                            ),
                            IconButton.outlined(
                              tooltip: 'Achievements',
                              onPressed: () =>
                                  openGamePage(context, AchievementsPage(game)),
                              icon: const Icon(Icons.emoji_events_outlined),
                            ),
                            IconButton.outlined(
                              tooltip: 'High scores',
                              onPressed: () =>
                                  openGamePage(context, ScoresPage(game)),
                              icon: const Icon(Icons.leaderboard_outlined),
                            ),
                          ],
                        ),
                        if (profile.saveFailed) ...[
                          const Text(
                            'Could not save progress.',
                            style: TextStyle(color: Colors.amber),
                          ),
                          IconButton(
                            tooltip: 'Retry save',
                            onPressed: profile.save,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
