import { useMemo } from 'react'
import { addDays, dayKey, prettyDay } from '../../lib/date'
import { setVote, toggleVote, habitStats, tinyFor, type DoneIndex, type ForgeHabit, type ForgeLog, type HabitStats } from './stats'

function plural(n: number, one: string, many = one + 's') {
  return `${n} ${n === 1 ? one : many}`
}

function StatusLine({ s, tinyToday }: { s: HabitStats; tinyToday: boolean }) {
  switch (s.state) {
    case 'done':
      return (
        <p className="forge-status done">
          {tinyToday ? 'Tiny version done. Showing up is what counts.' : 'Vote cast. One more brick laid.'}
        </p>
      )
    case 'new':
      return <p className="forge-status">Fresh on the anvil. Your first vote can be today.</p>
    case 'missed-one':
      return <p className="forge-status">Yesterday was a rest day. That's fine. Today is the one that counts.</p>
    case 'open':
      return <p className="forge-status">Today's vote is open.</p>
    default:
      return null
  }
}

function HabitCard({ h, done, logsToday, today }: { h: ForgeHabit; done: Set<string> | undefined; logsToday: Map<number, ForgeLog>; today: string }) {
  const s = habitStats(h, done, today)
  const yesterday = addDays(today, -1)
  const tinyToday = !!logsToday.get(h.id!)?.tiny
  const tiny = tinyFor(h)

  return (
    <article className={`panel forge-panel forge-card ${s.doneToday ? 'is-done' : ''} ${s.state === 'recover' ? 'is-recover' : ''}`}>
      <div className="forge-card-top">
        <button
          className={`forge-vote ${s.doneToday ? 'on' : ''}`}
          onClick={() => toggleVote(h.id!, today)}
          aria-pressed={s.doneToday}
          aria-label={s.doneToday ? `Undo today's vote for ${h.name}` : `Cast today's vote for ${h.name}`}
        >
          <span className="forge-vote-mark">{s.doneToday ? '✓' : '+'}</span>
          <span className="forge-vote-text">{s.doneToday ? 'Voted' : 'Vote'}</span>
        </button>
        <div className="forge-card-head">
          <h3 className="forge-habit-name">{h.name}</h3>
          <div className="forge-identity">{h.identity}</div>
        </div>
      </div>

      {s.state === 'recover' ? (
        <div className="forge-recover">
          <p>
            It's been a few quiet days. That happens to everyone who builds anything. No catching up needed, just one small vote to warm the iron again.
          </p>
          <button className="btn forge-btn-primary" onClick={() => setVote(h.id!, today, true, true)}>
            Do the tiny version: {tiny}
          </button>
        </div>
      ) : (
        <StatusLine s={s} tinyToday={tinyToday} />
      )}

      <div className="forge-votes">
        <span className="forge-votes-n mono">{s.votes}</span>
        <span className="forge-votes-label">
          {s.votes === 1 ? 'vote' : 'votes'} for: <em>{h.identity}</em>
        </span>
      </div>

      <div className="forge-meter" title={`${s.windowDone} of ${s.windowDays} days`}>
        <div className="row-between small">
          <span className="muted">Consistency · {!s.sinceStart ? 'last 30 days' : `since start (${plural(s.windowDays, 'day')})`}</span>
          <span className="mono forge-pct">{s.windowDays ? `${s.consistency}%` : '—'}</span>
        </div>
        <div className="forge-bar"><div className="forge-bar-fill" style={{ width: `${s.consistency}%` }} /></div>
      </div>

      <div className="row-between forge-card-foot small">
        <span className="muted">
          {s.run > 0 ? `Current run ${plural(s.run, 'day')}` : 'Next run starts with your next vote'}
          {s.best > 1 ? ` · best ${s.best}` : ''}
        </span>
        <button
          className={`chip forge-chip ${s.doneYesterday ? 'active' : ''}`}
          onClick={() => toggleVote(h.id!, yesterday)}
          title="Forgot to check in yesterday? Log it here."
        >
          {s.doneYesterday ? '✓ Yesterday logged' : '+ Log yesterday'}
        </button>
      </div>
      {!s.doneToday && s.state !== 'recover' && (
        <button className="btn btn-ghost btn-sm forge-tiny-link" onClick={() => setVote(h.id!, today, true, true)}>
          Low-energy day? Do the tiny version: {tiny}
        </button>
      )}
    </article>
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
          <span />
        </div>
        <h3>Nothing on the anvil yet</h3>
        <p className="muted">
          Pick one small habit and attach an identity to it. Each time you do it, you cast a vote for who you're becoming.
        </p>
        <button className="btn forge-btn-primary" onClick={onAddHabit}>Forge your first habit</button>
      </div>
    )
  }

  const allDone = doneCount === active.length
  return (
    <div className="stack">
      <div className="forge-today-bar">
        <div>
          <div className="panel-title forge-tight">{prettyDay(today)}</div>
          <div className="forge-today-msg">
            {allDone
              ? 'Every vote cast today. The iron holds its shape.'
              : doneCount === 0
                ? 'The forge is lit. One vote is enough to start.'
                : `${doneCount} of ${active.length} votes cast. Steady.`}
          </div>
        </div>
        <div className="forge-pips" aria-label={`${doneCount} of ${active.length} done`}>
          {active.map((h) => (
            <span key={h.id} className={`forge-pip ${logsToday.has(h.id!) ? 'on' : ''}`} />
          ))}
        </div>
      </div>

      {experiment && (
        <div className="forge-experiment">
          <span className="forge-experiment-tag mono">This week's experiment</span>
          <span>{experiment}</span>
        </div>
      )}

      <div className="forge-cards">
        {active.map((h) => (
          <HabitCard key={h.id} h={h} done={idx.get(h.id!)} logsToday={logsToday} today={today} />
        ))}
      </div>
    </div>
  )
}
