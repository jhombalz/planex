# Planex

Android portrait arcade shooter built with Flutter and Flame.

## Run

Install Flutter and the Android SDK, connect an Android phone with USB debugging,
then run `flutter pub get` and `flutter run`.

Checks: `flutter analyze`, `flutter test`, `flutter build apk --debug`.

## Development phases

1. **Playable foundation (implemented; device validation pending):** Android shell,
   fixed 360 × 640 playfield, drag-anywhere controls, automatic shooting, basic
   enemies, score, game over/restart, pause button, Android Back pause, lifecycle
   pause. Procedural graphics require no runtime network access.
2. **Combat and survival:** lives, respawn invulnerability, enemy projectiles,
   collision categories, reusable bullet pools, varied waves and difficulty.
3. **Weapons and feedback:** four distinct power levels, pickups, multitouch bomb
   button, explosions, bundled audio, mute controls and audio lifecycle handling.
4. **Stage and boss:** authored stage progression, multipart boss, balanced firing
   patterns, stage-clear flow.
5. **Persistence and presentation:** high scores, plane selection/unlocks,
   original sprites, title screen, settings and accessible controls.
6. **Android release:** physical-device performance and multitouch checks,
   screen-size/inset coverage, interruption testing, release signing and AAB.

Each phase should pass analysis, relevant automated tests, and an Android device
playthrough before being marked complete. Phase 1 is a prototype: collision ends
the run immediately; lives, bombs, audio and persistence arrive in later phases.

`DEVELOPMENT_GUIDE.md` is the original design reference. This roadmap narrows its
scope to Android and records the implementation sequence.

## Phase 1 validation

- Automated tests: projectile scoring/removal and offscreen cleanup passed.
- Android debug APK: built successfully at `build/app/outputs/flutter-apk/app-debug.apk`.
- Physical-device playthrough, touch feel and performance remain unverified.
- Release signing is not configured; the generated template uses debug signing.
