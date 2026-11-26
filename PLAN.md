# Notch (personal boring.notch fork)

Goal: the user's own notch app with music controls, plus a per-app volume Mixer as a notch tab and in the menu bar icon's panel.

Active plan: [docs/plans/active/2026-11-26-v1.md](docs/plans/active/2026-11-26-v1.md)

## Where I stopped
Mixer polish done: battery UI hidden on Macs with no battery (`ea4b038`), only apps making sound are listed (`03d1d86`), menu bar icon `slider.horizontal.3` (`084a44a`), new row look and micro-interactions (`afbc0b9`). Checked in a harness that hosts the real Mixer views (`build/ui-test/`), not yet in the live notch: the shell cannot open it. The rebuilt Notch is frozen until open macOS permission prompts are answered (see the plan's Surprises).

## Next action
Answer the open macOS prompts (then allow Notch for System Audio Recording if asked), open the notch's Mixer tab, and try hover, a drag to the top, mute, and a double-click on the percent.

## Backlog
Own GitHub fork (ask first) · custom app icon · pull upstream updates by hand · start and stop taps off the main thread · sign Debug builds with a stable identity so permissions survive rebuilds
