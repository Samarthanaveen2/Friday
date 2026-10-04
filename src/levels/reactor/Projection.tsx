import { Link } from 'react-router-dom'
import type { Last30 } from './useReactorData'

const HORIZONS = [
  { key: 'm1', label: 'In 1 month', short: '1 mo', days: 30 },
  { key: 'm6', label: 'In 6 months', short: '6 mo', days: 182 },
  { key: 'y1', label: 'In 1 year', short: '1 yr', days: 365 },
] as const

interface Metric {
  key: keyof Pick<Last30, 'keptDeals' | 'votes' | 'truths' | 'holes'>
  one: string
  many: string
  path: string
}

const METRICS: Metric[] = [
  { key: 'keptDeals', one: 'kept deal', many: 'kept deals', path: '/negotiator' },
  { key: 'votes', one: 'habit check-in', many: 'habit check-ins', path: '/forge' },
  { key: 'truths', one: 'truth written', many: 'truths written', path: '/truth' },
  { key: 'holes', one: 'idea explored', many: 'ideas explored', path: '/lab' },
]

function fmt(n: number) {
  const r = Math.round(n)
  return r.toLocaleString()
}

function phrase(n: number, m: Metric) {
  const r = Math.round(n)
  return `${r >= 10 ? '~' : ''}${fmt(n)} ${r === 1 ? m.one : m.many}`
}

function cap(s: string) {
  return s.charAt(0).toUpperCase() + s.slice(1)
}

function listSentence(parts: string[]) {
  if (parts.length <= 1) return parts.join('')
  return parts.slice(0, -1).join(', ') + ' and ' + parts[parts.length - 1]
}

export default function Projection({ data }: { data: Last30 }) {
  if (!data.hasData) {
    return (
      <section className="home-section">
        <h2 className="home-section-title">Looking ahead</h2>
        <div className="panel home-proj-empty">
          <p className="muted">
            This takes what you actually did over the last 30 days and extends it forward, so Future You becomes something you can see. Keep one
            deal, check in on one habit, write one truth or explore one idea to get started.
          </p>
          <div className="row home-proj-hint">
            {METRICS.map((m) => (
              <Link key={m.key} to={m.path} className="chip">
                {m.one}
              </Link>
            ))}
          </div>
        </div>
      </section>
    )
  }

  const perDay = (k: Metric['key']) => data[k] / data.windowDays
  const active = METRICS.filter((m) => data[m.key] > 0)
  const idle = METRICS.filter((m) => data[m.key] === 0)
  const yearParts = (mult: number) => active.map((m) => phrase(perDay(m.key) * 365 * mult, m))

  return (
    <section className="home-section">
      <div className="home-section-head">
        <h2 className="home-section-title">Looking ahead</h2>
        <span className="home-section-note">Based on your last {data.windowDays} days</span>
      </div>

      <div className="panel home-list home-proj-table">
        <div className="home-proj-row home-proj-headrow" aria-hidden>
          <span />
          {HORIZONS.map((h) => (
            <span key={h.key} className="home-proj-when">
              <span className="home-proj-long">{h.label}</span>
              <span className="home-proj-short">{h.short}</span>
            </span>
          ))}
        </div>
        {METRICS.map((m) => (
          <div key={m.key} className={'home-proj-row' + (data[m.key] === 0 ? ' zero' : '')}>
            <span className="home-proj-label">{cap(m.many)}</span>
            {HORIZONS.map((h) => (
              <span key={h.key} className="home-proj-num" aria-label={`${h.label}: ${fmt(perDay(m.key) * h.days)}`}>
                {fmt(perDay(m.key) * h.days)}
              </span>
            ))}
          </div>
        ))}
      </div>

      <div className="panel home-list">
        <div className="home-row home-row-text">
          <span className="home-row-label">At this rate</span>
          <span className="home-row-detail">In a year: {listSentence(yearParts(1))}.</span>
        </div>
        <div className="home-row home-row-text">
          <span className="home-row-label">With 10% more</span>
          <span className="home-row-detail">{cap(listSentence(yearParts(1.1)))}. Same you, a little braver.</span>
        </div>
        {idle.length > 0 && (
          <div className="home-row home-row-text">
            <span className="home-row-label">Not started yet</span>
            <span className="home-row-detail">
              {cap(listSentence(idle.map((m) => m.many)))}. Even one a week adds up to 52 by this time next year.
            </span>
          </div>
        )}
        <div className="home-row home-row-text">
          <span className="home-row-label">If you stop today</span>
          <span className="home-row-detail">Future You keeps exactly what you have now, and nothing more.</span>
        </div>
      </div>
    </section>
  )
}
