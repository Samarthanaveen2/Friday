import { Link } from 'react-router-dom'
import type { Last30 } from './useReactorData'

const HORIZONS = [
  { key: 'm1', label: 'In 1 month', days: 30 },
  { key: 'm6', label: 'In 6 months', days: 182 },
  { key: 'y1', label: 'In 1 year', days: 365 },
] as const

interface Metric {
  key: keyof Pick<Last30, 'keptDeals' | 'votes' | 'truths' | 'holes'>
  one: string
  many: string
  path: string
}

const METRICS: Metric[] = [
  { key: 'keptDeals', one: 'kept deal', many: 'kept deals', path: '/negotiator' },
  { key: 'votes', one: 'identity vote', many: 'identity votes', path: '/forge' },
  { key: 'truths', one: 'truth spoken', many: 'truths spoken', path: '/truth' },
  { key: 'holes', one: 'rabbit hole', many: 'rabbit holes', path: '/lab' },
]

function fmt(n: number) {
  const r = Math.round(n)
  return r.toLocaleString()
}

function phrase(n: number, m: Metric) {
  const r = Math.round(n)
  return `${r >= 10 ? '~' : ''}${fmt(n)} ${r === 1 ? m.one : m.many}`
}

function listSentence(parts: string[]) {
  if (parts.length <= 1) return parts.join('')
  return parts.slice(0, -1).join(', ') + ' and ' + parts[parts.length - 1]
}

export default function Projection({ data }: { data: Last30 }) {
  if (!data.hasData) {
    return (
      <section className="panel rx-projection">
        <div className="panel-title">Future projection</div>
        <h2 className="rx-section-title">Your future, in numbers</h2>
        <p className="muted rx-proj-empty">
          This panel takes what you actually did over the last 30 days and extends it forward, so Future You stops being an abstraction and
          becomes a number you can see. Keep one deal, cast one habit vote, speak one truth or open one rabbit hole, and the projection lights up.
        </p>
        <div className="rx-proj-hint row">
          {METRICS.map((m) => (
            <Link key={m.key} to={m.path} className="chip">
              + {m.one}
            </Link>
          ))}
        </div>
      </section>
    )
  }

  const perDay = (k: Metric['key']) => data[k] / data.windowDays
  const active = METRICS.filter((m) => data[m.key] > 0)
  const idle = METRICS.filter((m) => data[m.key] === 0)
  const yearParts = (mult: number) => active.map((m) => phrase(perDay(m.key) * 365 * mult, m))

  return (
    <section className="panel rx-projection">
      <div className="panel-title">Future projection · based on your last {data.windowDays} days</div>
      <h2 className="rx-section-title">Where this road goes</h2>

      <div className="rx-proj-grid">
        {HORIZONS.map((h) => (
          <div key={h.key} className={'rx-proj-col rx-proj-' + h.key}>
            <div className="rx-proj-when">{h.label}</div>
            <ul className="rx-proj-list">
              {METRICS.map((m) => {
                const v = perDay(m.key) * h.days
                return (
                  <li key={m.key} className={data[m.key] === 0 ? 'rx-proj-zero' : ''}>
                    <span className="rx-proj-num">{fmt(v)}</span>
                    <span className="rx-proj-label">{Math.round(v) === 1 ? m.one : m.many}</span>
                  </li>
                )
              })}
            </ul>
          </div>
        ))}
      </div>

      <div className="rx-proj-lines">
        <p className="rx-proj-line">
          <span className="rx-proj-tag">At this rate</span>
          in a year: {listSentence(yearParts(1))}.
        </p>
        <p className="rx-proj-line rx-proj-better">
          <span className="rx-proj-tag">If you improve 10%</span>
          {listSentence(yearParts(1.1))}. Same you, slightly braver.
        </p>
        {idle.length > 0 && (
          <p className="rx-proj-line rx-proj-idle">
            <span className="rx-proj-tag">Still at zero</span>
            {listSentence(idle.map((m) => m.many))}. Even one a week becomes 52 by this time next year.
          </p>
        )}
        <p className="rx-proj-line rx-proj-stop">
          <span className="rx-proj-tag">If you stop today</span>
          Future You inherits exactly what you have now, and not one thing more.
        </p>
      </div>
    </section>
  )
}
