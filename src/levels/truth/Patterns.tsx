import { useMemo } from 'react'
import { Link } from 'react-router-dom'
import { useLiveQuery } from 'dexie-react-hooks'
import { db } from '../../db/db'
import type { TruthKind } from '../../db/types'
import { addDays, dayKey } from '../../lib/date'
import { DAY_MS, KIND_LABEL, type TruthEntry, timeAgo } from './content'
import { changeStatus } from './Ledger'

interface Count {
  label: string
  n: number
}

function count(values: (string | undefined)[]): Count[] {
  const m = new Map<string, Count>()
  for (const v of values) {
    const t = v?.trim()
    if (!t) continue
    const k = t.toLowerCase()
    const c = m.get(k)
    if (c) c.n++
    else m.set(k, { label: t, n: 1 })
  }
  return [...m.values()].sort((a, b) => b.n - a.n || a.label.localeCompare(b.label))
}

function streaks(entries: TruthEntry[]) {
  const days = new Set(entries.map((t) => dayKey(new Date(t.createdAt))))
  const today = dayKey()
  // Current streak: counts today if written, otherwise starts from yesterday (today isn't over yet).
  let cursor = days.has(today) ? today : addDays(today, -1)
  let current = 0
  while (days.has(cursor)) {
    current++
    cursor = addDays(cursor, -1)
  }
  let best = 0
  for (const d of days) {
    if (days.has(addDays(d, -1))) continue
    let len = 0
    let c = d
    while (days.has(c)) {
      len++
      c = addDays(c, 1)
    }
    best = Math.max(best, len)
  }
  // Last 14 days strip
  const strip = Array.from({ length: 14 }, (_, i) => {
    const k = addDays(today, i - 13)
    return { key: k, on: days.has(k) }
  })
  return { current, best, writtenToday: days.has(today), strip, totalDays: days.size }
}

function TopList({ title, items, param, empty }: { title: string; items: Count[]; param: string; empty: string }) {
  const max = items[0]?.n ?? 1
  return (
    <section>
      <div className="truth-section-title">{title}</div>
      {items.length === 0 ? (
        <div className="truth-group truth-group-empty">{empty}</div>
      ) : (
        <ul className="truth-group">
          {items.slice(0, 6).map((c) => (
            <li key={c.label}>
              <Link className="truth-row truth-bar-row" to={`/truth/ledger?${param}=${encodeURIComponent(param === 'tag' ? c.label.toLowerCase() : c.label)}`}>
                <span className="truth-bar-main">
                  <span className="truth-bar-label">{param === 'tag' ? `#${c.label}` : c.label}</span>
                  <span className="truth-bar-track">
                    <span className="truth-bar-fill" style={{ width: `${(c.n / max) * 100}%` }} />
                  </span>
                </span>
                <span className="truth-bar-n">{c.n}</span>
                <Chevron />
              </Link>
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}

function Chevron() {
  return (
    <svg className="truth-chevron" width="7" height="12" viewBox="0 0 7 12" aria-hidden>
      <path d="M1 1l5 5-5 5" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

export default function Patterns() {
  const all = useLiveQuery(() => db.truths.toArray() as Promise<TruthEntry[]>, [])

  const stats = useMemo(() => {
    const list = all ?? []
    const now = Date.now()
    const byKind: Record<TruthKind, number> = { lie: 0, avoided: 0, self: 0 }
    for (const t of list) byKind[t.kind] = (byKind[t.kind] ?? 0) + 1
    const addressed = list.filter((t) => t.status === 'addressed').length
    const pattern = list.filter((t) => t.status === 'pattern').length
    const waiting = list
      .filter((t) => t.status !== 'addressed' && now - t.createdAt >= 7 * DAY_MS)
      .sort((a, b) => a.createdAt - b.createdAt)
    return {
      total: list.length,
      byKind,
      addressed,
      pattern,
      rate: list.length ? Math.round((addressed / list.length) * 100) : 0,
      people: count(list.map((t) => t.who)),
      topics: count(list.map((t) => t.topic)),
      tags: count(list.flatMap((t) => t.tags ?? [])),
      waiting,
      streak: streaks(list),
    }
  }, [all])

  if (!all) return <div className="empty">Loading…</div>

  if (stats.total === 0)
    return (
      <div className="empty truth-empty">
        <p className="truth-empty-title">No patterns yet</p>
        <p className="small" style={{ marginTop: 4 }}>
          They appear after a few entries. <Link to="/truth">Start with one true sentence</Link>.
        </p>
      </div>
    )

  const { streak } = stats
  const kindMax = Math.max(1, ...Object.values(stats.byKind))

  return (
    <div className="stack truth-patterns">
      <div className="truth-stats">
        <div className="panel truth-stat">
          <div className="truth-stat-label">Streak</div>
          <div className="truth-stat-value">
            <span className="big-number">{streak.current}</span>
            <span className="truth-stat-unit">{streak.current === 1 ? 'day' : 'days'}</span>
          </div>
          <div className="truth-strip" aria-label="Last 14 days">
            {streak.strip.map((d) => (
              <span key={d.key} className={`truth-strip-day ${d.on ? 'on' : ''}`} title={d.key} />
            ))}
          </div>
          <div className="truth-stat-foot">
            Best {streak.best} · {streak.totalDays} honest {streak.totalDays === 1 ? 'day' : 'days'}
            {!streak.writtenToday && streak.current > 0 ? ' · today still open' : ''}
          </div>
        </div>

        <div className="panel truth-stat">
          <div className="truth-stat-label">Addressed</div>
          <div className="truth-ring-wrap">
            <svg viewBox="0 0 36 36" className="truth-ring" aria-hidden>
              <circle cx="18" cy="18" r="15.5" className="truth-ring-bg" />
              {stats.rate > 0 && <circle cx="18" cy="18" r="15.5" className="truth-ring-fg" pathLength={100} strokeDasharray={`${stats.rate} ${100 - stats.rate}`} />}
            </svg>
            <div>
              <div className="big-number">{stats.rate}%</div>
              <div className="truth-stat-foot">
                {stats.addressed} of {stats.total} said out loud or fixed
              </div>
            </div>
          </div>
          <div className="truth-stat-foot">Writing it down is step one. Addressing it is optional, and it counts when you do.</div>
        </div>

        <div className="panel truth-stat">
          <div className="truth-stat-label">By kind</div>
          <ul className="truth-kind-bars">
            {(Object.keys(stats.byKind) as TruthKind[]).map((k) => (
              <li key={k}>
                <Link className="truth-kind-bar" to={`/truth/ledger?kind=${k}`}>
                  <span className="truth-kind-bar-top">
                    <span>{KIND_LABEL[k]}</span>
                    <span className="truth-bar-n">{stats.byKind[k]}</span>
                  </span>
                  <span className="truth-bar-track">
                    <span className={`truth-bar-fill truth-fill-${k}`} style={{ width: `${(stats.byKind[k] / kindMax) * 100}%` }} />
                  </span>
                </Link>
              </li>
            ))}
          </ul>
          {stats.pattern > 0 && <div className="truth-stat-foot">{stats.pattern} marked as a recurring pattern</div>}
        </div>
      </div>

      <section>
        <div className="truth-section-title truth-list-head">
          <span>Worth revisiting</span>
          {stats.waiting.length > 3 && (
            <Link className="truth-text-btn" to="/truth/ledger?old=1">
              See all {stats.waiting.length}
            </Link>
          )}
        </div>
        {stats.waiting.length === 0 ? (
          <div className="truth-group truth-group-empty">Nothing has been waiting more than a week. Nice and current.</div>
        ) : (
          <>
            <ul className="truth-group truth-list">
              {stats.waiting.slice(0, 3).map((t) => (
                <li key={t.id} className="truth-entry">
                  <div className="truth-entry-head">
                    <span className={`truth-kind truth-kind-${t.kind}`}>{KIND_LABEL[t.kind]}</span>
                    {t.who && <span className="truth-link">{t.who}</span>}
                    <span className="spacer" />
                    <span className="truth-time">{timeAgo(t.createdAt)}</span>
                  </div>
                  <p className="truth-entry-text">{t.text}</p>
                  <div className="truth-entry-foot">
                    <button type="button" className="btn btn-sm" onClick={() => changeStatus(t, 'addressed')}>
                      I addressed it
                    </button>
                    {t.status !== 'pattern' && (
                      <button type="button" className="btn btn-ghost btn-sm truth-ghost-muted" onClick={() => changeStatus(t, 'pattern')}>
                        It’s a pattern
                      </button>
                    )}
                  </div>
                </li>
              ))}
            </ul>
            <div className="truth-footnote">These have been sitting for over a week. No pressure. Pick one only if you’re ready.</div>
          </>
        )}
      </section>

      <div className="truth-tops">
        <TopList title="People who come up" items={stats.people} param="who" empty="No names yet. Add a “who” to see who comes up." />
        <TopList title="Recurring topics" items={stats.topics} param="topic" empty="No topics yet." />
        <TopList title="Repeating tags" items={stats.tags} param="tag" empty="No tags yet." />
      </div>
    </div>
  )
}
