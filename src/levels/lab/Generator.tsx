import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useLiveQuery } from 'dexie-react-hooks'
import { db } from '../../db/db'
import { dayKey } from '../../lib/date'
import { CATEGORIES, CATEGORY_COLORS, CATEGORY_GLYPHS, TOPICS, topicOfTheDay, type Category, type Topic } from './topics'
import { pickPrompt } from './prompts'
import { SearchLinks, type LabEntryX } from './shared'

type Mode = 1 | 2 | 3
const MODES: { n: Mode; label: string; sub: string }[] = [
  { n: 1, label: 'Single', sub: 'one rabbit hole' },
  { n: 2, label: 'Collision', sub: 'two worlds' },
  { n: 3, label: 'Triple', sub: 'pure chaos' },
]

function load<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key)
    return raw ? (JSON.parse(raw) as T) : fallback
  } catch {
    return fallback
  }
}
function save(key: string, value: unknown) {
  try {
    localStorage.setItem(key, JSON.stringify(value))
  } catch {
    /* ignore */
  }
}

const rand = <T,>(arr: T[]): T => arr[Math.floor(Math.random() * arr.length)]

export default function Generator() {
  const [mode, setModeState] = useState<Mode>(() => load<Mode>('lab.mode', 2))
  const [filter, setFilter] = useState<Category[]>(() => load<Category[]>('lab.filter', []))
  const [slots, setSlots] = useState<(Topic | null)[]>(() => Array(3).fill(null))
  const [locked, setLocked] = useState<boolean[]>([false, false, false])
  const [rolling, setRolling] = useState<boolean[]>([false, false, false])
  const [display, setDisplay] = useState<string[]>(['', '', ''])
  const [landed, setLanded] = useState<number[]>([0, 0, 0])
  const [prompt, setPrompt] = useState('')
  const [connection, setConnection] = useState('')
  const [notes, setNotes] = useState('')
  const [links, setLinks] = useState('')
  const [starred, setStarred] = useState(false)
  const [flash, setFlash] = useState('')
  const timers = useRef<number[]>([])

  const today = dayKey()
  const totd = topicOfTheDay(today)

  const entries = useLiveQuery(() => db.lab.toArray(), []) as LabEntryX[] | undefined
  const exploredCount = useMemo(() => {
    const m = new Map<string, number>()
    for (const e of entries ?? []) for (const t of e.topics) m.set(t, (m.get(t) ?? 0) + 1)
    return m
  }, [entries])

  const pool = useMemo(() => (filter.length ? TOPICS.filter((t) => filter.includes(t.category)) : TOPICS), [filter])

  useEffect(() => save('lab.mode', mode), [mode])
  useEffect(() => save('lab.filter', filter), [filter])
  useEffect(() => () => timers.current.forEach((t) => clearTimeout(t)), [])

  const active = slots.slice(0, mode)
  const anyRolling = rolling.slice(0, mode).some(Boolean)
  const drawn = active.every(Boolean) ? (active as Topic[]) : null

  const setMode = (m: Mode) => {
    if (anyRolling) return
    setModeState(m)
    const names = slots.slice(0, m)
    if (m > 1 && names.every(Boolean)) setPrompt(pickPrompt(names.map((t) => t!.name)))
    else setPrompt('')
  }

  const toggleCat = (c: Category) => setFilter((f) => (f.includes(c) ? f.filter((x) => x !== c) : [...f, c]))

  const spin = useCallback(() => {
    if (anyRolling) return
    timers.current.forEach((t) => clearTimeout(t))
    timers.current = []
    const final = slots.slice()
    const toSpin: number[] = []
    for (let i = 0; i < mode; i++) {
      if (locked[i] && final[i]) continue
      toSpin.push(i)
      final[i] = null
    }
    if (!toSpin.length) {
      setFlash('Everything is locked. Unlock something to spin.')
      return
    }
    for (const i of toSpin) {
      const taken = final.slice(0, mode).filter(Boolean) as Topic[]
      const names = new Set(taken.map((t) => t.name))
      const cats = new Set(taken.map((t) => t.category))
      let pick: Topic | null = null
      for (let tries = 0; tries < 40; tries++) {
        const c = rand(pool.length ? pool : TOPICS)
        if (names.has(c.name)) continue
        pick = c
        if (!cats.has(c.category) || tries > 25) break
      }
      final[i] = pick ?? rand(TOPICS)
    }
    setSlots(final)
    setPrompt('')
    setFlash('')
    setRolling((r) => r.map((v, i) => (toSpin.includes(i) ? true : v)))

    toSpin.forEach((slot, order) => {
      const stopAt = 650 + order * 420
      let elapsed = 0
      let delay = 40
      const tick = () => {
        elapsed += delay
        if (elapsed >= stopAt) {
          setDisplay((d) => d.map((v, i) => (i === slot ? final[slot]!.name : v)))
          setRolling((r) => r.map((v, i) => (i === slot ? false : v)))
          setLanded((l) => l.map((v, i) => (i === slot ? v + 1 : v)))
          if (order === toSpin.length - 1 && mode > 1) {
            setPrompt(pickPrompt(final.slice(0, mode).map((t) => t!.name)))
          }
          return
        }
        setDisplay((d) => d.map((v, i) => (i === slot ? rand(pool.length ? pool : TOPICS).name : v)))
        delay = Math.min(delay * 1.13, 160)
        timers.current.push(window.setTimeout(tick, delay))
      }
      timers.current.push(window.setTimeout(tick, delay))
    })
  }, [anyRolling, slots, mode, locked, pool])

  // Space bar spins when you're not typing.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const el = e.target as HTMLElement
      if (e.code !== 'Space' || ['INPUT', 'TEXTAREA', 'SELECT', 'BUTTON', 'A'].includes(el.tagName) || el.isContentEditable) return
      e.preventDefault()
      spin()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [spin])

  const pullTotd = () => {
    if (anyRolling) return
    setSlots((s) => s.map((v, i) => (i === 0 ? totd : v)))
    setDisplay((d) => d.map((v, i) => (i === 0 ? totd.name : v)))
    setLocked((l) => l.map((v, i) => (i === 0 ? true : v)))
    setLanded((l) => l.map((v, i) => (i === 0 ? v + 1 : v)))
    if (mode > 1) {
      const rest = slots.slice(1, mode)
      if (rest.every(Boolean)) setPrompt(pickPrompt([totd.name, ...rest.map((t) => t!.name)]))
    }
  }

  const saveEntry = async () => {
    if (!drawn) return
    const entry: LabEntryX = {
      createdAt: Date.now(),
      topics: drawn.map((t) => t.name),
      categories: drawn.map((t) => t.category),
      connection: connection.trim() || undefined,
      notes: notes.trim() || undefined,
      links: links
        .split(/\s+/)
        .map((s) => s.trim())
        .filter(Boolean),
      starred,
      prompt: mode > 1 ? prompt : undefined,
    }
    await db.lab.add(entry)
    setConnection('')
    setNotes('')
    setLinks('')
    setStarred(false)
    setFlash('Saved to the log ✦ the mind map just grew.')
  }

  return (
    <div className="stack">
      {/* Topic of the day */}
      <section className="panel lab-totd">
        <div className="lab-totd-orb" aria-hidden>
          {CATEGORY_GLYPHS[totd.category]}
        </div>
        <div className="lab-totd-body">
          <div className="panel-title lab-violet">Topic of the day</div>
          <h3 className="lab-totd-name">{totd.name}</h3>
          <p className="muted small">
            <span style={{ color: CATEGORY_COLORS[totd.category] }}>{totd.category}</span> · {totd.hook}
          </p>
          <div className="row" style={{ marginTop: 10 }}>
            <SearchLinks query={totd.name} compact />
            <button className="btn btn-sm lab-btn-violet" onClick={pullTotd}>
              Lock into slot 1
            </button>
          </div>
        </div>
      </section>

      {/* Controls */}
      <section className="panel stack">
        <div className="lab-modes" role="tablist" aria-label="Mode">
          {MODES.map((m) => (
            <button
              key={m.n}
              role="tab"
              aria-selected={mode === m.n}
              className={`lab-mode${mode === m.n ? ' active' : ''}`}
              onClick={() => setMode(m.n)}
            >
              <span className="lab-mode-dots">{'●'.repeat(m.n)}</span>
              <span className="lab-mode-label">{m.label}</span>
              <span className="lab-mode-sub">{m.sub}</span>
            </button>
          ))}
        </div>
        <div>
          <div className="row-between" style={{ marginBottom: 8 }}>
            <span className="label" style={{ margin: 0 }}>
              Draw from {filter.length ? `${filter.length} categor${filter.length === 1 ? 'y' : 'ies'} · ${pool.length} topics` : `everything · ${TOPICS.length} topics`}
            </span>
            {filter.length > 0 && (
              <button className="btn btn-ghost btn-sm" onClick={() => setFilter([])}>
                Clear
              </button>
            )}
          </div>
          <div className="lab-chips">
            {CATEGORIES.map((c) => (
              <button
                key={c}
                className={`chip lab-chip${filter.includes(c) ? ' active' : ''}`}
                style={{ ['--c' as string]: CATEGORY_COLORS[c] }}
                onClick={() => toggleCat(c)}
              >
                <span aria-hidden>{CATEGORY_GLYPHS[c]}</span> {c}
              </button>
            ))}
          </div>
        </div>
      </section>

      {/* Slots */}
      <section className={`lab-slots lab-slots-${mode}`}>
        {Array.from({ length: mode }, (_, i) => {
          const t = slots[i]
          const isRolling = rolling[i]
          const empty = !t && !isRolling
          const color = t && !isRolling ? CATEGORY_COLORS[t.category] : 'var(--violet)'
          const seen = t ? exploredCount.get(t.name) : 0
          return (
            <div key={i} className="lab-slot-wrap">
              {i > 0 && <div className="lab-collide" aria-hidden>×</div>}
              <article
                className={`lab-slot${isRolling ? ' rolling' : ''}${locked[i] ? ' locked' : ''}`}
                style={{ ['--c' as string]: color }}
              >
                <div className="row-between lab-slot-top">
                  <span className="lab-slot-cat mono">
                    {isRolling ? 'scrambling…' : t ? `${CATEGORY_GLYPHS[t.category]} ${t.category}` : `slot ${i + 1}`}
                  </span>
                  <button
                    className={`lab-lock${locked[i] ? ' on' : ''}`}
                    onClick={() => setLocked((l) => l.map((v, j) => (j === i ? !v : v)))}
                    disabled={!t || isRolling}
                    title={locked[i] ? 'Unlock' : 'Lock this topic and re-spin the others'}
                    aria-pressed={locked[i]}
                  >
                    {locked[i] ? '🔒' : '🔓'}
                  </button>
                </div>
                <div className="lab-reel">
                  {empty ? (
                    <span className="lab-slot-name lab-q">???</span>
                  ) : (
                    <span key={isRolling ? display[i] : `land-${landed[i]}`} className={`lab-slot-name${isRolling ? ' blur' : ' land'}`}>
                      {isRolling ? display[i] : t!.name}
                    </span>
                  )}
                </div>
                {t && !isRolling && (
                  <div className="lab-slot-detail" key={`d-${landed[i]}`}>
                    <p className="lab-hook">{t.hook}</p>
                    {!!seen && <span className="lab-seen mono">explored ×{seen}</span>}
                    <SearchLinks query={t.name} />
                  </div>
                )}
              </article>
            </div>
          )
        })}
      </section>

      <div className="lab-spin-row">
        <button className={`lab-spin${anyRolling ? ' spinning' : ''}`} onClick={spin} disabled={anyRolling}>
          <span className="lab-spin-glyph" aria-hidden>
            ✺
          </span>
          {anyRolling ? 'Spinning…' : drawn ? 'Spin again' : 'Spin'}
        </button>
        <span className="muted small lab-hint">press space · lock a topic to keep it</span>
      </div>

      {flash && <div className="lab-flash">{flash}</div>}

      {/* Collision prompt */}
      {mode > 1 && drawn && !anyRolling && prompt && (
        <section className="panel lab-prompt">
          <div className="row-between">
            <div className="panel-title lab-violet" style={{ margin: 0 }}>
              Collision prompt
            </div>
            <button className="btn btn-ghost btn-sm" onClick={() => setPrompt(pickPrompt(drawn.map((t) => t.name)))}>
              ↻ Another
            </button>
          </div>
          <p className="lab-prompt-text">{prompt}</p>
          <SearchLinks query={drawn.map((t) => t.name).join(' ')} compact />
        </section>
      )}

      {/* Save */}
      {drawn && !anyRolling && (
        <section className="panel stack lab-save">
          <div className="panel-title" style={{ margin: 0 }}>
            Log this {mode === 1 ? 'rabbit hole' : 'collision'}
          </div>
          {mode > 1 && (
            <div>
              <label className="label" htmlFor="lab-conn">
                The connection
              </label>
              <textarea
                id="lab-conn"
                className="textarea"
                placeholder={`How do ${drawn.map((t) => t.name).join(' and ')} connect?`}
                value={connection}
                onChange={(e) => setConnection(e.target.value)}
              />
            </div>
          )}
          <div>
            <label className="label" htmlFor="lab-notes">
              What I learned
            </label>
            <textarea
              id="lab-notes"
              className="textarea"
              placeholder="Facts, surprises, questions that opened up…"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
            />
          </div>
          <div>
            <label className="label" htmlFor="lab-links">
              Links (one per line)
            </label>
            <textarea
              id="lab-links"
              className="textarea lab-links-input"
              placeholder="https://…"
              value={links}
              onChange={(e) => setLinks(e.target.value)}
            />
          </div>
          <div className="row-between">
            <button className={`lab-star${starred ? ' on' : ''}`} onClick={() => setStarred((s) => !s)} aria-pressed={starred}>
              {starred ? '★' : '☆'} {starred ? 'Starred' : 'Star it'}
            </button>
            <button className="btn lab-btn-violet-solid" onClick={saveEntry}>
              Save to log
            </button>
          </div>
        </section>
      )}
    </div>
  )
}
