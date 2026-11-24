# Planex

An offline Android vertical arcade shooter built with Flutter and Flame.

## Download for Android

[**Download Phases 3–5 APK (v0.5.1)**](https://github.com/jhombalz/planex/releases/download/v0.5.1-phase5/planex-v0.5.1.apk)

Open the link on your phone, download the APK, then open it to install. Allow
installation from your browser if Android prompts. You can install this over the
previous Planex test build from this repository.

This is an optimized test build using development debug signing. Physical-device
performance, audio interruptions and production signing are part of Phase 6.

Earlier builds: [Phase 2](https://github.com/jhombalz/planex/releases/download/v0.2.0-phase2/planex-phase2.apk)
· [Phase 1](https://github.com/jhombalz/planex/releases/download/v0.1.0-phase1/planex-phase1-debug.apk)
· [All releases](https://github.com/jhombalz/planex/releases)

## Play

- Drag anywhere in the playfield to steer. Weapons fire automatically.
- Tap **BOMB** with a second finger to clear enemy bullets and damage enemies.
  Bombs grant temporary protection; you start with two and can carry five.
- Collect **P** for four weapon levels: single, twin, spread and five-way fire.
  Collect **B** to replenish bombs. Maxed-out pickups award bonus points.
- You have three lives. Respawning grants a two-second shield and costs one
  power level. Clear a stage to receive another bomb.
- Survive the authored 45-second approach, destroy both boss turrets, then attack
  the exposed core. Clear Coral Approach, Iron Harbor and Storm Citadel to win.
- Pause with the top-right button or Android Back. App interruptions pause the
  flight; tap **Resume flight** to continue.

The hangar includes the five best scores, plane selection and settings. **Swift**
is agile; **Striker** starts at power 2 and handles more slowly. Unlock Striker by
earning 5,000 points in a run or clearing stage 1. Unlocks, completed/ended-run
scores, plane choice, mute, reduced motion, button side and sensitivity save
locally. In-progress flights are not restored after the app process closes.

All artwork is original vector art rendered in code. The bundled soundtrack and
effects are original synthesized audio. Gameplay requires no network connection.

## Development phases

| Phase | Scope | Status |
| --- | --- | --- |
| 1 | Android foundation, movement, shooting, pause/restart | Implemented |
| 2 | Lives, enemy bullets, wave patterns, bullet pooling | Implemented |
| 3 | Four weapon levels, pickups, multitouch bombs, effects, audio/mute | Implemented |
| 4 | Three authored stages, multipart bosses, shielded cores, stage-clear/victory | Implemented |
| 5 | High scores, plane unlock/selection, original artwork, hangar/settings | Implemented |
| 6 | Physical-device testing, balancing/performance, production signing and AAB | Pending |

Implemented phases still require physical-device acceptance testing. Current
automated checks cover combat and campaign rules, saves and malformed-data
recovery, multitouch steering/bombs, lifecycle pause and stage-clear/victory UI.
Native audio playback and device performance are not verified by widget tests.

Validation for v0.5.1: `flutter analyze` passed, all 24 automated tests passed,
and the optimized Android APK built successfully.

## Run and verify

Install Flutter and the Android SDK, connect a phone with USB debugging, then:

```sh
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --release
```

The APK is generated at `build/app/outputs/flutter-apk/app-release.apk`.
Release mode currently uses the development signing key; configure production
signing before distribution beyond testing.

Regenerate bundled audio with `dart tool/generate_audio.dart`. See
`assets/LICENSE.txt` for asset provenance. `DEVELOPMENT_GUIDE.md` remains the
original design reference; this roadmap records the Android implementation.
