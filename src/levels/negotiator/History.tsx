import { Link } from 'react-router-dom'
import { addDays, dayKey, fromDayKey, prettyDay } from '../../lib/date'
import { NegThread, ReviewPanel, StatusChip } from './components'
import { type NegDeal, type NegMessage, completionPct, fmtMin, inheritedOwed, keepStats, keptStreak } from './logic'

export default function History({ deals }: { deals: NegDeal[] }) {
  const today = dayKey()
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

      <div className="neg-log">
        {sorted.map((d) => {
          const past = d.date < today
          // Deals from before negotiations were a conversation: show their two sides as the messages.
          const thread: NegMessage[] = d.thread?.length
            ? d.thread
            : [
                ...d.wants.map((w) => ({ id: w.id, from: 'present' as const, text: w.text })),
                ...d.needs.map((n) => ({ id: n.id, from: 'future' as const, text: n.text })),
              ]
          return (
            <section key={d.id} className="panel neg-log-day">
              <header className="neg-log-head">
                <div>
                  <div className="neg-log-date">{prettyDay(d.date)}</div>
                  <div className="small muted">
                    {fromDayKey(d.date).getFullYear()} · {d.completion ?? completionPct(d.needs)}% kept
                    {d.debtTaken ? ' · borrowed time' : ''}
                  </div>
                </div>
                <StatusChip status={d.status} />
              </header>

              {thread.length > 0 && <NegThread messages={thread} />}

              {d.thread?.length ? (
                <div className="neg-log-terms small">
                  {d.wants.length > 0 && (
                    <div>
                      <span className="neg-log-label neg-log-present">You got</span>{' '}
                      {d.wants.map((w) => w.text + (w.minutes ? ` (${fmtMin(w.minutes)})` : '')).join(' · ')}
                    </div>
                  )}
                  {d.needs.length > 0 && (
                    <div>
                      <span className="neg-log-label neg-log-future">You owed</span>{' '}
                      {d.needs.map((n, i) => (
                        <span key={n.id} className={n.done ? '' : 'muted'}>
                          {i > 0 && ' · '}
                          {n.done ? '✓ ' : d.status === 'open' ? '○ ' : '✗ '}
                          {n.text}
                        </span>
                      ))}
                    </div>
                  )}
                </div>
              ) : null}

              {d.review && <p className="neg-review-quote">“{d.review}”</p>}
              {(d.owedOut ?? 0) > 0 && <div className="small neg-red">Carried over: {fmtMin(d.owedOut!)}.</div>}
              {d.status === 'open' && past && (
                <div className="neg-alert-inline">
                  <div className="small muted" style={{ marginBottom: 8 }}>This deal was never closed.</div>
                  <ReviewPanel deal={d} />
                </div>
              )}
              {d.status === 'open' && !past && (
                <Link className="small" to="/negotiator">Review it on the Today tab</Link>
              )}
            </section>
          )
        })}
      </div>
    </div>
  )
}
