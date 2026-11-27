import type { CSSProperties } from 'react'
import { Count, Stage, type Act, type Rect } from '../../kit'
import './notch.css'

import musicIcon from './assets/apps/music.png'
import chromeIcon from './assets/apps/chrome.png'
import discordIcon from './assets/apps/discord.png'
import houseGlyph from './assets/glyphs/house.png'
import trayGlyph from './assets/glyphs/tray.png'
import slidersGlyph from './assets/glyphs/sliders.png'
import gearGlyph from './assets/glyphs/gear.png'
import speakerGlyph from './assets/glyphs/speaker.png'
import speakerSlashGlyph from './assets/glyphs/speaker-slash.png'
import waveformGlyph from './assets/glyphs/waveform.png'
import backwardGlyph from './assets/glyphs/backward.png'
import forwardGlyph from './assets/glyphs/forward.png'
import pauseGlyph from './assets/glyphs/pause.png'
import appleGlyph from './assets/glyphs/apple.png'
import wifiGlyph from './assets/glyphs/wifi.png'
import controlGlyph from './assets/glyphs/control.png'

// Notch's per-app volume Mixer, in the open notch at the top of a Mac screen.
// Started from the Dynamic Island gold: one black shape whose box springs
// between closed and open, with its content on a separate layer that fades in
// once the shape is mostly there, so nothing in it stretches.
//
// Everything is in macOS points at 1:1, measured from the real app
// (boringNotch/Mixer/MixerView.swift, sizing/matters.swift and screenshots):
// the open notch is 640 x 190 with 19 pt top fillets and 24 pt bottom corners,
// its content inset 31 pt; Mixer rows are 30 pt tall on a 32 pt pitch, an
// 18 pt app icon, a name column of min(34%, 160 pt), a slider, a 32 pt
// percent and a 26 pt mute button. The slider track is 4 pt at rest, 6 on
// hover and 8 while dragging. App icons are the apps' own (NSWorkspace), and
// glyphs are the SF Symbols the app uses, rendered to masks.
//
// The Mixer lists only apps making sound (or within 8 s of it), sorted by
// name, so the three rows are Discord (a call), Chrome and Music, each with
// its playing waveform.
//
// Real strings: the song and artist, the three app names and their percents.
// The menu bar's titles and clock are macOS chrome.

type GlyphName =
  | 'house' | 'tray' | 'sliders' | 'gear' | 'speaker' | 'speaker-slash' | 'waveform'
  | 'backward' | 'forward' | 'pause' | 'apple' | 'wifi' | 'control'

// Each glyph's image size in points, as NSImage reports it for the app's
// point size and weight (scratch script export-symbols.swift)
const GLYPHS: Record<GlyphName, [string, number, number]> = {
  house: [houseGlyph, 20, 16],
  tray: [trayGlyph, 19, 13],
  sliders: [slidersGlyph, 17, 13],
  gear: [gearGlyph, 18, 18],
  speaker: [speakerGlyph, 19, 14],
  'speaker-slash': [speakerSlashGlyph, 14, 16],
  waveform: [waveformGlyph, 12, 13],
  backward: [backwardGlyph, 22, 14],
  forward: [forwardGlyph, 22, 14],
  pause: [pauseGlyph, 20, 22],
  apple: [appleGlyph, 13, 16],
  wifi: [wifiGlyph, 17, 13],
  control: [controlGlyph, 17, 14],
}

function Glyph({ name, className }: { name: GlyphName; className?: string }) {
  const [src, width, height] = GLYPHS[name]
  const style: CSSProperties = { width, height, WebkitMaskImage: `url(${src})`, maskImage: `url(${src})` }
  return <span className={className ? `nm-glyph ${className}` : 'nm-glyph'} style={style} aria-hidden />
}

/** A damped spring as a CSS linear() easing, as SwiftUI's spring(response:dampingFraction:) */
function spring(zeta: number, response: number, ms: number, n = 48) {
  const omega = (2 * Math.PI) / response
  const wd = omega * Math.sqrt(1 - zeta * zeta)
  const points: string[] = []
  for (let i = 0; i <= n; i++) {
    const t = (i / n) * (ms / 1000)
    const x = i === n ? 1 : 1 - Math.exp(-zeta * omega * t) * (Math.cos(wd * t) + ((zeta * omega) / wd) * Math.sin(wd * t))
    points.push(x.toFixed(4))
  }
  return `linear(${points.join(', ')})`
}

// The app's own springs: open .spring(response: 0.42, dampingFraction: 0.8),
// close .spring(response: 0.45, dampingFraction: 1.0)
const OPEN = { ease: spring(0.8, 0.42, 700), ms: 700 }
const CLOSE = { ease: spring(0.99, 0.45, 560), ms: 560 }

type Layout = 'wide' | 'compact'
type Box = { l: number; t: number; w: number; h: number }

// Where everything sits, per design. The wide stage is 700 wide so the open
// notch's body edge lands where macOS starts its app menus: the Apple logo
// and the clock stay beside the open notch, and no menu title is cut by it.
// The compact design runs the open notch's body to the stage's edges and
// reflows the rows, the way the same rows fit the 380 pt menu bar panel.
function geometry(layout: Layout) {
  const wide = layout === 'wide'
  const width = wide ? 700 : 358
  const open: Box = wide ? { l: 30, t: 0, w: 640, h: 190 } : { l: -19, t: 0, w: 396, h: 190 }
  const closed: Box = { l: Math.round((width - 250) / 2), t: 0, w: 250, h: 32 }
  const left = open.l + 31
  const right = open.l + open.w - 31
  const nameColumn = wide ? 160 : 119
  const art = { l: left + 14, t: 53, s: 110 }
  const title = { l: art.l + art.s + 28, r: right }
  return { width, height: wide ? 280 : 260, open, closed, left, right, nameColumn, art, title }
}

type Geometry = ReturnType<typeof geometry>
type Tab = 'home' | 'shelf' | 'mixer'

type S = {
  open: boolean
  tab: Tab
  /** Where the album art is drawn: the closed notch's thumbnail or Home's cover */
  art: 'closed' | 'open'
  artShow: boolean
  chrome: number
  dragging: boolean
  discordMuted: boolean
}

const START: S = { open: false, tab: 'home', art: 'closed', artShow: true, chrome: 1, dragging: false, discordMuted: false }
const POSTER: S = { open: true, tab: 'mixer', art: 'open', artShow: false, chrome: 0.3, dragging: false, discordMuted: true }

// Where the pointer rests at the start and end of each loop: on the desktop
const REST = { wide: { x: 470, y: 246 }, compact: { x: 250, y: 236 } }

const TABS: { id: Tab; glyph: GlyphName; width: number }[] = [
  { id: 'home', glyph: 'house', width: 50 },
  { id: 'shelf', glyph: 'tray', width: 49 },
  { id: 'mixer', glyph: 'sliders', width: 47 },
]

/** The slider's value under the pointer, snapping to 100% at 97% as the app does.
 * The value stays continuous; only the percent readout rounds. */
function volumeAt(x: number, slider: Rect) {
  const v = Math.min(1, Math.max(0, (x - slider.x) / slider.width))
  if (v >= 0.97) return 1
  return v
}

// Three digits always, the leading one hidden below 100, so going back to
// 100% rolls the 1 in with the others instead of popping it in
const threeDigits = (n: number) => `${String(n).padStart(3, '0')}%`

function Shape({ s, g }: { s: S; g: Geometry }) {
  // The spring follows the direction of travel: a small overshoot opening,
  // critically damped closing, a beat late so the content has cleared
  const f = s.open ? g.open : g.closed
  const rt = s.open ? 19 : 6
  const rb = s.open ? 24 : 14
  const motion: CSSProperties = s.open
    ? { transitionDuration: `${OPEN.ms}ms`, transitionTimingFunction: OPEN.ease, transitionDelay: '0ms' }
    : { transitionDuration: `${CLOSE.ms}ms`, transitionTimingFunction: CLOSE.ease, transitionDelay: '120ms' }
  return (
    <div className="nm-shape" data-open={s.open || undefined} style={{ ...motion, left: f.l + rt, top: f.t, width: f.w - rt * 2, height: f.h, borderBottomLeftRadius: rb, borderBottomRightRadius: rb }}>
      <span className="nm-ear nm-ear--l" style={{ ...motion, width: rt, height: rt, left: -rt }} />
      <span className="nm-ear nm-ear--r" style={{ ...motion, width: rt, height: rt, right: -rt }} />
    </div>
  )
}

function MenuBar({ layout }: { layout: Layout }) {
  const wide = layout === 'wide'
  return (
    <div className="nm-menubar">
      <span className="nm-menubar__lead">
        <Glyph name="apple" className="nm-menubar__apple" />
        {wide && (
          <>
            <span className="nm-menubar__app">Music</span>
            <span>File</span>
            <span>Edit</span>
          </>
        )}
      </span>
      <span className="nm-menubar__trail">
        {wide && <Glyph name="wifi" />}
        {wide && <Glyph name="control" />}
        <span className="nm-menubar__clock">9:41</span>
      </span>
    </div>
  )
}

function Header({ s, g }: { s: S; g: Geometry }) {
  let capsuleLeft = 0
  let capsuleWidth = TABS[0]!.width
  let x = 0
  for (const tab of TABS) {
    if (tab.id === s.tab) {
      capsuleLeft = x
      capsuleWidth = tab.width
    }
    x += tab.width
  }
  return (
    <div className="nm-item nm-header" data-on={s.open || undefined} style={{ left: g.left, width: g.right - g.left }}>
      <span className="nm-tabs">
        <span className="nm-tabs__capsule" style={{ left: capsuleLeft, width: capsuleWidth }} />
        {TABS.map((tab) => (
          <span key={tab.id} className="nm-tab" data-target={`tab-${tab.id}`} data-on={tab.id === s.tab || undefined} style={{ width: tab.width }}>
            <Glyph name={tab.glyph} />
          </span>
        ))}
      </span>
      <span className="nm-gear">
        <Glyph name="gear" />
      </span>
    </div>
  )
}

function AlbumArt({ s, g }: { s: S; g: Geometry }) {
  const open = s.art === 'open'
  const box = open ? { l: g.art.l, t: g.art.t, s: g.art.s, r: 12 } : { l: g.closed.l + 6, t: 6, s: 20, r: 4 }
  const motion: CSSProperties = open
    ? { transitionTimingFunction: OPEN.ease, transitionDuration: `${OPEN.ms}ms` }
    : { transitionTimingFunction: CLOSE.ease, transitionDuration: `${CLOSE.ms}ms` }
  // The Music badge sits on the cover's corner, half outside, once it has landed
  const badge = open && s.artShow
  return (
    <>
      <span className="nm-art" data-target="art" data-show={s.artShow || undefined} style={{ ...motion, left: box.l, top: box.t, width: box.s, height: box.s, borderRadius: box.r }} />
      <img className="nm-badge" data-on={badge || undefined} src={musicIcon} alt="" style={{ left: g.art.l + g.art.s - 15, top: g.art.t + g.art.s - 17 }} />
    </>
  )
}

function Spectrum({ s, g }: { s: S; g: Geometry }) {
  return (
    <span className="nm-item nm-spectrum" data-on={!s.open || undefined} style={{ left: g.closed.l + g.closed.w - 26, top: 6 }}>
      <span />
      <span />
      <span />
      <span />
    </span>
  )
}

function Home({ s, g }: { s: S; g: Geometry }) {
  const on = s.open && s.tab === 'home'
  return (
    <div className="nm-item nm-home" data-on={on || undefined} style={{ left: g.title.l, width: g.title.r - g.title.l }}>
      <span className="nm-home__song">
        <span className="nm-home__title">Paper Lanterns</span>
        <span className="nm-home__artist">Maren Holt</span>
      </span>
      <span className="nm-home__progress">
        <span className="nm-home__track">
          <span className="nm-home__played" />
        </span>
        <span className="nm-home__times">
          <span>1:12</span>
          <span>3:41</span>
        </span>
      </span>
      <span className="nm-home__controls">
        <Glyph name="backward" />
        <Glyph name="pause" className="nm-home__pause" />
        <Glyph name="forward" />
      </span>
    </div>
  )
}

type App = { id: string; name: string; icon: string; playing: boolean }
const APPS: App[] = [
  { id: 'discord', name: 'Discord', icon: discordIcon, playing: true },
  { id: 'chrome', name: 'Google Chrome', icon: chromeIcon, playing: true },
  { id: 'music', name: 'Music', icon: musicIcon, playing: true },
]

function Row({ app, index, s, on }: { app: App; index: number; s: S; on: boolean }) {
  const volume = app.id === 'chrome' ? s.chrome : 1
  const muted = app.id === 'discord' && s.discordMuted
  const dragging = app.id === 'chrome' && s.dragging
  const percent = Math.round(volume * 100)
  let tone = 'full'
  if (dragging) tone = 'drag'
  else if (volume < 1) tone = 'partial'
  return (
    <div
      className="nm-row"
      data-target={`row-${app.id}`}
      data-muted={muted || undefined}
      style={{ top: index * 32, animationDelay: on ? `${110 + index * 40}ms` : '0ms' }}
    >
      <span className="nm-row__group">
        <img className="nm-row__icon" src={app.icon} alt="" />
        <span className="nm-row__name">
          <span className="nm-row__label">{app.name}</span>
          <span className="nm-wave" data-on={app.playing || undefined}>
            <Glyph name="waveform" />
          </span>
        </span>
        <span className="nm-slider" data-target={`slider-${app.id}`} data-cursor="hand" data-dragging={dragging || undefined}>
          <span className="nm-slider__track">
            <span className="nm-slider__fill" data-instant={dragging || undefined} style={{ width: `${volume * 100}%` }} />
          </span>
        </span>
        <span className="nm-row__pct" data-target={`pct-${app.id}`} data-tone={tone} data-short={percent < 100 || undefined}>
          <Count value={percent} format={threeDigits} duration={dragging ? 0 : 320} stagger={30} />
        </span>
      </span>
      <span className="nm-mute" data-target={`mute-${app.id}`} data-cursor="hand" data-muted={muted || undefined}>
        <Glyph name="speaker" className="nm-mute__on" />
        <Glyph name="speaker-slash" className="nm-mute__off" />
      </span>
    </div>
  )
}

function Mixer({ s, g }: { s: S; g: Geometry }) {
  const on = s.open && s.tab === 'mixer'
  const style = {
    left: g.left - 8,
    width: g.right - g.left + 16,
    '--nm-cols': `18px ${g.nameColumn}px minmax(0, 1fr) 32px`,
  } as CSSProperties
  return (
    <div className="nm-mixer" data-on={on || undefined} style={style}>
      {APPS.map((app, i) => (
        <Row key={app.id} app={app} index={i} s={s} on={on} />
      ))}
    </div>
  )
}

/**
 * The loop, 14.5s, one thing at a time (times as recorded):
 *   0.5s   the pointer goes up to the closed notch, where a song is playing
 *   1.45s  the notch springs open on Home; the album art grows into the cover
 *   3.4s   the Mixer tab: the capsule slides over, the rows rise in
 *   5.4s   Chrome's slider is dragged from 100% down to 30%
 *   7.9s   Discord's speaker is clicked: muted, its row dims
 *   8.7s   the payoff holds: Discord muted, Chrome at 30%, Music at 100%
 *  10.7s   a double-click on Chrome's percent puts it back to 100%
 *  11.9s   Discord is unmuted
 *  13.4s   the pointer leaves; the notch closes, back to the playing song
 */
async function script(a: Act<S>) {
  await a.wait(500)
  a.mark('enter')
  const notch = a.rect('notch')
  await a.move({ x: notch.x + notch.width * 0.5, y: notch.y + notch.height * 0.55 }, { duration: 700 })
  await a.wait(220)
  await a.set({ open: true, art: 'open' })
  a.mark('home')
  await a.wait(1300)

  await a.move({ at: 'tab-mixer', x: 0.62, y: 0.66 })
  await a.wait(120)
  await a.click()
  await a.set({ tab: 'mixer', artShow: false })
  a.mark('mixer')
  await a.wait(1000)

  // Chrome: press at the end of its full track and pull it down to 30%
  const slider = a.rect('slider-chrome')
  const y = slider.y + slider.height / 2
  await a.move({ x: slider.x + slider.width - 3, y })
  await a.wait(380)
  a.mark('drag')
  await a.drag(
    { x: slider.x + slider.width * 0.3, y },
    (at) => a.put({ dragging: true, chrome: volumeAt(at.x, slider) }),
    { duration: 1200, cursor: 'preserve' },
  )
  await a.set({ dragging: false })
  await a.wait(320)

  // Discord: mute
  await a.click({ at: 'mute-discord', x: 0.66, y: 0.7 })
  await a.set({ discordMuted: true })
  a.mark('muted')
  await a.wait(300)
  // Off the controls, into the notch's empty foot, near the next move
  const pct = a.rect('pct-chrome')
  const foot = a.rect('notch-foot')
  await a.move({ x: pct.x - 26, y: foot.y + foot.height * 0.5 }, { duration: 500 })
  await a.wait(2000)

  // Back to how it was, each with its own control
  a.mark('reset')
  await a.click({ at: 'pct-chrome', x: 0.03, y: 0.92 }, { double: true })
  await a.set({ chrome: 1 })
  await a.wait(650)
  await a.click({ at: 'mute-discord', x: 0.66, y: 0.7 })
  await a.set({ discordMuted: false })
  await a.wait(750)

  // The pointer leaves and the notch closes, back on Home for next time
  a.mark('leave')
  const rest = a.layout === 'compact' ? REST.compact : REST.wide
  void a.move(rest, { duration: 650 })
  await a.wait(260)
  await a.snap({ art: 'closed' }, 'art')
  await a.set({ open: false, artShow: true })
  await a.wait(600)
  await a.snap({ tab: 'home' })
  await a.wait(200)
}

export default function NotchMixer() {
  return (
    <Stage<S>
      width={700}
      height={280}
      compact={{ below: 560, width: 358, height: 260 }}
      theme="dark"
      initial={START}
      poster={POSTER}
      script={script}
      cursor={{ at: REST, style: 'real' }}
      className="nm"
    >
      {(s, _rect, layout) => {
        const g = geometry(layout)
        return (
          <div className="nm-screen" data-layout={layout}>
            <span className="nm-wall" />
            <MenuBar layout={layout} />
            <div className="nm-notch" data-open={s.open || undefined}>
              <Shape s={s} g={g} />
              <span className="nm-hit" data-target="notch" style={{ left: g.closed.l, top: 0, width: g.closed.w, height: g.closed.h }} />
              <span className="nm-hit" data-target="notch-foot" style={{ left: g.open.l + 19, top: 166, width: g.open.w - 38, height: 24 }} />
              <Spectrum s={s} g={g} />
              <AlbumArt s={s} g={g} />
              <Header s={s} g={g} />
              <Home s={s} g={g} />
              <Mixer s={s} g={g} />
            </div>
          </div>
        )
      }}
    </Stage>
  )
}
