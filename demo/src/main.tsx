import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { installVirtualClock } from '../kit/clock'
import './page.css'

// `?record` (or `?record=30`) hands time to a recorder: the kit's virtual
// clock only moves when the recorder steps it, one exact frame at a time, so
// a captured video has no dropped or doubled frames. It has to be installed
// before the demo's code starts any timer, hence the dynamic import below.
async function start() {
  const params = new URLSearchParams(location.search)
  if (params.has('record')) installVirtualClock({ fps: Number(params.get('record')) || 60 })
  const { default: NotchMixer } = await import('./notch-mixer')
  createRoot(document.getElementById('root')!).render(
    <StrictMode>
      <main className="page">
        <NotchMixer />
      </main>
    </StrictMode>,
  )
}

void start()
