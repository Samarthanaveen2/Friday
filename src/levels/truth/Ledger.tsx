import { useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { useLiveQuery } from 'dexie-react-hooks'
import { db } from '../../db/db'
import type { TruthKind, TruthStatus } from '../../db/types'
import { ADDRESSED_ACKS, DAY_MS, KIND_LABEL, STATUS_HINT, STATUS_LABEL, type TruthEntry, pick, timeAgo } from './content'

const KINDS: TruthKind[] = ['lie', 'avoided', 'self']
const STATUSES: TruthStatus[] = ['confessed', 'addressed', 'pattern']

export async function changeStatus(t: TruthEntry, status: TruthStatus) {
  if (t.id == null || t.status === status) return
  const now = Date.now()
  const patch: Partial<TruthEntry> = { status }
  if (status === 'addressed') patch.addressedAt = now
  else patch.addressedAt = undefined
  if (status === 'pattern') patch.patternAt = now
  await db.truths.update(t.id, patch)
}

export default function Ledger() {
  const all = useLiveQuery(() => db.truths.orderBy('createdAt').reverse().toArray() as Promise<TruthEntry[]>, [])
  const [params, setParams] = useSearchParams()
  const [q, setQ] = useState('')
  const [confirmId, setConfirmId] = useState<number | null>(null)
  const [toast, setToast] = useState<{ id: number; msg: string } | null>(null)

  const kind = (params.get('kind') as TruthKind | null) ?? null
  const status = (params.get('status') as TruthStatus | null) ?? null
  const who = params.get('who')
  const tag = params.get('tag')
  const topic = params.get('topic')
  const old = params.get('old') === '1'

  const setParam = (key: string, value: string | null) => {
    const next = new URLSearchParams(params)
    if (value == null || value === '') next.delete(key)
    else next.set(key, value)
    setParams(next, { replace: true })
  }

  const people = useMemo(() => {
    const m = new Map<string, string>()
    for (const t of all ?? []) if (t.who?.trim()) m.set(t.who.trim().toLowerCase(), t.who.trim())
    return [...m.values()].sort((a, b) => a.localeCompare(b))
  }, [all])

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase()
    const now = Date.now()
    return (all ?? []).filter((t) => {
      if (kind && t.kind !== kind) return false
      if (status && t.status !== status) return false
      if (who && (t.who ?? '').trim().toLowerCase() !== who.toLowerCase()) return false
      if (topic && (t.topic ?? '').trim().toLowerCase() !== topic.toLowerCase()) return false
      if (tag && !(t.tags ?? []).includes(tag)) return false
      if (old && (t.status === 'addressed' || now - t.createdAt < 7 * DAY_MS)) return false
      if (needle) {
        const hay = [t.text, t.who, t.topic, ...(t.tags ?? [])].join(' ').toLowerCase()
        if (!hay.includes(needle)) return false
      }
      return true
    })
  }, [all, q, kind, status, who, topic, tag, old])

  const anyFilter = !!(kind || status || who || tag || topic || old || q)

  const onStatus = async (t: TruthEntry, s: TruthStatus) => {
    await changeStatus(t, s)
    if (s === 'addressed' && t.id != null) {
      const id = t.id
      setToast({ id, msg: pick(ADDRESSED_ACKS) })
      setTimeout(() => setToast((cur) => (cur?.id === id ? null : cur)), 3200)
    }
  }

  const onDelete = async (id: number) => {
    await db.truths.delete(id)
    setConfirmId(null)
  }

  if (!all) return <div className="empty">Opening the ledger…</div>

  if (all.length === 0)
    return (
      <div className="empty truth-empty">
        <div className="truth-empty-glyph" aria-hidden>
          ◇
        </div>
        <p>The ledger is empty — and that’s fine.</p>
        <p className="small" style={{ marginTop: 4 }}>
          When something true needs a place to land, <Link to="/truth">write it here</Link>.
        </p>
      </div>
    )

  return (
    <div className="stack">
      <section className="panel truth-panel truth-filters">
        <input className="input" type="search" placeholder="Search the ledger…" value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search" />
        <div className="truth-filter-row">
          <span className="truth-filter-label">Kind</span>
          <div className="row truth-chips">
            {KINDS.map((k) => (
              <button key={k} type="button" className={`chip truth-chip-btn ${kind === k ? 'truth-chip-on' : ''}`} onClick={() => setParam('kind', kind === k ? null : k)}>
                {KIND_LABEL[k]}
              </button>
            ))}
          </div>
        </div>
        <div className="truth-filter-row">
          <span className="truth-filter-label">Status</span>
          <div className="row truth-chips">
            {STATUSES.map((s) => (
              <button
                key={s}
                type="button"
                className={`chip truth-chip-btn truth-status-${s} ${status === s ? 'truth-chip-on' : ''}`}
                onClick={() => setParam('status', status === s ? null : s)}
              >
                {STATUS_LABEL[s]}
              </button>
            ))}
          </div>
        </div>
        {people.length > 0 && (
          <div className="truth-filter-row">
            <span className="truth-filter-label">Who</span>
            <select className="select truth-who-select" value={who ?? ''} onChange={(e) => setParam('who', e.target.value || null)}>
              <option value="">Anyone</option>
              {people.map((p) => (
                <option key={p} value={p}>
                  {p}
                </option>
              ))}
            </select>
          </div>
        )}
        {(tag || topic || old) && (
          <div className="row truth-chips">
            {tag && (
              <button type="button" className="chip truth-chip-btn truth-chip-on" onClick={() => setParam('tag', null)}>
                #{tag} ✕
              </button>
            )}
            {topic && (
              <button type="button" className="chip truth-chip-btn truth-chip-on" onClick={() => setParam('topic', null)}>
                topic: {topic} ✕
              </button>
            )}
            {old && (
              <button type="button" className="chip truth-chip-btn truth-chip-on" onClick={() => setParam('old', null)}>
                waiting 7+ days ✕
              </button>
            )}
          </div>
        )}
        <div className="row-between small muted">
          <span>
            {filtered.length} of {all.length} {all.length === 1 ? 'truth' : 'truths'}
          </span>
          {anyFilter && (
            <button
              type="button"
              className="btn btn-ghost btn-sm"
              onClick={() => {
                setQ('')
                setParams(new URLSearchParams(), { replace: true })
              }}
            >
              Clear filters
            </button>
          )}
        </div>
      </section>

      {filtered.length === 0 ? (
        <div className="empty">Nothing matches those filters.</div>
      ) : (
        <ul className="truth-list">
          {filtered.map((t) => (
            <li key={t.id} className={`truth-entry truth-entry-${t.status}`}>
              <div className="truth-entry-head">
                <span className={`truth-kind truth-kind-${t.kind}`}>{KIND_LABEL[t.kind]}</span>
                {t.who && (
                  <button type="button" className="truth-link" onClick={() => setParam('who', t.who!.trim())}>
                    {t.who}
                  </button>
                )}
                {t.topic && (
                  <button type="button" className="truth-link truth-link-muted" onClick={() => setParam('topic', t.topic!.trim())}>
                    · {t.topic}
                  </button>
                )}
                <span className="spacer" />
                <time className="mono small muted" dateTime={new Date(t.createdAt).toISOString()} title={new Date(t.createdAt).toLocaleString()}>
                  {timeAgo(t.createdAt)}
                </time>
              </div>
              <p className="truth-entry-text">{t.text}</p>
              {t.tags?.length > 0 && (
                <div className="row truth-chips">
                  {t.tags.map((g) => (
                    <button key={g} type="button" className="chip truth-chip-btn" onClick={() => setParam('tag', g)}>
                      #{g}
                    </button>
                  ))}
                </div>
              )}
              {toast && toast.id === t.id && <div className="truth-inline-ack small">{toast.msg}</div>}
              <div className="truth-entry-foot">
                <div className="truth-status-seg" role="radiogroup" aria-label="Status">
                  {STATUSES.map((s) => (
                    <button
                      key={s}
                      type="button"
                      role="radio"
                      aria-checked={t.status === s}
                      title={STATUS_HINT[s]}
                      className={`truth-status-btn truth-status-${s} ${t.status === s ? 'active' : ''}`}
                      onClick={() => onStatus(t, s)}
                    >
                      {STATUS_LABEL[s]}
                    </button>
                  ))}
                </div>
                {t.status === 'addressed' && t.addressedAt && <span className="small muted">addressed {timeAgo(t.addressedAt)}</span>}
                <span className="spacer" />
                {confirmId === t.id ? (
                  <span className="row truth-confirm">
                    <span className="small muted">Delete for good?</span>
                    <button type="button" className="btn btn-danger btn-sm" onClick={() => onDelete(t.id!)}>
                      Delete
                    </button>
                    <button type="button" className="btn btn-ghost btn-sm" onClick={() => setConfirmId(null)}>
                      Keep
                    </button>
                  </span>
                ) : (
                  <button type="button" className="btn btn-ghost btn-sm" onClick={() => setConfirmId(t.id!)} aria-label="Delete entry">
                    Delete
                  </button>
                )}
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
