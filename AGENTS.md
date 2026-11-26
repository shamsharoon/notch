# Notch fork: agent notes

This is the user's personal fork of boring.notch (GPL-3.0). Read `SPEC.md` first; it defines v1. `PLAN.md` says where work stopped.

Build: open `boringNotch.xcodeproj` in Xcode, or use `xcodebuild`. This needs full Xcode, not just Command Line Tools.

Use pstack: start work with `/pstack:poteto-mode`.

## features.json rules
- Only change `passes`. Never delete, reword, or reorder features without asking the user.
- Set `passes: true` only after the steps were run for real (browser test or by hand) and the proof is in the plan's Decision Log.

"Done" for v1 means every feature in `features.json` passes.

## Hard rules
- Never save, send, or log app audio. The Mixer adds no network code.
- Never tap an app that is at 100% and not muted.
- Keep Sparkle updates off, so upstream releases never replace this fork.
- Don't push to `origin` (it is upstream TheBoredTeam). Ask the user before creating a GitHub fork or remote.
- Sound checks need the user's ears. Ask them to run the steps and report back. A passing build is not proof.
- Keep Mixer code in its own folder (`boringNotch/Mixer/`), so upstream changes merge cleanly.
