import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/flight_game.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const PlanexApp());
}

class PlanexApp extends StatefulWidget {
  const PlanexApp({super.key});
  @override
  State<PlanexApp> createState() => _PlanexAppState();
}

class _PlanexAppState extends State<PlanexApp> with WidgetsBindingObserver {
  final game = FlightGame();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) game.pauseFlight();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) game.pauseFlight();
      },
      child: Scaffold(
        backgroundColor: const Color(0xff061725),
        body: SafeArea(
          child: GameWidget<FlightGame>(
            game: game,
            overlayBuilderMap: {
              'menu': (context, game) => Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'PLANEX',
                          style: TextStyle(fontSize: 36, letterSpacing: 6),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          game.ended
                              ? 'Flight complete • Score ${game.score}'
                              : 'Drag anywhere to fly. Auto-fire enabled.',
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: game.startFlight,
                          child: Text(
                            game.ended
                                ? 'Fly again'
                                : game.started
                                ? 'Resume flight'
                                : 'Start flight',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              'pause': (context, game) => Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: 'Pause flight',
                  onPressed: game.pauseFlight,
                  icon: const Icon(Icons.pause_circle, size: 32),
                ),
              ),
            },
          ),
        ),
      ),
    ),
  );
}
