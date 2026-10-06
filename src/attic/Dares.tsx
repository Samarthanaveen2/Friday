import { useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useLiveQuery } from 'dexie-react-hooks'
import { db } from '../db/db'
import type { Dare } from '../db/types'
import { dayKey } from '../lib/date'
import { DARES, FACETS, FACET_INFO, isFacet, type Facet } from './facets'
import { POINTS } from './fuel'

interface Card {
  text: string
  facet: Facet
}

const ALL: Card[] = FACETS.flatMap((facet) => DARES[facet].map((text) => ({ text, facet })))

function hash(str: string): number {
  let h = 0x811c9dc5
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i)
    h = Math.imul(h, 0x01000193)
  }
  return h >>> 0
}

function FacetTag({ facet }: { facet: string }) {
  const info = isFacet(facet) ? FACET_INFO[facet] : null
  return (
    <span className="lab-pill" style={{ ['--c' as string]: info?.color ?? 'var(--purple)' }}>
      {info?.name ?? facet}
    </span>
  )
}

/** "I did it" with an optional reflection. */
function DoneForm({ onDone, onCancel }: { onDone: (reflection: string) => void; onCancel: () => void }) {
  const [text, setText] = useState('')
  return (
    <div className="stack-sm attic-done-form">
      <label className="label" htmlFor="dare-reflect">
        What did you notice? (optional)
      </label>
      <textarea
        id="dare-reflect"
        className="textarea"
        placeholder="What surprised you, what it felt like, what you’d do differently…"
        value={text}
        onChange={(e) => setText(e.target.value)}
        autoFocus
      />
      <div className="row" style={{ justifyContent: 'flex-end' }}>
        <button className="btn btn-ghost btn-sm" onClick={onCancel}>
          Cancel
        </button>
        <button className="btn btn-gold btn-sm" onClick={() => onDone(text.trim())}>
          Log it · +{POINTS.dare} fuel
        </button>
      </div>
    </div>
  )
}

export default function Dares() {
  const [params, setParams] = useSearchParams()
  const pf = params.get('facet')
  const facet: Facet | null = isFacet(pf) ? pf : null
  const dares = useLiveQuery(() => db.dares.orderBy('createdAt').reverse().toArray(), []) as Dare[] | undefined

  const today = dayKey()
  const daily = ALL[hash('dare:' + today) % ALL.length]
  const [drawn, setDrawn] = useState<Card | null>(null)
  const [finishing, setFinishing] = useState<string | number | null>(null) // 'drawn' | 'daily' | dare id
  const [flash, setFlash] = useState('')

  const pool = facet ? ALL.filter((c) => c.facet === facet) : ALL
  const todo = useMemo(() => (dares ?? []).filter((d) => d.status === 'todo'), [dares])
  const done = useMemo(
    () => (dares ?? []).filter((d) => d.status === 'done').sort((a, b) => (b.doneAt ?? 0) - (a.doneAt ?? 0)),
    [dares],
  )
  const doneTexts = useMemo(() => new Set(done.map((d) => d.text)), [done])
  const listed = useMemo(() => new Set(todo.map((d) => d.text)), [todo])

  const setFacet = (f: Facet | null) => {
    setParams(f ? { facet: f } : {}, { replace: true })
    setDrawn(null)
    setFinishing(null)
  }

  const draw = () => {
    // Prefer dares you haven't done or listed yet.
    const fresh = pool.filter((c) => !doneTexts.has(c.text) && !listed.has(c.text) && c.text !== drawn?.text)
    const from = fresh.length ? fresh : pool.filter((c) => c.text !== drawn?.text)
    setDrawn(from[Math.floor(Math.random() * from.length)] ?? pool[0])
    setFinishing(null)
    setFlash('')
  }

  const accept = async (c: Card) => {
    if (listed.has(c.text)) return setFlash('Already on your list.')
    await db.dares.add({ createdAt: Date.now(), text: c.text, facet: c.facet, status: 'todo' })
    setFlash('Added to your list. Do it before it goes stale.')
    if (drawn?.text === c.text) setDrawn(null)
  }

  const completeCard = async (c: Card, reflection: string) => {
    const now = Date.now()
    const existing = todo.find((d) => d.text === c.text)
    if (existing) await db.dares.update(existing.id!, { status: 'done', doneAt: now, reflection: reflection || undefined })
    else await db.dares.add({ createdAt: now, text: c.text, facet: c.facet, status: 'done', doneAt: now, reflection: reflection || undefined })
    setFinishing(null)
    if (drawn?.text === c.text) setDrawn(null)
    setFlash(`Done. +${POINTS.dare} ${FACET_INFO[c.facet].name.toLowerCase()} fuel.`)
  }

  const completeTodo = async (d: Dare, reflection: string) => {
    await db.dares.update(d.id!, { status: 'done', doneAt: Date.now(), reflection: reflection || undefined })
    setFinishing(null)
    setFlash(`Done. +${POINTS.dare} fuel.`)
  }

  // A render helper, not a component, so the reflection box keeps its text across re-renders.
  const cardActions = (c: Card, k: string) =>
    finishing === k ? (
      <DoneForm onDone={(r) => completeCard(c, r)} onCancel={() => setFinishing(null)} />
    ) : (
      <div className="row">
        <button className="btn btn-gold btn-sm" onClick={() => setFinishing(k)}>
          I did it
        </button>
        <button className="btn btn-sm lab-btn-tint" onClick={() => accept(c)} disabled={listed.has(c.text)}>
          {listed.has(c.text) ? 'On your list' : 'Save for later'}
        </button>
        {doneTexts.has(c.text) && <span className="small muted">You’ve done this one before</span>}
      </div>
    )

  return (
    <div className="stack">
      <section className="panel lab-totd">
        <div className="lab-totd-eyebrow">
          <span>Dare of the day</span>
          <span className="lab-totd-dot" aria-hidden>·</span>
          <span style={{ color: FACET_INFO[daily.facet].color }}>{FACET_INFO[daily.facet].name}</span>
        </div>
        <h2 className="lab-totd-name attic-dare-text">{daily.text}</h2>
        <div className="lab-totd-actions">
          {cardActions(daily, 'daily')}
        </div>
      </section>

      <section className="panel stack">
        <div className="row-between">
          <span className="lab-label">Draw a dare from</span>
          <span className="small muted">{pool.length} dares</span>
        </div>
        <div className="lab-chips" role="group" aria-label="Facet">
          <button className={`chip lab-chip${!facet ? ' active' : ''}`} style={{ ['--c' as string]: 'var(--accent)' }} onClick={() => setFacet(null)}>
            Any facet
          </button>
          {FACETS.map((f) => (
            <button
              key={f}
              className={`chip lab-chip${facet === f ? ' active' : ''}`}
              style={{ ['--c' as string]: FACET_INFO[f].color }}
              onClick={() => setFacet(f)}
              title={FACET_INFO[f].blurb}
            >
              <i className="lab-chip-dot" aria-hidden /> {FACET_INFO[f].name}
            </button>
          ))}
        </div>
        {facet && <p className="small muted">{FACET_INFO[facet].blurb}</p>}
        <div className="lab-spin-row">
          <button className="lab-spin" onClick={draw}>
            {drawn ? 'Another dare' : 'Draw a dare'}
          </button>
        </div>
        {drawn && (
          <div className="attic-drawn" key={drawn.text}>
            <FacetTag facet={drawn.facet} />
            <p className="lab-prompt-text">{drawn.text}</p>
            {cardActions(drawn, 'drawn')}
          </div>
        )}
      </section>

      {flash && <div className="lab-flash">{flash}</div>}

      <section>
        <h3 className="lab-group-title">On your list</h3>
        {todo.length === 0 ? (
          <div className="empty">Nothing waiting. Save a dare for later and it lands here.</div>
        ) : (
          <div className="lab-list">
            {todo.map((d) => (
              <article key={d.id} className="lab-entry">
                <div className="row-between">
                  <FacetTag facet={d.facet} />
                  <span className="lab-entry-date">Saved {new Date(d.createdAt).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}</span>
                </div>
                <p className="lab-entry-text attic-todo-text">{d.text}</p>
                {finishing === d.id ? (
                  <DoneForm onDone={(r) => completeTodo(d, r)} onCancel={() => setFinishing(null)} />
                ) : (
                  <div className="row">
                    <button className="btn btn-gold btn-sm" onClick={() => setFinishing(d.id!)}>
                      I did it
                    </button>
                    <button className="btn btn-ghost btn-sm lab-delete" onClick={() => db.dares.delete(d.id!)}>
                      Drop
                    </button>
                  </div>
                )}
              </article>
            ))}
          </div>
        )}
      </section>

      {done.length > 0 && (
        <section>
          <h3 className="lab-group-title">Done · {done.length}</h3>
          <div className="lab-list">
            {done.map((d) => (
              <article key={d.id} className="lab-entry">
                <div className="row-between">
                  <FacetTag facet={d.facet} />
                  <span className="lab-entry-date">
                    {new Date(d.doneAt ?? d.createdAt).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })}
                  </span>
                </div>
                <p className="lab-entry-text">{d.text}</p>
                {d.reflection && <p className="lab-entry-prompt attic-reflection">{d.reflection}</p>}
              </article>
            ))}
          </div>
        </section>
      )}
    </div>
  )
}
