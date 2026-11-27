# Rehearsal: Notch Mixer demo

Gold: `dynamic-island`. Kept its core: one black shape whose box springs between presentations (a small overshoot opening, critically damped closing, the close held 120 ms so content clears first), with content on its own layer that blurs out fast and sharpens in once the shape is mostly there. Changed: the iPhone became the top of a Mac screen (menu bar, dark slate desktop); the island's geometry became the notch's real geometry from `sizing/matters.swift` (640 × 190 open, 19 pt top fillets, 24 pt bottom corners, the app's own spring values); touch became the macOS pointer; the Live Activity became Notch's Home and Mixer views. The pointer beats (target, press, then state) follow `hero-demo`.

Beats, loop 14.5 s (times are the recorded `act.mark` frames):
1. 0.50 s: the pointer goes up to the closed notch, where a song is playing (cover thumbnail and spectrum).
2. 1.45 s: the notch springs open on Home. The cover grows from the thumbnail into the 110 pt art.
3. 3.42 s: click the Mixer tab. The capsule slides over and the rows rise in 40 ms apart.
4. 5.42 s: drag Chrome's slider from 100% to 30%. The track goes 4 → 6 pt on hover and 8 pt while dragging, and the percent brightens.
5. 7.88 s: click Discord's speaker. Its row dims to 45% and the icon swaps to the slash.
6. Payoff (the poster), held 2 s after the pointer moves off the controls: Discord muted, Chrome at 30%, Music at 100%.
7. 10.68 s: double-click Chrome's "30%". It rolls back to 100% and the fill eases back.
8. About 11.9 s: click Discord's speaker again to unmute.
9. 13.37 s: the pointer leaves and the notch closes. The tab returns to Home unseen, as the app does on close.

Captured:
- Widths: the shown width (700 × 280 design in a 732 column) and 390 (the compact 358 × 260 design). The final gates also ran at 250 ms density at both widths.
- Looks: dark only. The product is a black notch.
- States: every mark filmed (`--states`, and `--at` close-ups of the tab switch, mute, reset roll, open and close).
- Reduced motion: the poster at 2x (`mixer-demo-poster.png`).
- Video: 1741 frames on the kit's virtual clock, 60 fps, 1400 × 560 (`mixer-demo.mp4`). The last frame matches the first.

Gate (last line of each run on the final code):
- `npm run film` (shown width): `rehearsal passed (necessary, not sufficient: references/verify.md and the fresh eye in review.md still stand)`
- `npm run film:phone` (390): `rehearsal passed (necessary, not sufficient: references/verify.md and the fresh eye in review.md still stand)`

Film lines, and what I did:
- `loose list` on Home. The title, artist and controls read as three spaced rows. Fixed: grouped them into song, progress and controls, as the app's view is built.
- `uneven padding` on the cover. The Music badge sat inside the cover's box. Fixed: the badge is its own element on the corner.
- `uneven inset` at 390. A hovered mute button's circle sat 2 px from the hovered row's top and bottom but 8 px from its right. That is the app's real geometry: 30 pt row, 26 pt button, 8 pt row padding. Fixed: the row's 5% hover fill steps aside while its mute button is hovered, so only one hover surface shows. **This differs from the app, which shows both.**
- Row jumps after the Mixer faded out. Fixed: rows rise in with a CSS animation, and the list fades out as one.
- Fill moving in 3 px steps while dragging. Fixed: the value stays continuous and only the readout rounds, as in the app.
- Leading "1" popping in on 30% → 100%. Fixed: three digits always, the leading one hidden below 100, so the 1 rolls in with the others (`shots/reset-zoom2.png`).
- Spectrum smudge while the notch closes. Fixed: it waits for the shape to close, with the cover.
- Kept: `settle snap` / `jump` on the slider fill at drag start, about 10 px. This is the app's real snap: values of 97% and up read as 100%, so leaving that zone drops the fill from 100% to 97%.
- Kept: `covers "0"` on the double-click. It measures the hidden leading digit. At 4x the pointer tip sits below-left of "30%" and the 1 rolls in clear of it (`shots/reset-zoom.png`).
- Kept: `near-empty frames` for about 2.4 s at the seam. That is the closed notch, the loop's opening beat.
- Kept: `settle snap` of 100 px on a `span`. That is `Count` re-centering its digit strip after a roll, which draws the same glyph.
- Coverage reads "inconclusive" on every run: headless Chrome on this Mac misses 27 ms frame deadlines by up to 43 ms. The gate still ends passed.

Review: no fresh-eye reviewer ran, because the brief said no subagents. I checked my own stills against `dynamic-island` and `references/verify.md`.

Assumptions:
- The song ("Paper Lanterns", Maren Holt) and its cover are made up, so there is no real album art.
- Rows follow the app's current rules: only apps making sound are listed, sorted by name. So Discord is playing (a call), and there is no quiet fourth row. The empty foot under three rows is what the real notch shows.
- The stage is 700 × 280, not 720 × 340. At 700 wide, the open notch's body edge lands where macOS starts its app menus, so no menu title is cut by it. At 280 tall, less empty desktop sits under the notch.
- The menu bar is lighter than real dark macOS, so the black closed notch reads against it.
- App icons are the installed apps' own icons (via `NSWorkspace`), and glyphs are the app's SF Symbols rendered to 8x PNG masks.

Unresolved:
- The row-hover change above. Say if you want the demo to match the app exactly, or the app to match the demo.

Not checked:
- Playback in QuickTime by eye. I decoded the mp4 with AVFoundation (29.017 s, 1400 × 560, 60 fps, `avc1`) and looked at frames, but did not watch it in the player.
- Safari, Firefox and live frame pacing in a real browser tab. Everything was filmed in headless Chrome.
- How GitHub renders the mp4 in a README.
- The compact design on video. Only the wide design was recorded.
- The `?record` clock alongside pause, resume and offscreen playback.
