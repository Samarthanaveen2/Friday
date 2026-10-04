import { useState } from 'react'
import { Link } from 'react-router-dom'
import { addDays, dayKey, fromDayKey, prettyDay } from '../../lib/date'
import { ReviewPanel, StatusChip } from './components'
import { type NegDeal, completionPct, fmtMin, inheritedOwed, keepStats, keptStreak, sumMinutes } from './logic'

export default function History({ deals }: { deals: NegDeal[] }) {
  const today = dayKey()
  const [open, setOpen] = useState<number | null>(null)
  const sorted = [...deals].sort((a, b) => b.date.localeCompare(a.date))
  const streak = keptStreak(deals, today)
  const stats = keepStats(deals, today)
  const todayDeal = deals.find((d) => d.date === today)
  const owedNow = todayDeal ? (todayDeal.status === 'open' ? (todayDeal.debtTaken ?? 0) : (todayDeal.owedOut ?? 0)) : inheritedOwed(deals, today).owed
  const byDate = new Map(deals.map((d) => [d.date, d]))
  const strip = Array.from({ length: 30 }, (_, i) => addDays(today, i - 29))

  if (deals.length === 0) {
    return (
      <div className="empty">
        <p>No deals on record yet.</p>
        <p className="small" style={{ marginTop: 6 }}>
          Your first deal will show up here. <Link to="/negotiator">Make one today</Link>
        </p>
      </div>
    )
  }

  return (
    <div className="stack">
      <div className="neg-stats">
        <div className="panel neg-stat">
          <div className="panel-title">Kept streak</div>
          <div className="big-number neg-accent">{streak}</div>
          <div className="small muted">{streak === 1 ? 'day' : 'days'} in a row</div>
        </div>
        <div className="panel neg-stat">
          <div className="panel-title">Keep rate · 30d</div>
          <div className="big-number">{stats.rate === null ? '—' : `${Math.round(stats.rate * 100)}%`}</div>
          <div className="small muted">
            {stats.reviewed ? `${stats.kept} kept · ${stats.partial} partial · ${stats.broken} broken` : 'No reviewed deals yet'}
          </div>
        </div>
        <div className="panel neg-stat">
          <div className="panel-title">Borrowed time</div>
          <div className={`big-number ${owedNow > 0 ? 'neg-red' : 'neg-green'}`}>{owedNow > 0 ? fmtMin(owedNow) : '0'}</div>
          <div className="small muted">{owedNow > 0 ? 'carried into the next deal' : 'Nothing owed'}</div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-title">Last 30 days</div>
        <div className="neg-strip">
          {strip.map((k) => {
            const d = byDate.get(k)
            return (
              <div
                key={k}
                className={`neg-dot neg-dot-${d ? d.status : 'none'} ${k === today ? 'today' : ''}`}
                title={`${prettyDay(k)}: ${d ? d.status : 'no deal'}`}
              />
            )
          })}
        </div>
        <div className="neg-legend small muted">
          <span><i className="neg-dot neg-dot-kept" /> kept</span>
          <span><i className="neg-dot neg-dot-partial" /> partial</span>
          <span><i className="neg-dot neg-dot-broken" /> broken</span>
          <span><i className="neg-dot neg-dot-open" /> open</span>
          <span><i className="neg-dot neg-dot-none" /> no deal</span>
        </div>
      </div>

      <ul className="panel neg-history">
        {sorted.map((d) => {
          const isOpen = open === d.id
          const pct = d.completion ?? completionPct(d.needs)
          const past = d.date < today
          return (
            <li key={d.id} className={`neg-hist neg-hist-${d.status}`}>
              <button className="neg-hist-row" onClick={() => setOpen(isOpen ? null : (d.id ?? null))} aria-expanded={isOpen}>
                <div className="neg-hist-date">
                  <div>{prettyDay(d.date)}</div>
                  <div className="small muted">{fromDayKey(d.date).getFullYear()}</div>
                </div>
                <div className="neg-hist-mid small">
                  <span className="neg-num-inline">{fmtMin(sumMinutes(d.needs))}</span>
                  <span className="muted"> needs · </span>
                  <span className="neg-num-inline">{fmtMin(sumMinutes(d.wants))}</span>
                  <span className="muted"> wants · </span>
                  <span className="neg-num-inline">{pct}%</span>
                  {d.debtTaken ? <span className="muted"> · borrowed</span> : null}
                </div>
                <StatusChip status={d.status} />
                <svg className="neg-chevron" viewBox="0 0 10 16" width="8" height="13" aria-hidden>
                  <path d="M2 2l6 6-6 6" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </button>
              {isOpen && (
                <div className="neg-hist-body stack-sm">
                  <div className="neg-hist-cols">
                    <div>
                      <div className="neg-card-title neg-card-present"><span className="neg-label-dot" aria-hidden />Present You</div>
                      {d.wants.length ? (
                        <ul className="neg-mini">
                          {d.wants.map((w) => (
                            <li key={w.id}>
                              <span>{w.text}</span> {w.minutes ? <span className="muted neg-num-inline">{fmtMin(w.minutes)}</span> : null}
                            </li>
                          ))}
                        </ul>
                      ) : (
                        <div className="small muted">Nothing.</div>
                      )}
                    </div>
                    <div>
                      <div className="neg-card-title neg-card-future"><span className="neg-label-dot" aria-hidden />Future You</div>
                      {d.needs.length ? (
                        <ul className="neg-mini">
                          {d.needs.map((n) => (
                            <li key={n.id} className={n.done ? 'done' : 'undone'}>
                              <i className={`neg-sdot ${n.done ? 'neg-sdot-kept' : 'neg-sdot-broken'}`} aria-hidden />
                              <span>{n.text}</span> {n.minutes ? <span className="muted neg-num-inline">{fmtMin(n.minutes)}</span> : null}
                            </li>
                          ))}
                        </ul>
                      ) : (
                        <div className="small muted">Nothing.</div>
                      )}
                    </div>
                  </div>
                  {d.rules.length > 0 && (
                    <ul className="neg-mini">
                      {d.rules.map((r) => (
                        <li key={r.id} className={r.kept === false ? 'undone' : 'done'}>
                          {r.kept !== undefined && <i className={`neg-sdot ${r.kept ? 'neg-sdot-kept' : 'neg-sdot-broken'}`} aria-hidden />}
                          <span>If {r.when}, then {r.then}</span>
                        </li>
                      ))}
                    </ul>
                  )}
                  {d.review && <p className="neg-review-quote">“{d.review}”</p>}
                  {(d.owedOut ?? 0) > 0 && <div className="small neg-red">Carried over: {fmtMin(d.owedOut!)} of need-work.</div>}
                  {d.status === 'open' && past && (
                    <div className="neg-alert-inline">
                      <div className="small muted" style={{ marginBottom: 8 }}>This deal was never closed.</div>
                      <ReviewPanel deal={d} />
                    </div>
                  )}
                  {d.status === 'open' && !past && (
                    <Link className="small" to="/negotiator">Review it on the Today tab</Link>
                  )}
                </div>
              )}
            </li>
          )
        })}
      </ul>
    </div>
  )
}
