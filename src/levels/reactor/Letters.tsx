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

function countdown(ms: number) {
  const s = Math.max(0, Math.floor(ms / 1000))
  const d = Math.floor(s / 86400)
  const h = Math.floor((s % 86400) / 3600)
  const m = Math.floor((s % 3600) / 60)
  const sec = s % 60
  const pad = (n: number) => String(n).padStart(2, '0')
  return { d, text: `${pad(h)}:${pad(m)}:${pad(sec)}` }
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
  const now = useNow(1000)
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
    setFlash('Future You has written back. Find it below.')
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

  return (
    <section className="panel rx-letters">
      <div className="panel-title">Letters across time</div>
      <div className="row-between">
        <h2 className="rx-section-title">Write to the person you are becoming</h2>
        <div className="rx-tabs" role="tablist">
          <button role="tab" aria-selected={mode === 'future'} className={'rx-tab' + (mode === 'future' ? ' active' : '')} onClick={() => setMode('future')}>
            To Future You
          </button>
          <button role="tab" aria-selected={mode === 'present'} className={'rx-tab' + (mode === 'present' ? ' active' : '')} onClick={() => setMode('present')}>
            Future You writes back
          </button>
        </div>
      </div>

      {mode === 'future' ? (
        <div className="stack-sm rx-compose">
          <label className="label" htmlFor="rx-letter">
            Tell them what you are sacrificing for them, what you hope they have, what you are afraid of. They will read it on the day you choose,
            and not a second earlier.
          </label>
          <textarea
            id="rx-letter"
            className="textarea rx-paper"
            placeholder="Dear Future Me,"
            value={body}
            onChange={(e) => setBody(e.target.value)}
          />
          <div className="row rx-presets">
            <span className="small muted">Unlocks in</span>
            {PRESETS.map((p) => (
              <button key={p.key} type="button" className={'chip rx-chip-btn' + (preset === p.key ? ' active' : '')} onClick={() => setPreset(p.key)}>
                {p.label}
              </button>
            ))}
            {preset === 'custom' && (
              <input type="date" className="input rx-date" min={minCustom} value={custom} onChange={(e) => setCustom(e.target.value)} aria-label="Unlock date" />
            )}
          </div>
          <div className="row-between">
            <span className="small muted mono">{unlockAt ? `Opens ${fmtDate(unlockAt)}` : 'Pick a future date'}</span>
            <button className="btn btn-primary" disabled={!body.trim() || !unlockAt} onClick={seal}>
              Seal letter
            </button>
          </div>
        </div>
      ) : (
        <div className="stack-sm rx-compose">
          <p className="rx-reply-intro">
            Close your eyes for ten seconds. It is <strong>{fmtDate(oneYear.getTime())}</strong>. You are one year older, and you kept going. Now write
            to the you reading this today.
          </p>
          <ul className="rx-prompts">
            {REPLY_PROMPTS.map((p) => (
              <li key={p}>{p}</li>
            ))}
          </ul>
          <textarea
            className="textarea rx-paper rx-paper-future"
            placeholder="Hey. It's me, a year from now..."
            value={reply}
            onChange={(e) => setReply(e.target.value)}
          />
          <div className="row-between">
            <span className="small muted">Opens immediately. Read it when present-you wavers.</span>
            <button className="btn btn-primary" disabled={!reply.trim()} onClick={saveReply}>
              Send it back in time
            </button>
          </div>
        </div>
      )}

      {flash && (
        <div className="rx-flash" role="status">
          {flash}
        </div>
      )}

      {ready.length > 0 && (
        <div className="rx-letter-group">
          <div className="rx-group-title rx-group-ready">Ready to open</div>
          <div className="rx-envelopes">
            {ready.map((l) => (
              <button key={l.id} className="rx-envelope rx-envelope-ready" onClick={() => open(l)}>
                <span className="rx-env-seal" aria-hidden />
                <span className="rx-env-meta">Written {fmtDate(l.createdAt)}</span>
                <span className="rx-env-cta">Unlocked. Open it →</span>
              </button>
            ))}
          </div>
        </div>
      )}

      {sealed.length > 0 && (
        <div className="rx-letter-group">
          <div className="rx-group-title">Sealed · {sealed.length}</div>
          <div className="rx-envelopes">
            {sealed.map((l) => {
              const c = countdown(l.unlockAt - now)
              return (
                <div key={l.id} className="rx-envelope rx-envelope-sealed" aria-label={`Sealed letter, opens ${fmtDate(l.unlockAt)}`}>
                  <span className="rx-env-lock" aria-hidden>
                    <svg viewBox="0 0 24 24" width="16" height="16">
                      <rect x="5" y="11" width="14" height="10" rx="2" fill="none" stroke="currentColor" strokeWidth="1.6" />
                      <path d="M8 11V8a4 4 0 0 1 8 0v3" fill="none" stroke="currentColor" strokeWidth="1.6" />
                    </svg>
                  </span>
                  <span className="rx-env-count mono">
                    {c.d > 0 && <b>{c.d}d </b>}
                    {c.text}
                  </span>
                  <span className="rx-env-meta">Opens {fmtDate(l.unlockAt)}</span>
                  <span className="rx-env-meta">Written {fmtDate(l.createdAt)}</span>
                </div>
              )
            })}
          </div>
        </div>
      )}

      <div className="rx-letter-group">
        <div className="rx-group-title">Opened letters</div>
        {opened.length === 0 ? (
          <div className="empty small">No opened letters yet. The first one you seal becomes a message waiting for you on the other side.</div>
        ) : (
          <div className="stack-sm">
            {opened.map((l) => {
              const isOpen = expanded === l.id
              return (
                <article
                  key={l.id}
                  className={'rx-opened' + (l.to === 'present' ? ' rx-from-future' : '') + (revealId === l.id ? ' rx-reveal' : '') + (isOpen ? ' expanded' : '')}
                >
                  <button className="rx-opened-head" onClick={() => setExpanded(isOpen ? null : (l.id ?? null))} aria-expanded={isOpen}>
                    <span className="rx-opened-dir">{l.to === 'present' ? 'From Future You' : 'To Future You'}</span>
                    <span className="rx-opened-date mono">{fmtDate(l.createdAt)}</span>
                    {!isOpen && <span className="rx-opened-preview">{l.body}</span>}
                  </button>
                  {isOpen && (
                    <div className="rx-opened-body">
                      <p className="rx-letter-text">{l.body}</p>
                      <div className="row-between">
                        <span className="small muted">
                          {l.to === 'future'
                            ? `Sealed for ${Math.max(1, Math.round((l.unlockAt - l.createdAt) / DAY))} days`
                            : 'Imagined from one year ahead'}
                        </span>
                        <button className="btn btn-ghost btn-sm" onClick={() => remove(l)}>
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
