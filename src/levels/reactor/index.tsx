import { useEffect, useState } from 'react'
import { dayKey } from '../../lib/date'
import { LEVELS } from '../../lib/levels'
import Rings, { type ActivityRing } from './Rings'
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
  return 'Good night'
}

function progressNote(p: number) {
  if (p === 0) return 'A fresh start. One small step is enough to begin.'
  if (p < 25) return 'You’ve made a start. Keep it going.'
  if (p < 50) return 'Good momentum so far.'
  if (p < 75) return 'More than halfway there.'
  if (p < 100) return 'Nearly done for today.'
  return 'Everything done for today. Nicely done.'
}

export default function Reactor() {
  const now = useClock()
  const today = dayKey(now)
  const data = useReactorData(today)
  const [lineOffset, setLineOffset] = useState(0)

  const level = (p: string) => LEVELS.find((l) => l.path === p)!
  const rings: ActivityRing[] = data
    ? [
        { label: level('/negotiator').name, color: level('/negotiator').accent, value: data.negotiator.score },
        { label: level('/truth').name, color: level('/truth').accent, value: data.truth.score },
        { label: level('/lab').name, color: level('/lab').accent, value: data.lab.score },
        { label: level('/forge').name, color: level('/forge').accent, value: data.forge.score },
      ]
    : []
  const power = data?.power ?? 0

  const line = FUTURE_LINES[(lineIndexForDay(today) + lineOffset) % FUTURE_LINES.length]
  const date = now.toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' })

  return (
    <div className="home-page" style={{ ['--accent' as string]: 'var(--blue)' }}>
      <header className="home-header">
        <div className="home-date">{date}</div>
        <h1 className="home-title">{greeting(now.getHours())}</h1>
        <p className="home-sub">{data ? progressNote(power) : 'Loading today…'}</p>
      </header>

      <section className="panel home-summary" aria-label="Today's progress">
        <div className="home-rings-wrap">
          <Rings rings={rings.length ? rings : LEVELS.slice(1, 5).map((l) => ({ label: l.name, color: l.accent, value: 0 }))} />
        </div>
        <div className="home-summary-info">
          <div className="home-label">Today’s progress</div>
          <div className="home-total">
            {data ? power : '–'}
            <span className="home-total-unit">%</span>
          </div>
          <ul className="home-legend">
            {rings.map((r) => (
              <li key={r.label} style={{ ['--ring' as string]: r.color }}>
                <span className="home-legend-dot" aria-hidden />
                <span className="home-legend-name">{r.label}</span>
                <span className="home-legend-val">{Math.round(r.value * 100)}%</span>
              </li>
            ))}
          </ul>
        </div>
      </section>

      <section className="panel home-quote" aria-label="A note from Future You">
        <p className="home-quote-text">{line}</p>
        <div className="home-quote-foot">
          <span className="home-quote-by">Future You</span>
          <button className="btn btn-ghost btn-sm" onClick={() => setLineOffset((o) => o + 1)}>
            Another
          </button>
        </div>
      </section>

      {data && <LevelCards data={data} />}

      <div className="home-lower">
        {data && <Projection data={data.last30} />}
        <Letters />
      </div>
    </div>
  )
}
