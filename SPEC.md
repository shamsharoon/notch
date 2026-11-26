# Notch (personal fork of boring.notch)

## Goal
The user's own notch app, forked from boring.notch: music controls in the notch (as boring.notch already has), plus a per-app volume **Mixer**. The Mixer is a tab in the notch, and the same sliders also open from the app's menu bar icon.

## Users and job
One user, on their own Mac. The job: control music and balance each app's volume (game, calls, music, Discord) from the notch, without touching the system volume.

## Main flow
1. Hover over (or click) the notch. It opens on the Home tab: now playing, album art, play/pause/skip.
2. Click the new **Mixer** tab (next to Home and Shelf).
3. See every app that uses sound, playing apps first with a green dot.
4. Drag an app's slider (0–100%). Only that app gets quieter, right away. Click its speaker button to mute.
5. Move the pointer away. The notch closes and the volumes stay applied.
6. Other way in: click the app's menu bar icon. A small panel shows the same Mixer sliders, plus Settings, Restart and Quit buttons.
7. First time only: macOS asks for "System Audio Recording" permission. The user clicks Allow. If it's denied, the Mixer shows a short message saying where to turn it on.

## Out of scope
- Making an app louder than 100%.
- Sending different apps to different speakers or headphones.
- Presets, profiles and keyboard shortcuts for the Mixer.
- Microphone or any input levels.
- Separate volumes for each output device.
- Publishing: no signed release, no auto-updates, no pull requests back to boring.notch.
- New features for the other notch parts (shelf, calendar, webcam, battery). They stay as they are and must keep working.
- The standalone `~/Code/mixer` app. It is retired; its code moves in here.

## Data
- Per-app volume (0–1) and muted state, keyed by bundle ID (for example `com.hnc.Discord`). Stored with the app's existing settings library (`Defaults`, which uses `UserDefaults`) on this Mac. Kept until the user changes it; an app set back to 100% is removed.
- Everything boring.notch already stores (settings, shelf items) stays as it is.
- Audio is never stored. It only passes from the app to the speakers in memory.

## Services
- No new outside services and no keys.
- Sparkle auto-update must be turned off. It currently points at upstream's `appcast.xml` and would replace this fork with the official app.
- boring.notch's existing network use (album art, lyrics and similar) stays. The Mixer adds no network code.
- macOS permission needed: System Audio Recording (`NSAudioCaptureUsageDescription`).
- Build tool: **full Xcode is required** (an `.xcodeproj` with Swift packages and an XPC helper). This Mac has only Command Line Tools, so the user must install Xcode first.

## Done when
- [ ] The fork builds in Xcode and runs as its own app (its own name and bundle ID). It can run while the official Boring Notch is not installed, and it never offers upstream updates.
- [ ] Music controls in the notch work with Apple Music and Spotify: title, artwork, play/pause, next, previous.
- [ ] The Mixer tab and the menu bar panel both show the same apps and the same volumes, and changes in one appear in the other.
- [ ] Four apps (a game, a call app, a music app, Discord) play at four different volumes at the same time, and each sounds right.
- [ ] Turned-down apps sound clean, with no pops, crackles or delay during a 30-minute game or call.
- [ ] Volumes come back after an app restarts, after the notch app restarts, and after a reboot.
- [ ] Volumes stay correct when switching between speakers, wired headphones and AirPods.
- [ ] Quitting or force-killing the notch app leaves no app silent.
- [ ] Apps at 100% are never tapped.
- [ ] Every entry in `features.json` has `passes: true`.

## Risks
- **Private data:** the Mixer can read app audio, including calls. It must never save it, send it, or keep it beyond the current buffer.
- **Sandbox:** boring.notch is sandboxed (`boringNotch/boringNotch.entitlements`). Process taps and private aggregate devices are not proven to work inside the sandbox. Test this first. If they fail, the fallback is turning the sandbox off for this personal build (record the choice in the Decision Log).
- **Silence:** a broken tap mutes an app. Quitting or crashing must undo it. Test with `kill -9`.
- **Upstream updates:** if Sparkle stays on, the fork can be overwritten. Turn it off before the first run.
- **Bundle ID clash:** both the app and the XPC helper use `theboringteam.boringnotch…`. Change both, or the fork collides with the real app's settings and permissions.
- **License:** boring.notch is GPL-3.0. That's fine for personal use. If the user ever shares it, the source must stay GPL-3.0 and credit upstream.
- **No money and no deleting involved.**

## Findings
- Fork source: `~/Code/boring-notch`, cloned from `TheBoredTeam/boring.notch` at `b7611bb` (2026-10-31). `origin` still points at upstream. Nothing has been pushed.
- Build: `boringNotch.xcodeproj` (objectVersion 70, so a recent Xcode), Swift 5 mode, macOS 14.0 target. Swift packages: Defaults, KeyboardShortcuts, LaunchAtLogin-Modern, Sparkle, Lottie, Pow, SkyLightWindow, MacroVisionKit, swiftui-introspect, swift-collections, AsyncXPCConnection. `xcodebuild` fails here: "requires Xcode".
- Tabs: `NotchViews` enum (`home`, `shelf`) in `boringNotch/enums/generic.swift`; the `tabs` list in `boringNotch/components/Tabs/TabSelectionView.swift`; the switch on the current view in `boringNotch/ContentView.swift` (about line 350). A Mixer tab means one enum case, one `TabModel`, and one switch case.
- Menu bar: `MenuBarExtra("boring.notch", systemImage: "sparkle")` in `boringNotch/boringNotchApp.swift:32` uses the default menu style (Settings, Check for Updates, Restart, Quit). Sliders need `.menuBarExtraStyle(.window)`, so those buttons move into the panel. `boringNotch/menu/StatusBarMenu.swift` looks unused.
- Music: `boringNotch/managers/MusicManager.swift`, `boringNotch/MediaControllers/` (Apple Music, Spotify, YouTube Music, Now Playing) and `mediaremote-adapter/`. `boringNotch/managers/VolumeManager.swift` handles system volume only.
- Updates: `SUFeedURL` = `https://TheBoredTeam.github.io/boring.notch/appcast.xml` in `boringNotch/Info.plist`.
- Mixer code to move in, from `~/Code/mixer/Sources/Mixer/` (commit `7d60f45`): `CoreAudioHelpers.swift`, `AudioAppScanner.swift` (groups helper processes by responsible PID, then bundle prefix), `AppVolumeTap.swift` (process tap with `.mutedWhenTapped` plus a private aggregate device and a gain callback), `MixerModel.swift` (saved volumes, taps only below 100%, follows output changes), `MixerView.swift` (rows: icon, name, dot, percent, slider, mute). It builds standalone but has not been tested by ear.
- Agent tooling: official pstack 0.15.48 is installed in Claude Code (`pstack@cursor-plugins`), so `/pstack:poteto-mode` works.
