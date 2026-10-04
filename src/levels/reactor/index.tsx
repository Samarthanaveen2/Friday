import { useEffect, useState } from 'react'
import LevelHeader from '../../components/LevelHeader'
import { dayKey } from '../../lib/date'
import { LEVELS } from '../../lib/levels'
import ArcReactor, { type ReactorRing } from './ArcReactor'
import LevelCards from './LevelCards'
import Letters from './Letters'
import Projection from './Projection'
import { FUTURE_LINES, lineIndexForDay } from './quotes'
import { useReactorData } from './useReactorData'
import './reactor.css'

function useClock() {
  const [now, setNow] = useState(() => new Date())
  useEffect(() => {
    const id = window.setInterval(() => setNow(new Date()), 15_000)
    return () => window.clearInterval(id)
  }, [])
  return now
}

function greeting(h: number) {
  if (h < 5) return 'Still up'
  if (h < 12) return 'Good morning'
  if (h < 17) return 'Good afternoon'
  if (h < 22) return 'Good evening'
  return 'Late night'
}

function powerState(p: number) {
  if (p === 0) return 'Cold start. One action brings it online.'
  if (p < 25) return 'Ignition. The core is warming up.'
  if (p < 50) return 'Partial power. Keep feeding it.'
  if (p < 75) return 'Running strong.'
  if (p < 100) return 'Near full output.'
  return 'Full power. Future You felt that.'
}

export default function Reactor() {
  const now = useClock()
  const today = dayKey(now)
  const data = useReactorData(today)
  const [lineOffset, setLineOffset] = useState(0)

  const level = (p: string) => LEVELS.find((l) => l.path === p)!
  const rings: ReactorRing[] = data
    ? [
        { label: level('/negotiator').name, color: level('/negotiator').accent, value: data.negotiator.score },
        { label: level('/truth').name, color: level('/truth').accent, value: data.truth.score },
        { label: level('/lab').name, color: level('/lab').accent, value: data.lab.score },
        { label: level('/forge').name, color: level('/forge').accent, value: data.forge.score },
      ]
    : []
  const power = data?.power ?? 0

  const line = FUTURE_LINES[(lineIndexForDay(today) + lineOffset) % FUTURE_LINES.length]
  const time = now.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' })
  const date = now.toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })

  return (
    <div className="rx-page">
      <LevelHeader path="/" />

      <section className="rx-hero panel glow" style={{ ['--hero-power' as string]: power / 100 }}>
        <span className="rx-corner rx-corner-tl" aria-hidden />
        <span className="rx-corner rx-corner-tr" aria-hidden />
        <span className="rx-corner rx-corner-bl" aria-hidden />
        <span className="rx-corner rx-corner-br" aria-hidden />

        <div className="rx-hero-reactor">
          <ArcReactor power={power} rings={rings} />
        </div>

        <div className="rx-hero-info">
          <div className="rx-greet-meta mono">
            <span>{date}</span>
            <span className="rx-clock">{time}</span>
          </div>
          <h2 className="rx-greet">{greeting(now.getHours())}.</h2>
          <p className="rx-greet-sub">Today is the only place Future You can be built.</p>

          <div className="rx-power-read">
            <div className="rx-power-label mono">Core output</div>
            <div className="rx-power-num">
              {data ? power : '--'}
              <span className="rx-power-unit">%</span>
            </div>
            <div className="rx-power-state">{data ? powerState(power) : 'Spinning up…'}</div>
          </div>

          <ul className="rx-legend">
            {rings.map((r) => (
              <li key={r.label} style={{ ['--ring' as string]: r.color }} className={r.value >= 1 ? 'full' : r.value > 0 ? 'on' : ''}>
                <span className="rx-legend-swatch" aria-hidden />
                <span className="rx-legend-name">{r.label}</span>
                <span className="rx-legend-val mono">{Math.round(r.value * 100)}%</span>
              </li>
            ))}
          </ul>
        </div>
      </section>

      <section className="rx-quote" aria-label="Note from Future You">
        <span className="rx-quote-tag mono">Future You ·</span>
        <p className="rx-quote-text">{line}</p>
        <button className="btn btn-ghost btn-sm rx-quote-next" onClick={() => setLineOffset((o) => o + 1)} aria-label="Show another line">
          ↻
        </button>
      </section>

      {data && <LevelCards data={data} />}

      <div className="rx-lower">
        {data && <Projection data={data.last30} />}
        <Letters />
      </div>
    </div>
  )
}
