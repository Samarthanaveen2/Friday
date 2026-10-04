import { useState } from 'react'
import type { DealItem, DealStatus, IfThenRule } from '../../db/types'
import { db } from '../../db/db'
import { uid } from '../../lib/date'
import {
  type Balance,
  type NegDeal,
  completionPct,
  computeOwedOut,
  fmtMin,
  projectNeeds,
  projectionSentence,
  sumMinutes,
  suggestStatus,
} from './logic'

/* ---------------- Item column (one side of the table) ---------------- */

export function ItemColumn({
  side,
  title,
  subtitle,
  items,
  onChange,
  placeholder,
}: {
  side: 'present' | 'future'
  title: string
  subtitle: string
  items: DealItem[]
  onChange: (items: DealItem[]) => void
  placeholder: string
}) {
  const [text, setText] = useState('')
  const [minutes, setMinutes] = useState('')

  const add = (t: string, m?: number) => {
    const clean = t.trim()
    if (!clean) return
    onChange([...items, { id: uid(), text: clean, minutes: m && m > 0 ? Math.round(m) : undefined }])
  }

  const submit = () => {
    add(text, Number(minutes) || undefined)
    setText('')
    setMinutes('')
  }

  const update = (id: string, patch: Partial<DealItem>) => onChange(items.map((i) => (i.id === id ? { ...i, ...patch } : i)))
  const remove = (id: string) => onChange(items.filter((i) => i.id !== id))
  const total = sumMinutes(items)

  return (
    <section className={`panel neg-card neg-card-${side}`}>
      <header className="neg-card-head">
        <div>
          <div className="neg-card-title">
            <span className="neg-label-dot" aria-hidden />
            {title}
          </div>
          <div className="muted small">{subtitle}</div>
        </div>
        <div className="neg-card-total">{fmtMin(total)}</div>
      </header>

      <div className="neg-card-body">
        <ul className="neg-list">
          {items.map((i) => (
            <li key={i.id} className="neg-row">
              <input
                className="neg-row-text"
                value={i.text}
                aria-label="Item"
                onChange={(e) => update(i.id, { text: e.target.value })}
              />
              <label className="neg-row-min">
                <input
                  type="number"
                  min={0}
                  inputMode="numeric"
                  placeholder="0"
                  aria-label="Minutes"
                  value={i.minutes ?? ''}
                  onChange={(e) => update(i.id, { minutes: Number(e.target.value) > 0 ? Number(e.target.value) : undefined })}
                />
                <span>min</span>
              </label>
              <button className="neg-x" type="button" aria-label={`Remove ${i.text}`} onClick={() => remove(i.id)}>
                <svg viewBox="0 0 20 20" width="20" height="20" aria-hidden>
                  <circle cx="10" cy="10" r="9" fill="currentColor" />
                  <path d="M6 10h8" stroke="#fff" strokeWidth="2" strokeLinecap="round" />
                </svg>
              </button>
            </li>
          ))}
          <li className="neg-row neg-row-add">
            <form
              onSubmit={(e) => {
                e.preventDefault()
                submit()
              }}
            >
              <input className="neg-row-text" placeholder={placeholder} aria-label="New item" value={text} onChange={(e) => setText(e.target.value)} />
              <label className="neg-row-min">
                <input
                  type="number"
                  min={0}
                  inputMode="numeric"
                  placeholder="0"
                  aria-label="Minutes for new item"
                  value={minutes}
                  onChange={(e) => setMinutes(e.target.value)}
                />
                <span>min</span>
              </label>
              <button className="btn btn-sm neg-add-btn" type="submit" disabled={!text.trim()}>
                Add
              </button>
            </form>
          </li>
        </ul>
        {items.length === 0 && <div className="neg-hint small">Nothing here yet. Type above to add one.</div>}

      </div>
    </section>
  )
}

/* ---------------- Balance meter ---------------- */

export function BalanceMeter({
  balance,
  rate,
  rates,
  onRate,
}: {
  balance: Balance
  rate: number
  rates: number[]
  onRate: (r: number) => void
}) {
  const { wantMin, earned, surplus, debt, owedIn, needMin } = balance
  const empty = needMin === 0 && wantMin === 0 && owedIn === 0
  const covered = wantMin === 0 ? (earned > 0 ? 1 : 0) : Math.min(1, earned / wantMin)

  let headline: string
  let verdict: string
  let tone: 'ok' | 'warn' | 'bad'
  if (empty) {
    headline = 'Nothing yet'
    verdict = 'Add what you want on one side and what you need to do on the other.'
    tone = 'warn'
  } else if (debt === 0 && surplus === 0) {
    headline = 'Balanced'
    verdict = 'Every minute of fun is paid for.'
    tone = 'ok'
  } else if (debt === 0) {
    headline = 'Balanced'
    verdict = `You have ${fmtMin(surplus)} of free time still to spend.`
    tone = 'ok'
  } else {
    headline = `${fmtMin(debt)} short`
    verdict = 'Add a need, trim a want, or borrow the time from tomorrow.'
    tone = debt > 60 ? 'bad' : 'warn'
  }

  return (
    <section className={`panel neg-balance neg-balance-${tone}`}>
      <div className="neg-balance-top">
        <div>
          <div className="panel-title neg-balance-label">Balance</div>
          <div className="neg-balance-headline">{headline}</div>
          <div className="small muted">{verdict}</div>
        </div>
        <div className="neg-rate">
          <span className="muted small">1 min of need earns</span>
          <div className="neg-seg neg-seg-sm" role="radiogroup" aria-label="Exchange rate">
            {rates.map((r) => (
              <button
                key={r}
                type="button"
                role="radio"
                aria-checked={r === rate}
                className={`neg-seg-opt ${r === rate ? 'active' : ''}`}
                onClick={() => onRate(r)}
              >
                {r}m
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="neg-bar" role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(covered * 100)} aria-label="Wants paid for">
        <div className="neg-bar-fill" style={{ width: `${covered * 100}%` }} />
      </div>

      <div className="neg-balance-nums">
        <div>
          <div className="small muted">Wants</div>
          <div className="neg-num">{fmtMin(wantMin)}</div>
        </div>
        <div>
          <div className="small muted">Earned</div>
          <div className="neg-num">{fmtMin(earned)}</div>
        </div>
        <div>
          <div className="small muted">{debt > 0 ? 'Short' : 'To spare'}</div>
          <div className={`neg-num ${debt > 0 ? 'neg-red' : ''}`}>{debt > 0 ? `−${fmtMin(debt)}` : `+${fmtMin(surplus)}`}</div>
        </div>
      </div>
      {owedIn > 0 && (
        <div className="small muted">
          The first {fmtMin(owedIn)} of today's needs pays back time borrowed earlier, so it doesn't earn anything new.
        </div>
      )}
    </section>
  )
}

/* ---------------- If-then rules ---------------- */

export function RulesEditor({ rules, onChange }: { rules: IfThenRule[]; onChange: (r: IfThenRule[]) => void }) {
  const [when, setWhen] = useState('')
  const [then, setThen] = useState('')
  const add = (w: string, t: string) => {
    if (!w.trim() || !t.trim()) return
    onChange([...rules, { id: uid(), when: w.trim(), then: t.trim() }])
  }

  return (
    <div className="stack-sm">
      {rules.length === 0 ? (
        <div className="neg-hint small">
          No rules yet. An if-then plan decides in advance, so in the moment you don't have to.
        </div>
      ) : (
        <ul className="neg-list">
          {rules.map((r) => (
            <li key={r.id} className="neg-row">
              <div className="neg-rule-text">
                <span className="neg-kw">If</span> {r.when}, <span className="neg-kw">then I will</span> {r.then}
              </div>
              <button className="neg-x" type="button" aria-label="Remove rule" onClick={() => onChange(rules.filter((x) => x.id !== r.id))}>
                <svg viewBox="0 0 20 20" width="20" height="20" aria-hidden>
                  <circle cx="10" cy="10" r="9" fill="currentColor" />
                  <path d="M6 10h8" stroke="#fff" strokeWidth="2" strokeLinecap="round" />
                </svg>
              </button>
            </li>
          ))}
        </ul>
      )}
      <form
        className="neg-rule-form"
        onSubmit={(e) => {
          e.preventDefault()
          add(when, then)
          setWhen('')
          setThen('')
        }}
      >
        <label className="neg-rule-field">
          <span className="neg-kw">If</span>
          <input className="input" placeholder="it's 9pm…" value={when} onChange={(e) => setWhen(e.target.value)} />
        </label>
        <label className="neg-rule-field">
          <span className="neg-kw">Then I will</span>
          <input className="input" placeholder="put the phone in the other room" value={then} onChange={(e) => setThen(e.target.value)} />
        </label>
        <button className="btn btn-sm" type="submit" disabled={!when.trim() || !then.trim()}>
          Add rule
        </button>
      </form>
    </div>
  )
}

/* ---------------- Future projection ---------------- */

export function Projection({ needs, wants, keepRate }: { needs: DealItem[]; wants: DealItem[]; keepRate: number | null }) {
  const lines = projectNeeds(needs)
  const wantMin = sumMinutes(wants)
  if (lines.length === 0 && wantMin === 0) {
    return <div className="neg-hint small">Add needs to see what this deal builds if you keep making it.</div>
  }
  const month = projectionSentence(lines, 30)
  const year = projectionSentence(lines, 365)
  const realistic = keepRate !== null && keepRate < 1 ? projectionSentence(lines, 30, keepRate) : null

  return (
    <div className="stack-sm neg-projection">
      {month && (
        <p>
          <span className="neg-proj-label">30 days</span>
          Repeat this deal and you'll have <strong>{month}</strong>.
        </p>
      )}
      {year && (
        <p>
          <span className="neg-proj-label">1 year</span>
          <strong>{year}</strong>. That adds up to a different person.
        </p>
      )}
      {realistic && (
        <p className="muted small">
          To be honest, you've kept {Math.round(keepRate! * 100)}% of recent deals, so a realistic month is closer to {realistic}.
        </p>
      )}
      {wantMin > 0 && (
        <p className="muted small">
          The price: 30 days of these wants is {Math.round((wantMin * 30) / 60)} hours. Make sure they're worth it, then enjoy them without guilt.
        </p>
      )}
    </div>
  )
}

/* ---------------- Status helpers ---------------- */

export const STATUS_LABEL: Record<DealStatus, string> = {
  open: 'Open',
  kept: 'Kept',
  partial: 'Partial',
  broken: 'Broken',
}

export function StatusChip({ status }: { status: DealStatus }) {
  return (
    <span className={`neg-status neg-status-${status}`}>
      <i className="neg-sdot" aria-hidden />
      {STATUS_LABEL[status]}
    </span>
  )
}

/* ---------------- Evening review ---------------- */

export function ReviewPanel({ deal, compact }: { deal: NegDeal; compact?: boolean }) {
  const pct = completionPct(deal.needs)
  const suggested = suggestStatus(pct)
  const [status, setStatus] = useState<Exclude<DealStatus, 'open'>>(deal.status !== 'open' ? deal.status : suggested)
  const [review, setReview] = useState(deal.review ?? '')
  const owed = computeOwedOut(deal, status)

  const save = async () => {
    if (deal.id == null) return
    await db.deals.update(deal.id, {
      status,
      review: review.trim() || undefined,
      reviewedAt: Date.now(),
      completion: pct,
      owedOut: owed,
    } as Partial<NegDeal>)
  }

  return (
    <div className="stack-sm neg-review">
      <div className="row-between">
        <div className="small">
          Needs done: <span className="neg-num-inline">{pct}%</span>
        </div>
        <div className="small muted">
          Suggested: <StatusChip status={suggested} />
        </div>
      </div>
      <div className="neg-seg neg-status-pick" role="radiogroup" aria-label="Deal status">
        {(['kept', 'partial', 'broken'] as const).map((s) => (
          <button
            key={s}
            type="button"
            role="radio"
            aria-checked={status === s}
            className={`neg-seg-opt neg-pick neg-status-${s} ${status === s ? 'active' : ''}`}
            onClick={() => setStatus(s)}
          >
            <i className="neg-sdot" aria-hidden />
            {STATUS_LABEL[s]}
          </button>
        ))}
      </div>
      {!compact && (
        <textarea
          className="textarea"
          placeholder="What happened? What would make tomorrow's deal easier to keep?"
          value={review}
          onChange={(e) => setReview(e.target.value)}
        />
      )}
      <div className="small muted">
        {owed > 0
          ? `${fmtMin(owed)} of need-work will carry forward. It comes first in tomorrow's deal.`
          : 'Nothing carries over. Tomorrow starts fresh.'}
      </div>
      <div className="row">
        <button className="btn btn-gold" onClick={save}>
          {deal.status === 'open' ? 'Close the deal' : 'Update review'}
        </button>
      </div>
    </div>
  )
}
