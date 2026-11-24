# Stable v2 release checklist

The v2.0.0-rc.1 APK is a development-signed test candidate. Feature implementation
and automated checks do not establish physical-phone acceptance.

## Phone acceptance

- [ ] Install over v0.9.0 without uninstalling; confirm scores/settings/planes remain.
- [ ] Check launcher, round/adaptive icon crop and splash in light/dark mode.
- [ ] Verify fullscreen, cutouts, Android Back and pause/resume after app switching.
- [ ] Test two-finger steering/bombing, both handedness settings and sensitivity.
- [ ] Test audio, mute, interruption recovery and extended playback on hardware.
- [ ] Play all six stages in each difficulty; assess aces, readable warnings,
  boss phases, pickup frequency, aircraft perks and the difficulty curve.
- [ ] Kill the app after reaching a checkpoint; Continue must restart the saved level.
- [ ] Confirm practice cannot affect scores, medals, unlocks or checkpoints.
- [ ] Play at least 15 minutes on a lower-end and recent Android phone; record
  frame timing, memory, heat and battery behavior. Headless soak results are separate.

Record device/Android version, mode, stage, reproduction steps and results for each
problem before promoting the candidate to stable.

## Production signing and distribution

1. Create and securely back up the owner's production keystore outside this repo.
2. Copy `android/key.properties.example` to ignored `android/key.properties`; fill
   actual keystore path, alias and secrets locally. Never commit them.
3. Use Gradle property `productionRelease=true` (for example, set
   `ORG_GRADLE_PROJECT_productionRelease=true` in a build-only shell), then run
   `flutter build appbundle --release`. This property makes missing signing
   configuration fail instead of falling back to development signing.
4. Verify package ID, version code, signing certificate, release artifact and install
   flow. Keep future updates on the same production signing identity.
5. A differently signed production build cannot replace a development-signed APK
   directly. Plan the tester transition before distribution; uninstalling removes
   local data. Cross-signature data transfer is not implemented.
6. Complete store listing, screenshots, content rating and applicable store forms,
   then publish through the owner's account after device acceptance.

No production key or store credentials are included. Candidates retain the existing
development signature for compatibility with earlier test builds.
