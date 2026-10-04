import { useMemo } from 'react'
import { addDays, dayKey, prettyDay } from '../../lib/date'
import { setVote, toggleVote, habitStats, tinyFor, type DoneIndex, type ForgeHabit, type ForgeLog, type HabitStats } from './stats'

function plural(n: number, one: string, many = one + 's') {
  return `${n} ${n === 1 ? one : many}`
}

function statusText(s: HabitStats, tinyToday: boolean): string | null {
  switch (s.state) {
    case 'done':
      return tinyToday ? 'Tiny version done. Showing up is what counts.' : 'Done for today.'
    case 'new':
      return 'New habit. Today can be day one.'
    case 'missed-one':
      return "Yesterday was a rest day. That's fine, today is the one that counts."
    default:
      return null
  }
}

function Check({ on }: { on: boolean }) {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden className={`forge-check-icon ${on ? 'on' : ''}`}>
      <path d="M5 12.5l4.5 4.5L19 7.5" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

function HabitRow({ h, done, logsToday, today }: { h: ForgeHabit; done: Set<string> | undefined; logsToday: Map<number, ForgeLog>; today: string }) {
  const s = habitStats(h, done, today)
  const yesterday = addDays(today, -1)
  const tinyToday = !!logsToday.get(h.id!)?.tiny
  const tiny = tinyFor(h)
  const status = statusText(s, tinyToday)
  const windowLabel = `Last ${!s.sinceStart ? '30 days' : plural(s.windowDays, 'day')}`

  return (
    <li className={`forge-habit ${s.doneToday ? 'is-done' : ''}`}>
      <div className="forge-habit-top">
        <button
          className={`forge-check ${s.doneToday ? 'on' : ''}`}
          onClick={() => toggleVote(h.id!, today)}
          aria-pressed={s.doneToday}
          aria-label={s.doneToday ? `Mark ${h.name} as not done today` : `Mark ${h.name} as done today`}
        >
          <Check on={s.doneToday} />
        </button>
        <div className="forge-habit-main">
          <h3 className="forge-habit-name">{h.name}</h3>
          <div className="forge-identity">{h.identity}</div>
        </div>
        <div className="forge-habit-pct" title={`${s.windowDone} of ${s.windowDays} days`}>
          <span className="forge-pct">{s.windowDays ? `${s.consistency}%` : '—'}</span>
          <span className="forge-pct-l">{windowLabel}</span>
        </div>
      </div>

      <div className="forge-habit-body">
        {s.state === 'recover' ? (
          <div className="forge-recover">
            <p>It's been a few quiet days. That happens to everyone. No need to catch up, just do the smallest version today.</p>
            <button className="btn btn-gold btn-sm forge-wrap" onClick={() => setVote(h.id!, today, true, true)}>
              Do the tiny version: {tiny}
            </button>
          </div>
        ) : (
          status && <p className={`forge-status ${s.doneToday ? 'done' : ''}`}>{status}</p>
        )}

        <div className="forge-habit-meta">
          <span className="forge-meta-text">
            {plural(s.votes, 'check-in')}
            {s.run > 0 ? ` · ${plural(s.run, 'day')} in a row` : ''}
            {s.best > 1 ? ` · best ${s.best}` : ''}
          </span>
          <span className="forge-meta-actions">
            {!s.doneToday && s.state !== 'recover' && (
              <button className="forge-link" onClick={() => setVote(h.id!, today, true, true)} title={`Tiny version: ${tiny}`}>
                Tiny version
              </button>
            )}
            <button
              className={`forge-pill ${s.doneYesterday ? 'on' : ''}`}
              onClick={() => toggleVote(h.id!, yesterday)}
              title="Forgot to check in yesterday? Log it here."
            >
              {s.doneYesterday ? '✓ Yesterday' : '+ Yesterday'}
            </button>
          </span>
        </div>
      </div>
    </li>
  )
}

export default function TodayTab({
  habits,
  idx,
  logs,
  experiment,
  onAddHabit,
}: {
  habits: ForgeHabit[]
  idx: DoneIndex
  logs: ForgeLog[]
  experiment?: string
  onAddHabit: () => void
}) {
  const today = dayKey()
  const active = habits.filter((h) => !h.archived)
  const logsToday = useMemo(() => {
    const m = new Map<number, ForgeLog>()
    for (const l of logs) if (l.date === today && l.done) m.set(l.habitId, l)
    return m
  }, [logs, today])
  const doneCount = active.filter((h) => logsToday.has(h.id!)).length

  if (active.length === 0) {
    return (
      <div className="empty forge-empty">
        <div className="forge-empty-icon" aria-hidden>
          <Check on />
        </div>
        <h3>No habits yet</h3>
        <p className="muted">
          Pick one small habit and attach an identity to it. Each time you do it, you cast a vote for who you're becoming.
        </p>
        <button className="btn btn-gold" onClick={onAddHabit}>Add your first habit</button>
      </div>
    )
  }

  const allDone = doneCount === active.length
  const pct = Math.round((doneCount / active.length) * 100)
  return (
    <div className="stack">
      <section className="panel forge-today">
        <div className="row-between forge-today-head">
          <div className="forge-today-date">{prettyDay(today)}</div>
          <div className="forge-today-count">{pct}%</div>
        </div>
        <div className="forge-today-msg">
          {allDone
            ? 'Everything done today. Nice work.'
            : doneCount === 0
              ? 'One check is enough to get going.'
              : `${doneCount} of ${active.length} done. Keep it steady.`}
        </div>
        <div className="forge-bar" role="progressbar" aria-valuenow={pct} aria-valuemin={0} aria-valuemax={100}>
          <div className="forge-bar-fill" style={{ width: `${pct}%` }} />
        </div>
      </section>

      {experiment && (
        <div className="forge-experiment">
          <span className="forge-experiment-tag">This week's experiment</span>
          <span>{experiment}</span>
        </div>
      )}

      <ul className="forge-group forge-habits-list">
        {active.map((h) => (
          <HabitRow key={h.id} h={h} done={idx.get(h.id!)} logsToday={logsToday} today={today} />
        ))}
      </ul>
    </div>
  )
}
