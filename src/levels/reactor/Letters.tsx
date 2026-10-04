import { useEffect, useState } from 'react'
import { useLiveQuery } from 'dexie-react-hooks'
import { db } from '../../db/db'
import type { Letter } from '../../db/types'
import { dayKey } from '../../lib/date'

const DAY = 86_400_000

type PresetKey = 'week' | 'month' | 'quarter' | 'year' | 'custom'
const PRESETS: { key: PresetKey; label: string }[] = [
  { key: 'week', label: '1 week' },
  { key: 'month', label: '1 month' },
  { key: 'quarter', label: '3 months' },
  { key: 'year', label: '1 year' },
  { key: 'custom', label: 'Custom' },
]

function unlockFor(preset: PresetKey, custom: string): number | null {
  const d = new Date()
  switch (preset) {
    case 'week':
      d.setDate(d.getDate() + 7)
      return d.getTime()
    case 'month':
      d.setMonth(d.getMonth() + 1)
      return d.getTime()
    case 'quarter':
      d.setMonth(d.getMonth() + 3)
      return d.getTime()
    case 'year':
      d.setFullYear(d.getFullYear() + 1)
      return d.getTime()
    case 'custom': {
      if (!custom) return null
      const [y, m, day] = custom.split('-').map(Number)
      const t = new Date(y, m - 1, day, 8, 0, 0).getTime() // opens 8am that day
      return t > Date.now() ? t : null
    }
  }
}

function fmtDate(ms: number) {
  return new Date(ms).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })
}

/** A calm, coarse countdown: days, then hours, then minutes. */
function countdown(ms: number) {
  const min = Math.max(0, Math.ceil(ms / 60_000))
  const d = Math.floor(min / 1440)
  const h = Math.floor((min % 1440) / 60)
  const m = min % 60
  if (d >= 2) return `in ${d} days`
  if (d === 1) return h > 0 ? `in 1 day, ${h} h` : 'in 1 day'
  if (h > 0) return `in ${h} h ${m} min`
  return m <= 1 ? 'in a minute' : `in ${m} min`
}

function useNow(interval = 1000) {
  const [now, setNow] = useState(() => Date.now())
  useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), interval)
    return () => window.clearInterval(id)
  }, [interval])
  return now
}

const REPLY_PROMPTS = [
  'Where are you sitting, one year from now? Describe the room.',
  'What are you quietly proud that present-you started this week?',
  'What did present-you worry about that turned out not to matter?',
  'What do you need present-you to stop, or start, today?',
]

export default function Letters() {
  const now = useNow(30_000)
  const letters = useLiveQuery(() => db.letters.orderBy('unlockAt').toArray(), [])

  const [mode, setMode] = useState<'future' | 'present'>('future')
  const [body, setBody] = useState('')
  const [preset, setPreset] = useState<PresetKey>('month')
  const [custom, setCustom] = useState('')
  const [reply, setReply] = useState('')
  const [revealId, setRevealId] = useState<number | null>(null)
  const [expanded, setExpanded] = useState<number | null>(null)
  const [flash, setFlash] = useState('')

  const unlockAt = unlockFor(preset, custom)
  const minCustom = dayKey(new Date(Date.now() + DAY))
  const oneYear = new Date()
  oneYear.setFullYear(oneYear.getFullYear() + 1)

  async function seal() {
    if (!body.trim() || !unlockAt) return
    await db.letters.add({ createdAt: Date.now(), unlockAt, body: body.trim(), to: 'future', opened: false })
    setBody('')
    setFlash(`Sealed. It opens on ${fmtDate(unlockAt)}.`)
    window.setTimeout(() => setFlash(''), 4000)
  }

  async function saveReply() {
    if (!reply.trim()) return
    const t = Date.now()
    const id = await db.letters.add({ createdAt: t, unlockAt: t, body: reply.trim(), to: 'present', opened: true })
    setReply('')
    setExpanded(id as number)
    setFlash('Saved. You’ll find it under Opened.')
    window.setTimeout(() => setFlash(''), 4000)
  }

  async function open(l: Letter) {
    if (l.id == null || l.unlockAt > Date.now()) return
    await db.letters.update(l.id, { opened: true })
    setRevealId(l.id)
    setExpanded(l.id)
  }

  async function remove(l: Letter) {
    if (l.id == null) return
    if (!window.confirm('Delete this letter for good?')) return
    await db.letters.delete(l.id)
  }

  const all = letters ?? []
  const sealed = all.filter((l) => !l.opened && l.unlockAt > now)
  const ready = all.filter((l) => !l.opened && l.unlockAt <= now)
  const opened = all.filter((l) => l.opened).sort((a, b) => b.createdAt - a.createdAt)

  const lockIcon = (
    <svg viewBox="0 0 24 24" width="16" height="16" aria-hidden>
      <rect x="5" y="11" width="14" height="10" rx="2.5" fill="none" stroke="currentColor" strokeWidth="1.8" />
      <path d="M8 11V8a4 4 0 0 1 8 0v3" fill="none" stroke="currentColor" strokeWidth="1.8" />
    </svg>
  )
  const envIcon = (
    <svg viewBox="0 0 24 24" width="16" height="16" aria-hidden>
      <rect x="3.5" y="6" width="17" height="12.5" rx="2.5" fill="none" stroke="currentColor" strokeWidth="1.8" />
      <path d="M4.5 7.5l7.5 6 7.5-6" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" />
    </svg>
  )

  return (
    <section className="home-section home-letters">
      <h2 className="home-section-title">Letters</h2>

      <div className="panel home-compose">
        <div className="home-segmented" role="tablist" aria-label="Letter type">
          <button role="tab" aria-selected={mode === 'future'} className={mode === 'future' ? 'active' : ''} onClick={() => setMode('future')}>
            To Future You
          </button>
          <button role="tab" aria-selected={mode === 'present'} className={mode === 'present' ? 'active' : ''} onClick={() => setMode('present')}>
            From Future You
          </button>
        </div>

        {mode === 'future' ? (
          <div className="stack-sm home-compose-body" key="future">
            <label className="home-compose-hint" htmlFor="home-letter">
              Write to the person you are becoming: what you’re giving up for them, what you hope they have, what worries you. It stays sealed
              until the day you choose.
            </label>
            <textarea id="home-letter" className="textarea" placeholder="Dear Future Me," value={body} onChange={(e) => setBody(e.target.value)} />
            <div className="row home-presets">
              <span className="small muted">Opens in</span>
              {PRESETS.map((p) => (
                <button key={p.key} type="button" className={'chip home-chip-btn' + (preset === p.key ? ' active' : '')} onClick={() => setPreset(p.key)}>
                  {p.label}
                </button>
              ))}
              {preset === 'custom' && (
                <input type="date" className="input home-date-input" min={minCustom} value={custom} onChange={(e) => setCustom(e.target.value)} aria-label="Opening date" />
              )}
            </div>
            <div className="row-between home-compose-foot">
              <span className="small muted">{unlockAt ? `Opens ${fmtDate(unlockAt)}` : 'Choose a future date'}</span>
              <button className="btn btn-primary" disabled={!body.trim() || !unlockAt} onClick={seal}>
                Seal letter
              </button>
            </div>
          </div>
        ) : (
          <div className="stack-sm home-compose-body" key="present">
            <p className="home-compose-hint">
              Imagine it’s <strong>{fmtDate(oneYear.getTime())}</strong>. You’re a year older and you kept going. Write to the you reading this
              today.
            </p>
            <ul className="home-prompts">
              {REPLY_PROMPTS.map((p) => (
                <li key={p}>{p}</li>
              ))}
            </ul>
            <textarea className="textarea" placeholder="Hey. It’s me, a year from now…" value={reply} onChange={(e) => setReply(e.target.value)} />
            <div className="row-between home-compose-foot">
              <span className="small muted">Opens right away, for days when you need it.</span>
              <button className="btn btn-primary" disabled={!reply.trim()} onClick={saveReply}>
                Save letter
              </button>
            </div>
          </div>
        )}

        {flash && (
          <div className="home-flash" role="status">
            {flash}
          </div>
        )}
      </div>

      {ready.length > 0 && (
        <div className="home-group">
          <div className="home-group-title">Ready to open</div>
          <div className="panel home-list">
            {ready.map((l) => (
              <button key={l.id} className="home-row home-row-button" onClick={() => open(l)}>
                <span className="home-row-icon ready">{envIcon}</span>
                <span className="home-row-main">
                  <span className="home-row-title">Letter from {fmtDate(l.createdAt)}</span>
                  <span className="home-row-sub">Ready to read</span>
                </span>
                <span className="home-row-action">Open</span>
              </button>
            ))}
          </div>
        </div>
      )}

      {sealed.length > 0 && (
        <div className="home-group">
          <div className="home-group-title">Sealed · {sealed.length}</div>
          <div className="panel home-list">
            {sealed.map((l) => (
              <div key={l.id} className="home-row" aria-label={`Sealed letter, opens ${fmtDate(l.unlockAt)}`}>
                <span className="home-row-icon">{lockIcon}</span>
                <span className="home-row-main">
                  <span className="home-row-title">Opens {fmtDate(l.unlockAt)}</span>
                  <span className="home-row-sub">Written {fmtDate(l.createdAt)}</span>
                </span>
                <span className="home-row-value">{countdown(l.unlockAt - now)}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="home-group">
        <div className="home-group-title">Opened</div>
        {opened.length === 0 ? (
          <div className="panel home-list-empty small muted">No opened letters yet. The first one you seal will be waiting for you on the other side.</div>
        ) : (
          <div className="panel home-list">
            {opened.map((l) => {
              const isOpen = expanded === l.id
              return (
                <article key={l.id} className={'home-letter' + (revealId === l.id ? ' reveal' : '') + (isOpen ? ' expanded' : '')}>
                  <button className="home-row home-row-button" onClick={() => setExpanded(isOpen ? null : (l.id ?? null))} aria-expanded={isOpen}>
                    <span className={'home-row-icon' + (l.to === 'present' ? ' future' : ' ready')}>{envIcon}</span>
                    <span className="home-row-main">
                      <span className="home-row-title">{l.to === 'present' ? 'From Future You' : 'To Future You'}</span>
                      <span className="home-row-sub">{isOpen ? fmtDate(l.createdAt) : l.body}</span>
                    </span>
                    {!isOpen && <span className="home-row-value">{fmtDate(l.createdAt)}</span>}
                    <svg viewBox="0 0 8 14" width="8" height="14" className="home-row-chevron" aria-hidden>
                      <path d="M1.5 1.5L6.5 7l-5 5.5" />
                    </svg>
                  </button>
                  {isOpen && (
                    <div className="home-letter-body">
                      <p className="home-letter-text">{l.body}</p>
                      <div className="row-between">
                        <span className="small muted">
                          {l.to === 'future'
                            ? `Sealed for ${Math.max(1, Math.round((l.unlockAt - l.createdAt) / DAY))} days`
                            : 'Written from one year ahead'}
                        </span>
                        <button className="btn btn-ghost btn-sm btn-danger" onClick={() => remove(l)}>
                          Delete
                        </button>
                      </div>
                    </div>
                  )}
                </article>
              )
            })}
          </div>
        )}
      </div>
    </section>
  )
}
