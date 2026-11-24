import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/aircraft.dart';
import 'game/artwork.dart';
import 'game/flight_game.dart';
import 'game/sprite_art.dart';
import 'game/weapon.dart';
import 'services/player_profile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(
    PlanexApp(profile: PlayerProfile(await SharedPreferences.getInstance())),
  );
}

class PlanexApp extends StatefulWidget {
  const PlanexApp({super.key, required this.profile, this.enableAudio = true});
  final PlayerProfile profile;
  final bool enableAudio;
  @override
  State<PlanexApp> createState() => _PlanexAppState();
}

class _PlanexAppState extends State<PlanexApp> with WidgetsBindingObserver {
  late final game = FlightGame(widget.profile, enableAudio: widget.enableAudio);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.profile.addListener(game.settingsChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      game.pauseFlight();
    } else {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.profile.removeListener(game.settingsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff86eadc),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xff061725),
    ),
    home: PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) game.pauseFlight();
      },
      child: Scaffold(
        body: Builder(
          builder: (context) {
            game.topInset = MediaQuery.viewPaddingOf(context).top;
            return GameWidget<FlightGame>(
              game: game,
              overlayBuilderMap: {
                'menu': (context, game) => SafeArea(child: Hangar(game: game)),
                'hud': (context, game) => SafeArea(
                  child: ValueListenableBuilder<int>(
                    valueListenable: game.hudRevision,
                    builder: (context, value, child) => Stack(
                      children: [
                        Positioned(
                          top: 4,
                          right: 8,
                          child: IconButton.filledTonal(
                            tooltip: 'Pause flight',
                            onPressed: game.pauseFlight,
                            icon: const Icon(Icons.pause, size: 28),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: game.profile.leftHanded ? 16 : null,
                          right: game.profile.leftHanded ? null : 16,
                          child: Badge.count(
                            count: game.combat.bombs,
                            child: IconButton.filled(
                              key: const Key('bomb-button'),
                              tooltip: 'Use bomb',
                              style: IconButton.styleFrom(
                                minimumSize: const Size(64, 64),
                              ),
                              onPressed: game.combat.canUseBomb
                                  ? game.useBomb
                                  : null,
                              icon: const SpriteIcon('bomb', size: 38),
                            ),
                          ),
                        ),
                        if (game.combat.weapon != Weapon.pulse)
                          Positioned(
                            bottom: 22,
                            left: game.profile.leftHanded ? null : 18,
                            right: game.profile.leftHanded ? 18 : null,
                            child: Semantics(
                              label:
                                  '${game.combat.weapon.label} bonus, ${game.combat.bonusTime.ceil()} seconds',
                              child: SizedBox.square(
                                dimension: 54,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value: (game.combat.bonusTime / 18).clamp(
                                        0,
                                        1,
                                      ),
                                      strokeWidth: 3,
                                      color: game.combat.bonusTime <= 3
                                          ? const Color(0xffff786f)
                                          : const Color(0xffffd16a),
                                    ),
                                    SpriteIcon(
                                      SpriteArt.weaponSprite(
                                        game.combat.weapon,
                                      ),
                                      size: 28,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                'debrief': (context, game) => SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.emoji_events_outlined,
                                  size: 52,
                                  color: Color(0xff86eadc),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  game.combat.victory
                                      ? 'CAMPAIGN COMPLETE'
                                      : 'LEVEL ${game.combat.stage} CLEAR',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Score ${game.score} · Lives ${game.combat.lives}',
                                ),
                                if (game.combat.stage == 1) ...[
                                  const AircraftPreview(Aircraft.striker),
                                  const Text(
                                    'STRIKER UNLOCKED',
                                    style: TextStyle(
                                      color: Color(0xffffb86b),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    'Bronze fighter · amber weapon effects\nEquipped automatically for level 2',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (!game.combat.victory)
                                      IconButton.filled(
                                        tooltip: 'Next level',
                                        onPressed: game.nextStage,
                                        icon: const Icon(Icons.double_arrow),
                                        iconSize: 34,
                                      ),
                                    const SizedBox(width: 16),
                                    IconButton.outlined(
                                      tooltip: 'Return to hangar',
                                      onPressed: game.returnToHangar,
                                      icon: const Icon(Icons.home_outlined),
                                      iconSize: 30,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              },
            );
          },
        ),
      ),
    ),
  );
}

class Hangar extends StatelessWidget {
  const Hangar({super.key, required this.game});
  final FlightGame game;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: game.profile,
    builder: (context, child) {
      final profile = game.profile;
      final paused = game.started && !game.ended;
      return ColoredBox(
        color: const Color(0xe0061725),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'PLANEX',
                        style: TextStyle(
                          fontSize: 34,
                          letterSpacing: 7,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        paused ? 'FLIGHT PAUSED' : 'PULSE. COLLECT. SURVIVE.',
                        style: const TextStyle(
                          fontSize: 11,
                          letterSpacing: 2,
                          color: Color(0xff86eadc),
                        ),
                      ),
                      if (game.ended)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text('Flight complete · Score ${game.score}'),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        'BEST ${profile.highScore}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!paused) ...[
                        AircraftPreview(profile.selected),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: Aircraft.values.map((plane) {
                            final locked =
                                plane == Aircraft.striker &&
                                !profile.strikerUnlocked;
                            return Tooltip(
                              message: locked
                                  ? 'Reach level 2 to unlock Striker'
                                  : plane.description,
                              child: ChoiceChip(
                                avatar: SpriteIcon(plane.name, size: 24),
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
                        const SizedBox(height: 8),
                        Text(
                          profile.selected.description,
                          textAlign: TextAlign.center,
                        ),
                        if (!profile.strikerUnlocked)
                          const Text(
                            'Reach level 2 to unlock the bronze Striker.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xffa7bbc9),
                            ),
                          ),
                      ],
                      const SizedBox(height: 16),
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
                              minimumSize: const Size(64, 64),
                            ),
                            onPressed: game.startFlight,
                            icon: Icon(
                              game.ended ? Icons.replay : Icons.play_arrow,
                              size: 38,
                            ),
                          ),
                          if (paused) ...[
                            const SizedBox(width: 16),
                            IconButton.outlined(
                              tooltip: 'End flight and save score',
                              onPressed: game.returnToHangar,
                              icon: const Icon(Icons.home_outlined),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Pulse is your default weapon. Collect weapon drops for an 18-second bonus. P multiplies your fire: up to 4 laser beams. Rapid kills earn extra drops.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, height: 1.5),
                      ),
                      ExpansionTile(
                        title: const Text('Settings & controls'),
                        tilePadding: EdgeInsets.zero,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Mute audio'),
                            value: profile.muted,
                            onChanged: (v) {
                              profile.muted = v;
                              unawaited(profile.save());
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Reduce motion'),
                            subtitle: const Text(
                              'Disable shake, flash and shield blinking',
                            ),
                            value: profile.reducedMotion,
                            onChanged: (v) {
                              profile.reducedMotion = v;
                              unawaited(profile.save());
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Bomb button on left'),
                            value: profile.leftHanded,
                            onChanged: (v) {
                              profile.leftHanded = v;
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
                            onChanged: (v) {
                              profile.sensitivity = v;
                              unawaited(profile.save());
                            },
                          ),
                          if (game.audio.unavailable)
                            const Text('Audio is unavailable on this device.'),
                        ],
                      ),
                      ExpansionTile(
                        title: const Text('High scores'),
                        tilePadding: EdgeInsets.zero,
                        children: profile.scores.isEmpty
                            ? [
                                const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'Your first flight starts the leaderboard.',
                                  ),
                                ),
                              ]
                            : profile.scores
                                  .asMap()
                                  .entries
                                  .map(
                                    (e) => ListTile(
                                      dense: true,
                                      leading: Text('#${e.key + 1}'),
                                      trailing: Text('${e.value}'),
                                    ),
                                  )
                                  .toList(),
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
      );
    },
  );
}
