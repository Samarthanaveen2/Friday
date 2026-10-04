import { useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { useLiveQuery } from 'dexie-react-hooks'
import { db } from '../../db/db'
import type { TruthKind, TruthStatus } from '../../db/types'
import { CheckIcon } from './icons'
import { ADDRESSED_ACKS, DAY_MS, KIND_LABEL, STATUS_HINT, STATUS_LABEL, type TruthEntry, pick, timeAgo } from './content'

const KINDS: TruthKind[] = ['lie', 'avoided', 'self']
const STATUSES: TruthStatus[] = ['confessed', 'addressed', 'pattern']
const KIND_SHORT: Record<TruthKind, string> = { lie: 'Lies', avoided: 'Avoided', self: 'Self' }

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

  if (!all) return <div className="empty">Loading…</div>

  if (all.length === 0)
    return (
      <div className="empty truth-empty">
        <p className="truth-empty-title">Nothing here yet</p>
        <p className="small" style={{ marginTop: 4 }}>
          When something true needs a place to land, <Link to="/truth">write it down</Link>.
        </p>
      </div>
    )

  return (
    <div className="stack">
      <div className="truth-filters">
        <input className="input truth-search" type="search" placeholder="Search" value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search" />
        <div className="truth-filter-line">
          <div className="truth-seg truth-seg-sm truth-seg-kind" role="radiogroup" aria-label="Filter by kind">
            <button type="button" role="radio" aria-checked={!kind} className={`truth-seg-btn ${!kind ? 'active' : ''}`} onClick={() => setParam('kind', null)}>
              All
            </button>
            {KINDS.map((k) => (
              <button key={k} type="button" role="radio" aria-checked={kind === k} className={`truth-seg-btn ${kind === k ? 'active' : ''}`} onClick={() => setParam('kind', k)}>
                {KIND_SHORT[k]}
              </button>
            ))}
          </div>
          <div className="truth-seg truth-seg-sm truth-seg-status" role="radiogroup" aria-label="Filter by status">
            <button type="button" role="radio" aria-checked={!status} className={`truth-seg-btn ${!status ? 'active' : ''}`} onClick={() => setParam('status', null)}>
              Any status
            </button>
            {STATUSES.map((st) => (
              <button key={st} type="button" role="radio" aria-checked={status === st} className={`truth-seg-btn ${status === st ? 'active' : ''}`} onClick={() => setParam('status', st)}>
                {STATUS_LABEL[st]}
              </button>
            ))}
          </div>
          {people.length > 0 && (
            <select className="select truth-who-select" value={who ?? ''} onChange={(e) => setParam('who', e.target.value || null)} aria-label="Filter by person">
              <option value="">Anyone</option>
              {people.map((p) => (
                <option key={p} value={p}>
                  {p}
                </option>
              ))}
            </select>
          )}
        </div>
        {(tag || topic || old) && (
          <div className="row truth-chips">
            {tag && (
              <button type="button" className="chip truth-chip-btn active" onClick={() => setParam('tag', null)}>
                #{tag} ✕
              </button>
            )}
            {topic && (
              <button type="button" className="chip truth-chip-btn active" onClick={() => setParam('topic', null)}>
                Topic: {topic} ✕
              </button>
            )}
            {old && (
              <button type="button" className="chip truth-chip-btn active" onClick={() => setParam('old', null)}>
                Waiting 7+ days ✕
              </button>
            )}
          </div>
        )}
      </div>

      <div>
        <div className="truth-section-title truth-list-head">
          <span>
            {filtered.length} of {all.length} {all.length === 1 ? 'entry' : 'entries'}
          </span>
          {anyFilter && (
            <button
              type="button"
              className="truth-text-btn"
              onClick={() => {
                setQ('')
                setParams(new URLSearchParams(), { replace: true })
              }}
            >
              Clear filters
            </button>
          )}
        </div>

        {filtered.length === 0 ? (
          <div className="empty">Nothing matches those filters.</div>
        ) : (
          <ul className="truth-group truth-list">
            {filtered.map((t) => (
              <li key={t.id} className="truth-entry">
                <div className="truth-entry-head">
                  <span className={`truth-kind truth-kind-${t.kind}`}>{KIND_LABEL[t.kind]}</span>
                  {t.who && (
                    <button type="button" className="truth-link" onClick={() => setParam('who', t.who!.trim())}>
                      {t.who}
                    </button>
                  )}
                  {t.topic && (
                    <button type="button" className="truth-link truth-link-muted" onClick={() => setParam('topic', t.topic!.trim())}>
                      {t.topic}
                    </button>
                  )}
                  <span className="spacer" />
                  <time className="truth-time" dateTime={new Date(t.createdAt).toISOString()} title={new Date(t.createdAt).toLocaleString()}>
                    {timeAgo(t.createdAt)}
                  </time>
                </div>
                <p className="truth-entry-text">{t.text}</p>
                {t.tags?.length > 0 && (
                  <div className="truth-tags">
                    {t.tags.map((g) => (
                      <button key={g} type="button" className="truth-tag" onClick={() => setParam('tag', g)}>
                        #{g}
                      </button>
                    ))}
                  </div>
                )}
                {toast && toast.id === t.id && (
                  <div className="truth-inline-ack">
                    <CheckIcon size={14} /> {toast.msg}
                  </div>
                )}
                <div className="truth-entry-foot">
                  <label className={`truth-pill truth-pill-${t.status}`} title={STATUS_HINT[t.status]}>
                    <span className="truth-visually-hidden">Status</span>
                    <select value={t.status} onChange={(e) => onStatus(t, e.target.value as TruthStatus)}>
                      {STATUSES.map((st) => (
                        <option key={st} value={st}>
                          {STATUS_LABEL[st]}
                        </option>
                      ))}
                    </select>
                    <svg width="8" height="8" viewBox="0 0 10 10" aria-hidden>
                      <path d="M2 3.5l3 3 3-3" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
                    </svg>
                  </label>
                  {t.status === 'addressed' && t.addressedAt && <span className="truth-time">Addressed {timeAgo(t.addressedAt)}</span>}
                  <span className="spacer" />
                  {confirmId === t.id ? (
                    <span className="row truth-confirm">
                      <span className="truth-time">Delete for good?</span>
                      <button type="button" className="truth-text-btn truth-text-danger" onClick={() => onDelete(t.id!)}>
                        Delete
                      </button>
                      <button type="button" className="truth-text-btn" onClick={() => setConfirmId(null)}>
                        Keep
                      </button>
                    </span>
                  ) : (
                    <button type="button" className="truth-text-btn truth-text-quiet" onClick={() => setConfirmId(t.id!)} aria-label="Delete entry">
                      Delete
                    </button>
                  )}
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  )
}
