import 'dart:async';

import 'package:flutter/material.dart';

import '../game/campaign.dart';
import '../game/flight_game.dart';
import 'arcade_glyph.dart';

void showFlightGuide(
  BuildContext context,
  FlightGame game, {
  VoidCallback? onFinish,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => _FlightGuide(game, onFinish),
  );
}

class _FlightGuide extends StatefulWidget {
  const _FlightGuide(this.game, this.finish);
  final FlightGame game;
  final VoidCallback? finish;
  @override
  State<_FlightGuide> createState() => _FlightGuideState();
}

class _FlightGuideState extends State<_FlightGuide> {
  int page = 0;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(const ['FLY', 'COLLECT', 'DODGE'][page]),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ArcadeGlyph(
          [GameAction.play, GameAction.resume, GameAction.practice][page],
          size: 64,
        ),
        const SizedBox(height: 18),
        Text(
          const [
            'Drag anywhere to move. Weapons fire automatically. Tap the bomb icon with a second finger to clear danger.',
            'Pulse is your default. Collect P for stronger volleys and gold-ring drops for temporary Laser, Missiles or Plasma. Move close to attract pickups.',
            'Orange lines show where shots will fire. Destroy boss turrets to expose the core. Pause when needed; practice never affects your records.',
          ][page],
        ),
        const SizedBox(height: 12),
        Text('${page + 1} / 3'),
      ],
    ),
    actions: [
      IconButton.filled(
        tooltip: page == 2 ? 'Begin flight' : 'Next tip',
        icon: ArcadeGlyph(page == 2 ? GameAction.play : GameAction.next),
        onPressed: () {
          if (page < 2) {
            setState(() => page++);
            return;
          }
          widget.game.profile.tutorialSeen = true;
          unawaited(widget.game.profile.save());
          Navigator.pop(context);
          widget.finish?.call();
        },
      ),
    ],
  );
}

void showPracticePicker(BuildContext context, FlightGame game) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('PRACTICE LEVEL'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'No leaderboard scores, achievements or checkpoint changes.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(
              campaign.length,
              (i) => Tooltip(
                message: campaign[i].name,
                child: Badge(
                  label: Text('${i + 1}'),
                  child: IconButton.filledTonal(
                    tooltip: 'Practice level ${i + 1}',
                    onPressed: i <= game.profile.clearedStage
                        ? () {
                            Navigator.pop(context);
                            game.startPractice(i + 1);
                          }
                        : null,
                    icon: const ArcadeGlyph(GameAction.practice, size: 30),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class V2HangarPanel extends StatelessWidget {
  const V2HangarPanel(this.game, {super.key});
  final FlightGame game;
  @override
  Widget build(BuildContext context) {
    final profile = game.profile;
    return Column(
      children: [
        Text(
          profile.mode.label,
          style: const TextStyle(
            color: Color(0xffffcf78),
            fontWeight: FontWeight.bold,
          ),
        ),
        Wrap(
          spacing: 8,
          children: Challenge.values
              .map(
                (mode) => Tooltip(
                  message: mode.label,
                  child: ChoiceChip(
                    selected: profile.mode == mode,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        mode.index + 1,
                        (_) => const Icon(Icons.star, size: 15),
                      ),
                    ),
                    onSelected: (_) => unawaited(profile.selectMode(mode)),
                  ),
                ),
              )
              .toList(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (profile.checkpoint != null)
              IconButton.outlined(
                tooltip: 'Continue checkpoint',
                onPressed: game.continueCheckpoint,
                icon: const ArcadeGlyph(GameAction.resume),
              ),
            IconButton.outlined(
              tooltip: 'Practice',
              onPressed: () => showPracticePicker(context, game),
              icon: const ArcadeGlyph(GameAction.practice),
            ),
            IconButton.outlined(
              tooltip: 'Tutorial',
              onPressed: () => showFlightGuide(context, game),
              icon: const ArcadeGlyph(GameAction.help),
            ),
          ],
        ),
        if (profile.checkpoint != null)
          Text(
            'Checkpoint: level ${profile.checkpoint!.stage} · ${profile.checkpoint!.mode.label}',
            style: const TextStyle(fontSize: 12),
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            'Achievements ${profile.achievements.length}/${Achievement.values.length}',
          ),
          children: Achievement.values
              .map(
                (a) => ListTile(
                  dense: true,
                  leading: Icon(
                    profile.achievements.contains(a.name)
                        ? Icons.verified
                        : Icons.lock_outline,
                    color: profile.achievements.contains(a.name)
                        ? const Color(0xffffcf78)
                        : null,
                  ),
                  title: Text(a.title),
                  subtitle: Text(a.description),
                ),
              )
              .toList(),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Campaign records'),
          children: [
            Wrap(
              spacing: 6,
              children: List.generate(campaign.length, (i) {
                final medal = profile.medals['${profile.mode.name}:${i + 1}'];
                return Tooltip(
                  message: campaign[i].name,
                  child: Chip(
                    avatar: Icon(
                      medal == null
                          ? Icons.radio_button_unchecked
                          : Icons.workspace_premium,
                      color: medal == 2
                          ? const Color(0xffffd16a)
                          : medal == 1
                          ? const Color(0xffbfcbd8)
                          : const Color(0xffb48762),
                      size: 18,
                    ),
                    label: Text('${i + 1}'),
                  ),
                );
              }),
            ),
            Text(
              'Campaign clears: ${profile.completions[profile.mode.name] ?? 0}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ],
    );
  }
}
