# Planex

Android portrait arcade shooter built with Flutter and Flame.

## Download for Android

[**Download Phase 2 APK**](https://github.com/jhombalz/planex/releases/download/v0.2.0-phase2/planex-phase2.apk)

Test builds are published as prereleases. Open [all builds](https://github.com/jhombalz/planex/releases)
and download the APK under **Assets**. On your phone, open the APK and allow
installation from your browser when Android prompts. These builds use debug signing.

- [Phase 1 APK](https://github.com/jhombalz/planex/releases/download/v0.1.0-phase1/planex-phase1-debug.apk)

## Run

Install Flutter and the Android SDK, connect an Android phone with USB debugging,
then run `flutter pub get` and `flutter run`.

Checks: `flutter analyze`, `flutter test`, `flutter build apk --release`.
The Phase 2 download is optimized in release mode but uses the development debug
signing key for testing. Production signing is planned for Phase 6.

## Development phases

1. **Playable foundation (implemented; device validation pending):** Android shell,
   fixed 360 × 640 playfield, drag-anywhere controls, automatic shooting, basic
   enemies, score, game over/restart, pause button, Android Back pause, lifecycle
   pause. Procedural graphics require no runtime network access.
2. **Combat and survival (implemented; device validation pending):** lives, respawn invulnerability, enemy projectiles,
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
playthrough before being marked complete. Phase 2 adds three lives and a two-second
shield at launch and after respawn. Straight, sine and hovering turret waves rotate;
difficulty increases every 25 seconds up to level 6. Enemy bullets are gold.
Bombs, audio and persistence arrive in later phases.

`DEVELOPMENT_GUIDE.md` is the original design reference. This roadmap narrows its
scope to Android and records the implementation sequence.

## Phase 1 validation

- Automated tests: projectile scoring/removal and offscreen cleanup passed.
- Android debug APK: built successfully at `build/app/outputs/flutter-apk/app-debug.apk`.
- Physical-device playthrough, touch feel and performance remain unverified.
- Release signing is not configured; the generated template uses debug signing.

## Phase 2 validation

- Analysis: passed without issues.
- Nine combat tests passed: scoring, lives, shield expiry, projectile ownership,
  pool reuse/capacity, cleanup, wave rotation/difficulty, enemy fire/movement and restart.
- Optimized Android test APK built successfully (about 43 MB).
- Physical-device playthrough and sustained performance remain unverified.
