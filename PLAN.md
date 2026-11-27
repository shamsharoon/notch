# Notch (personal boring.notch fork)

Goal: the user's own notch app with music controls, plus a per-app volume Mixer as a notch tab and in the menu bar icon's panel.

Active plan: [docs/plans/active/2026-11-26-v1.md](docs/plans/active/2026-11-26-v1.md)

## Where I stopped
Mixer polish done: battery UI hidden on Macs with no battery (`ea4b038`), only apps making sound are listed (`03d1d86`), menu bar icon `slider.horizontal.3` (`084a44a`), new row look and micro-interactions (`afbc0b9`). Checked in a harness that hosts the real Mixer views (`build/ui-test/`), not yet in the live notch: the shell cannot open it. Taps now start and stop off the main thread, so a pending permission prompt no longer freezes the notch or hangs quit (quit takes about 1 s while a tap is stuck). Taps still won't change any volume until the prompts are answered. A looping README demo of the Mixer is in `demo/` (`demo/mixer-demo.mp4`). Published 2026-11-27: public repo github.com/shamsharoon/notch, release `notch-v1.0.0` with `Notch.zip` (Release build, both chips, self-signed, not notarized, so users click Open Anyway). Commit emails rewritten to the GitHub noreply address; repo Actions turned off so upstream CI doesn't run here.

## Next action
Answer the open macOS prompts (then allow Notch for System Audio Recording if asked), open the notch's Mixer tab, and try hover, a drag to the top, mute, and a double-click on the percent.

## Backlog
custom app icon · pull upstream updates by hand · Apple Developer ID + notarization so downloads open without Open Anyway · stop Dependabot PRs on the fork (`.github/dependabot.yml`)
