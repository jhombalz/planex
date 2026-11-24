import 'dart:async';

import 'package:flutter/material.dart';

import '../game/campaign.dart';
import '../game/flight_game.dart';

void openGamePage(BuildContext context, Widget page) {
  Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));
}

class GamePageShell extends StatelessWidget {
  const GamePageShell({
    super.key,
    required this.title,
    required this.child,
    this.footer = const [],
  });
  final String title;
  final Widget child;
  final List<Widget> footer;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      leading: IconButton(
        tooltip: 'Back to home',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                child,
                if (footer.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: footer,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ControlsPage extends StatelessWidget {
  const ControlsPage(this.game, {super.key});
  final FlightGame game;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: game.profile,
    builder: (context, _) {
      final profile = game.profile;
      return GamePageShell(
        title: 'CONTROLS',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Drag anywhere to steer. Weapons fire automatically. Tap the bomb icon with a second finger to clear danger.',
              style: TextStyle(fontSize: 17, height: 1.6),
            ),
            const SizedBox(height: 16),
            const Text(
              'Collect P to strengthen your weapon and B for bombs. Gold-ring drops grant temporary Laser, Missiles, Plasma or Spread. Pause with the top-right icon or Android Back.',
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bomb button on left'),
              value: profile.leftHanded,
              onChanged: (value) {
                profile.leftHanded = value;
                unawaited(profile.save());
              },
            ),
            Text(
              'Drag sensitivity: ${profile.sensitivity.toStringAsFixed(1)}×',
            ),
            Slider(
              label: profile.sensitivity.toStringAsFixed(1),
              min: 0.5,
              max: 1.8,
              divisions: 13,
              value: profile.sensitivity,
              onChanged: (value) {
                profile.sensitivity = value;
                unawaited(profile.save());
              },
            ),
            const Divider(height: 40),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mute audio'),
              value: profile.muted,
              onChanged: (value) {
                profile.muted = value;
                unawaited(profile.save());
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reduce motion'),
              subtitle: const Text(
                'Reduce flashes and freeze scenery and propellers',
              ),
              value: profile.reducedMotion,
              onChanged: (value) {
                profile.reducedMotion = value;
                unawaited(profile.save());
              },
            ),
            if (game.audio.unavailable)
              const Text('Audio is unavailable on this device.'),
          ],
        ),
      );
    },
  );
}

class AchievementsPage extends StatelessWidget {
  const AchievementsPage(this.game, {super.key});
  final FlightGame game;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: game.profile,
    builder: (context, _) {
      final profile = game.profile;
      return GamePageShell(
        title: 'ACHIEVEMENTS',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${profile.achievements.length} / ${Achievement.values.length} earned',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            for (final achievement in Achievement.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  profile.achievements.contains(achievement.name)
                      ? Icons.verified
                      : Icons.lock_outline,
                  color: profile.achievements.contains(achievement.name)
                      ? const Color(0xffffd16a)
                      : null,
                ),
                title: Text(achievement.title),
                subtitle: Text(achievement.description),
              ),
            const Divider(height: 40),
            const Text(
              'CAMPAIGN RECORDS',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            for (final mode in Challenge.values) ...[
              const SizedBox(height: 20),
              Text(
                '${mode.label} · ${profile.completions[mode.name] ?? 0} campaign clears',
              ),
              Wrap(
                spacing: 8,
                children: List.generate(campaign.length, (i) {
                  final medal = profile.medals['${mode.name}:${i + 1}'];
                  return Tooltip(
                    message:
                        '${campaign[i].name}: ${medal == null ? 'No medal' : Medal.values[medal].name}',
                    child: Chip(
                      avatar: Icon(
                        medal == null
                            ? Icons.radio_button_unchecked
                            : Icons.workspace_premium,
                        size: 18,
                        color: medal == null
                            ? null
                            : [
                                const Color(0xffb48762),
                                const Color(0xffbfcbd8),
                                const Color(0xffffd16a),
                              ][medal],
                      ),
                      label: Text('${i + 1}'),
                    ),
                  );
                }),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class ScoresPage extends StatelessWidget {
  const ScoresPage(this.game, {super.key});
  final FlightGame game;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: game.profile,
    builder: (context, _) {
      final profile = game.profile;
      return GamePageShell(
        title: 'HIGH SCORES',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final mode in Challenge.values) ...[
              Text(
                mode.label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if ((mode == Challenge.normal
                      ? profile.scores
                      : profile.modeScores[mode]!)
                  .isEmpty)
                const Text('Your first flight starts the leaderboard.'),
              for (final entry
                  in (mode == Challenge.normal
                          ? profile.scores
                          : profile.modeScores[mode]!)
                      .asMap()
                      .entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text('#${entry.key + 1}'),
                  trailing: Text('${entry.value}'),
                ),
              Text('Boss rush best: ${profile.rushBests[mode.name] ?? 0}'),
              const SizedBox(height: 32),
            ],
          ],
        ),
      );
    },
  );
}
