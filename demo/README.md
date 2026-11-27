# Mixer demo

A looping faux-UI demo of Notch's per-app volume Mixer, built with [Stageshow](kit/LICENSE) (React and plain CSS). It is a drawing of the app, not a recording: nothing here runs Core Audio.

- `mixer-demo.mp4`: two loops, 29 s, 1400 × 560, 60 fps, H.264. Plays in QuickTime.
- `mixer-demo-poster.png`: the still that reduced motion and thumbnails show.

## Run it

```sh
npm install
npm run dev          # http://127.0.0.1:5173/
npm run typecheck
npm run film         # rehearsal gate at the shown width (needs Google Chrome)
npm run film:phone   # the same at 390 wide, which shows the compact design
```

`?record` (or `?record=30`) puts the page on the kit's virtual clock, so a recorder can step it one exact frame at a time. That is how the mp4 was made.

## Assets

- `kit/`: Stageshow's kit, MIT (`kit/LICENSE`, `kit/NOTICE.md`).
- `src/notch-mixer/assets/apps/`: the Music, Google Chrome and Discord icons, exported from the installed apps with `NSWorkspace`, the same icons the real Mixer shows. They belong to their owners.
- `src/notch-mixer/assets/glyphs/`: the SF Symbols the app uses, rendered to masks.
- The song, artist and cover art are made up.
