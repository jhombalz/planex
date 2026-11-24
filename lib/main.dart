import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/aircraft.dart';
import 'game/artwork.dart';
import 'game/flight_game.dart';
import 'game/weapon.dart';
import 'services/player_profile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final profile = PlayerProfile(await SharedPreferences.getInstance());
  runApp(PlanexApp(profile: profile));
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
    if (state != AppLifecycleState.resumed) game.pauseFlight();
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
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff86eadc),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xff061725),
      useMaterial3: true,
    ),
    home: PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) game.pauseFlight();
      },
      child: Scaffold(
        body: SafeArea(
          child: GameWidget<FlightGame>(
            game: game,
            overlayBuilderMap: {
              'menu': (context, game) => Hangar(game: game),
              'hud': (context, game) => ValueListenableBuilder<int>(
                valueListenable: game.hudRevision,
                builder: (context, value, child) => Stack(
                  children: [
                    Positioned(
                      bottom: 16,
                      left: game.profile.leftHanded ? null : 16,
                      right: game.profile.leftHanded ? 16 : null,
                      child: Tooltip(
                        message: 'Switch weapon',
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(124, 60),
                            backgroundColor: const Color(0xee091522),
                          ),
                          onPressed: game.combat.availableWeapons.length > 1
                              ? game.cycleWeapon
                              : null,
                          icon: const Icon(Icons.swap_horiz),
                          label: Text(game.combat.weapon.label),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 4,
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
                      child: Semantics(
                        label: '${game.combat.bombs} bombs remaining',
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(112, 60),
                          ),
                          onPressed: game.combat.bombs > 0
                              ? game.useBomb
                              : null,
                          icon: const Icon(Icons.blur_on),
                          label: Text('BOMB ${game.combat.bombs}'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              'debrief': (context, game) => Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              game.combat.victory
                                  ? Icons.emoji_events
                                  : Icons.check_circle_outline,
                              size: 56,
                              color: const Color(0xff86eadc),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              game.combat.victory
                                  ? 'CAMPAIGN COMPLETE'
                                  : 'STAGE ${game.combat.stage} CLEAR',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Score ${game.score}  ·  Lives ${game.combat.lives}',
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Striker unlocked in the hangar.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${Weapon.values[game.combat.stage].label} UNLOCKED',
                              style: const TextStyle(
                                color: Color(0xff86eadc),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              Weapon.values[game.combat.stage].description,
                              textAlign: TextAlign.center,
                            ),
                            if (!game.combat.victory) ...[
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: game.nextStage,
                                child: const Text('Next stage · +1 bomb'),
                              ),
                            ],
                            TextButton(
                              onPressed: game.returnToHangar,
                              child: const Text('Return to hangar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            },
          ),
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
        color: const Color(0xd9061725),
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
                        paused ? 'FLIGHT PAUSED' : 'THREE STAGES. ONE SKY.',
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
                        'BEST  ${profile.highScore}',
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
                            return ChoiceChip(
                              label: Text(
                                locked ? '${plane.label} 🔒' : plane.label,
                              ),
                              selected: profile.selected == plane,
                              onSelected: locked
                                  ? null
                                  : (_) => unawaited(profile.select(plane)),
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
                            'Unlock Striker: 5,000 points or clear stage 1.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xffa7bbc9),
                            ),
                          ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 52),
                          ),
                          onPressed: game.startFlight,
                          child: Text(
                            paused
                                ? 'Resume flight'
                                : game.ended
                                ? 'Fly again'
                                : 'Start flight',
                          ),
                        ),
                      ),
                      if (paused)
                        TextButton(
                          onPressed: game.returnToHangar,
                          child: const Text('End flight and save score'),
                        ),
                      const SizedBox(height: 10),
                      const Text(
                        'Drag anywhere to fly. Collect P for power and B for bombs. Destroy boss turrets to expose the core.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, height: 1.5),
                      ),
                      ExpansionTile(
                        title: Text(
                          'Weapons · ${profile.selectedWeapon.label}',
                        ),
                        tilePadding: EdgeInsets.zero,
                        children: [
                          Wrap(
                            spacing: 6,
                            children: Weapon.values
                                .map(
                                  (weapon) => ChoiceChip(
                                    label: Text(weapon.label),
                                    selected: profile.selectedWeapon == weapon,
                                    onSelected:
                                        weapon.requiredStage <=
                                                profile.clearedStage &&
                                            !paused
                                        ? (_) => unawaited(
                                            profile.selectWeapon(weapon),
                                          )
                                        : null,
                                  ),
                                )
                                .toList(),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Clear stage 1: Laser\nClear stage 2: Homing Missiles\nClear stage 3: Plasma\nSwitch unlocked weapons using the flight button.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      ExpansionTile(
                        title: const Text('Settings & controls'),
                        tilePadding: EdgeInsets.zero,
                        children: [
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
                              'Disable shake, flash and shield blinking',
                            ),
                            value: profile.reducedMotion,
                            onChanged: (value) {
                              profile.reducedMotion = value;
                              unawaited(profile.save());
                            },
                          ),
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
                          if (game.audio.unavailable)
                            const Text(
                              'Audio is unavailable on this device. Gameplay is unaffected.',
                            ),
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
                                    (entry) => ListTile(
                                      dense: true,
                                      leading: Text('#${entry.key + 1}'),
                                      trailing: Text('${entry.value}'),
                                    ),
                                  )
                                  .toList(),
                      ),
                      if (profile.saveFailed)
                        const Text(
                          'Could not save progress. Free some storage and retry.',
                          style: TextStyle(color: Colors.amber),
                        ),
                      if (profile.saveFailed)
                        TextButton(
                          onPressed: profile.save,
                          child: const Text('Retry save'),
                        ),
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
