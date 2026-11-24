import 'dart:async';

import 'package:flutter/material.dart';

import '../game/campaign.dart';
import '../game/flight_game.dart';
import 'arcade_glyph.dart';
export 'menu_pages.dart';
import 'menu_pages.dart';

void showFlightGuide(
  BuildContext context,
  FlightGame game, {
  VoidCallback? onFinish,
}) {
  openGamePage(context, _FlightGuide(game, onFinish));
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
  Widget build(BuildContext context) => GamePageShell(
    title: 'FLIGHT GUIDE',
    footer: [
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
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          const ['FLY', 'COLLECT', 'DODGE'][page],
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        ArcadeGlyph(
          [GameAction.play, GameAction.resume, GameAction.practice][page],
          size: 64,
        ),
        const SizedBox(height: 18),
        Text(
          const [
            'Drag anywhere to move. Weapons fire automatically. Tap the bomb icon with a second finger to clear danger.',
            'Pulse is your default. Collect P for stronger volleys and gold-ring drops for temporary Laser, Missiles, Plasma or Spread. Move close to attract pickups.',
            'Orange lines show where shots will fire. Destroy boss turrets to expose the core. Pause when needed; practice never affects your records.',
          ][page],
        ),
        const SizedBox(height: 12),
        Text('${page + 1} / 3'),
      ],
    ),
  );
}

void showPracticePicker(BuildContext context, FlightGame game) {
  openGamePage(
    context,
    GamePageShell(
      title: 'PRACTICE LEVEL',
      child: Column(
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

class StageRewards extends StatelessWidget {
  const StageRewards(this.game, {super.key});
  final FlightGame game;
  @override
  Widget build(BuildContext context) {
    final medal = game.combat.medal;
    final color = switch (medal) {
      Medal.gold => const Color(0xffffd16a),
      Medal.silver => const Color(0xffbfcbd8),
      Medal.bronze => const Color(0xffb48762),
    };
    return Column(
      children: [
        const SizedBox(height: 12),
        Icon(Icons.workspace_premium, size: 44, color: color),
        Text(
          '${medal.name.toUpperCase()} MEDAL',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        Text(
          game.combat.rankedCampaign
              ? 'Best medal saved for this difficulty'
              : 'Session result only',
          style: const TextStyle(fontSize: 12),
        ),
        for (final reward in game.earnedRewards)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(Icons.verified, color: Color(0xffffd16a), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reward,
                    style: const TextStyle(color: Color(0xffffd16a)),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
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
            IconButton.outlined(
              tooltip: profile.bossRushUnlocked
                  ? 'Boss rush'
                  : 'Clear campaign to unlock boss rush',
              onPressed: profile.bossRushUnlocked ? game.startBossRush : null,
              icon: const Icon(Icons.local_fire_department_outlined),
            ),
          ],
        ),
        if (profile.bossRushUnlocked)
          Text(
            'Boss rush best: ${profile.rushBests[profile.mode.name] ?? 0}',
            style: const TextStyle(fontSize: 12),
          ),
        if (profile.checkpoint != null)
          Text(
            'Checkpoint: level ${profile.checkpoint!.stage} Â· ${profile.checkpoint!.mode.label}',
            style: const TextStyle(fontSize: 12),
          ),
      ],
    );
  }
}
