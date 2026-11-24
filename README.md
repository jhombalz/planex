# Planex

Offline fullscreen Android arcade shooter built with Flutter and Flame.

## Download

[**Download Android APK v0.8.0**](https://github.com/jhombalz/planex/releases/download/v0.8.0-bonus/planex-v0.8.0.apk)

Open the link on your phone, download the APK, then install it. Allow installation
from your browser when Android prompts. It installs over earlier Planex test builds
and retains scores, cleared levels, plane choice and settings. Legacy weapon
selections are ignored: every flight starts with Pulse.

This optimized test build uses development signing. Physical-phone validation of
immersive fullscreen, native audio, balancing and sustained performance is pending.

[All releases](https://github.com/jhombalz/planex/releases) ·
[Previous v0.7.0 APK](https://github.com/jhombalz/planex/releases/download/v0.7.0-sprites/planex-v0.7.0.apk)

## Controls and bonuses

- Drag anywhere to steer. Weapons fire automatically.
- Flight buttons are icons: pause at the top right and bomb near the bottom.
  The bomb badge shows your stock. Buttons retain tooltips/accessibility names.
- Pulse is always the default. Collect a gold-ring weapon drop for **18 seconds**
  of Laser, Homing Missiles or Plasma. Expiry, respawn and a new level restore Pulse.
  The small circular weapon indicator shows remaining bonus time; it is not a switch.
- Bonus drops have a 12% random kill chance, a guaranteed reward every six kills,
  and a reward for four kills within a rolling three-second combo window.
- Collect **P** for power, **B** for bombs. Power stays when a bonus expires.
  Every third kill drops a supply; every ninth kill drops a bomb supply.
- You have three lives. Respawn grants a two-second shield and removes one power
  level. Bombs clear hostile bullets, damage enemies and grant temporary protection.
- Pause also activates on Android Back or an app interruption. Resume explicitly
  with the play icon. Menus use play, next-level, replay and home icon actions.

### P upgrades

| Power | Pulse shots | Laser beams | Homing missiles | Plasma shots |
| --- | --- | --- | --- | --- |
| 1 | 1 | 1 | 1 | 1 |
| 2 | 2 | 2 | 2 | 2 |
| 3 | 3 | 3 | 3 | 3 |
| 4 | 5 | 4 | 4 | 5 |

Laser drawing and damage use the same beam positions. Beams pierce aligned
enemies; multiple overlapping beams do not multiply damage against a single
target in one tick. Power also increases bonus damage/beam width. Maxed pickups
award bonus points.

## Levels and aircraft

Clear Coral Approach, Iron Harbor and Storm Citadel. Each level has an authored
45-second approach followed by a multipart boss. Destroy both turrets to expose
the core. The boss display emphasizes core health/percentage, shield/enraged state
and two smaller turret indicators. Every regular enemy retains its own health bar.

Each level raises enemy health, movement speed, projectile speed and fire rate,
plus boss health and fan-fire frequency. Later levels also have more formations.

Reaching **level 2** permanently unlocks the bronze **Striker**, which is equipped
automatically for that level. It has amber projectile/laser effects and at least
power 2. Swift uses cyan effects and agile handling. Choose unlocked aircraft by
their icons in the hangar for future runs. Weapon bonuses are earned in combat,
not unlocked or selected in the hangar.

## Artwork

Aircraft, bosses, modules, bullets and weapons use bundled transparent PNG sprites
from one cached atlas. Runtime tinting distinguishes aircraft weapon effects.

<img src="assets/images/arcade_atlas.png" width="460" alt="Planex aircraft and projectile sprites">

The atlas was created with built-in imagegen using the supplied arcade screenshot
as a style reference. See the [prompt](assets/ART_PROMPT.txt),
[sprite index](assets/images/arcade_atlas.json) and [asset provenance](assets/LICENSE.txt).
Scenery and explosions are rendered in code; audio is synthesized and bundled.

## Development status and verification

Phases 1–5 are implemented. Phase 6 remains: device acceptance testing,
balancing/performance, production signing and AAB preparation.

For v0.8.0, analysis and all **39 automated tests** passed. Tests cover combat,
bonus collection/expiry, combo rewards, multibeam damage, P volley upgrades,
legacy-save migration, level-2 unlocks, icon controls, viewport sizing and pause.
Phone-sized rendering was inspected. Native system bars and audio still require
physical-device verification.

```sh
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --release
```

APK: `build/app/outputs/flutter-apk/app-release.apk`.
Audio generator: `dart tool/generate_audio.dart`.
`DEVELOPMENT_GUIDE.md` is the original design reference; this README describes the
current Android implementation. In-progress runs do not survive process exit.
