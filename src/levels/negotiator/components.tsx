import { useState } from 'react'
import type { DealItem, DealStatus, IfThenRule } from '../../db/types'
import { db } from '../../db/db'
import { uid } from '../../lib/date'
import type { Preset } from './presets'
import { RULE_PRESETS } from './presets'
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
  presets,
  placeholder,
}: {
  side: 'present' | 'future'
  title: string
  subtitle: string
  items: DealItem[]
  onChange: (items: DealItem[]) => void
  presets: Preset[]
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
  const unused = presets.filter((p) => !items.some((i) => i.text.toLowerCase() === p.text.toLowerCase()))
  const total = sumMinutes(items)

  return (
    <section className={`neg-side neg-side-${side}`}>
      <div className="neg-side-head">
        <div>
          <div className="neg-side-title">{title}</div>
          <div className="muted small">{subtitle}</div>
        </div>
        <div className="neg-side-total mono">{fmtMin(total)}</div>
      </div>

      {items.length === 0 ? (
        <div className="neg-side-empty small">Nothing on the table yet.</div>
      ) : (
        <ul className="neg-items">
          {items.map((i) => (
            <li key={i.id} className="neg-item">
              <input
                className="input neg-item-text"
                value={i.text}
                aria-label="Item"
                onChange={(e) => update(i.id, { text: e.target.value })}
              />
              <input
                className="input neg-item-min mono"
                type="number"
                min={0}
                inputMode="numeric"
                placeholder="min"
                aria-label="Minutes"
                value={i.minutes ?? ''}
                onChange={(e) => update(i.id, { minutes: Number(e.target.value) > 0 ? Number(e.target.value) : undefined })}
              />
              <button className="btn btn-ghost btn-sm neg-x" aria-label={`Remove ${i.text}`} onClick={() => remove(i.id)}>
                ×
              </button>
            </li>
          ))}
        </ul>
      )}

      <form
        className="neg-add"
        onSubmit={(e) => {
          e.preventDefault()
          submit()
        }}
      >
        <input className="input neg-item-text" placeholder={placeholder} value={text} onChange={(e) => setText(e.target.value)} />
        <input
          className="input neg-item-min mono"
          type="number"
          min={0}
          inputMode="numeric"
          placeholder="min"
          value={minutes}
          onChange={(e) => setMinutes(e.target.value)}
        />
        <button className="btn btn-sm neg-add-btn" type="submit" disabled={!text.trim()}>
          Add
        </button>
      </form>

      {unused.length > 0 && (
        <div className="neg-chips">
          {unused.map((p) => (
            <button key={p.text} className="chip neg-chip" type="button" onClick={() => add(p.text, p.minutes)}>
              + {p.text}
              {p.minutes ? <span className="mono neg-chip-min">{p.minutes}m</span> : null}
            </button>
          ))}
        </div>
      )}
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
  const scale = Math.max(wantMin, earned, 1)
  const wantPct = (wantMin / scale) * 50
  const earnPct = (earned / scale) * 50
  const tilt = Math.max(-1, Math.min(1, (earned - wantMin) / scale))

  let verdict: string
  let tone: 'ok' | 'warn' | 'bad'
  if (needMin === 0 && wantMin === 0 && owedIn === 0) {
    verdict = 'Put something on the table. Wants on the left, needs on the right.'
    tone = 'warn'
  } else if (debt === 0 && surplus === 0) {
    verdict = 'Perfectly balanced. Every minute of fun is paid for.'
    tone = 'ok'
  } else if (debt === 0) {
    verdict = `Balanced, with ${fmtMin(surplus)} of want-time still unspent. Future You is ahead.`
    tone = 'ok'
  } else {
    verdict = `Present You is short by ${fmtMin(debt)} of need-work. Add needs, trim wants, or take on debt.`
    tone = debt > 60 ? 'bad' : 'warn'
  }

  return (
    <div className={`neg-meter neg-meter-${tone}`}>
      <div className="row-between">
        <div className="panel-title neg-meter-title">The Balance</div>
        <div className="neg-rate">
          <span className="muted small">1 min of need earns</span>
          <div className="neg-rate-opts">
            {rates.map((r) => (
              <button key={r} className={`chip neg-rate-chip ${r === rate ? 'active' : ''}`} onClick={() => onRate(r)}>
                {r}m
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="neg-scale" aria-hidden>
        <div className="neg-scale-beam" style={{ transform: `rotate(${(-tilt * 6).toFixed(2)}deg)` }}>
          <div className="neg-scale-half neg-scale-left">
            <div className="neg-scale-fill neg-fill-want" style={{ width: `${wantPct * 2}%` }} />
          </div>
          <div className="neg-scale-pivot" />
          <div className="neg-scale-half neg-scale-right">
            <div className="neg-scale-fill neg-fill-earn" style={{ width: `${earnPct * 2}%` }} />
          </div>
        </div>
      </div>

      <div className="neg-meter-nums">
        <div>
          <div className="muted small">Wants spent</div>
          <div className="mono neg-num-present">{fmtMin(wantMin)}</div>
        </div>
        <div className="neg-meter-mid">
          <div className="muted small">{debt > 0 ? 'Debt' : 'Surplus'}</div>
          <div className={`mono ${debt > 0 ? 'neg-num-debt' : 'neg-num-ok'}`}>{debt > 0 ? `−${fmtMin(debt)}` : `+${fmtMin(surplus)}`}</div>
        </div>
        <div className="neg-meter-right">
          <div className="muted small">Wants earned</div>
          <div className="mono neg-num-future">{fmtMin(earned)}</div>
        </div>
      </div>
      {owedIn > 0 && (
        <div className="small muted">
          {fmtMin(owedIn)} of today's need-work goes to paying back what Future You is already owed before it earns anything.
        </div>
      )}
      <div className={`neg-verdict small neg-verdict-${tone}`}>{verdict}</div>
    </div>
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
  const unused = RULE_PRESETS.filter((p) => !rules.some((r) => r.when === p.when))

  return (
    <div className="stack-sm">
      {rules.length === 0 ? (
        <div className="neg-side-empty small">
          No rules yet. An if-then plan decides in advance, so in the moment you don't have to.
        </div>
      ) : (
        <ul className="neg-rules">
          {rules.map((r) => (
            <li key={r.id} className="neg-rule">
              <div className="neg-rule-text">
                <span className="neg-kw">If</span> {r.when} <span className="neg-kw">then I will</span> {r.then}
              </div>
              <button className="btn btn-ghost btn-sm neg-x" aria-label="Remove rule" onClick={() => onChange(rules.filter((x) => x.id !== r.id))}>
                ×
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
          <span className="neg-kw">then I will</span>
          <input className="input" placeholder="put the phone in the other room" value={then} onChange={(e) => setThen(e.target.value)} />
        </label>
        <button className="btn btn-sm" type="submit" disabled={!when.trim() || !then.trim()}>
          Add rule
        </button>
      </form>
      {unused.length > 0 && (
        <div className="neg-chips">
          {unused.slice(0, 5).map((p) => (
            <button key={p.when} type="button" className="chip neg-chip" onClick={() => add(p.when, p.then)}>
              + If {p.when}…
            </button>
          ))}
        </div>
      )}
    </div>
  )
}

/* ---------------- Future projection ---------------- */

export function Projection({ needs, wants, keepRate }: { needs: DealItem[]; wants: DealItem[]; keepRate: number | null }) {
  const lines = projectNeeds(needs)
  const wantMin = sumMinutes(wants)
  if (lines.length === 0 && wantMin === 0) {
    return <div className="neg-side-empty small">Add needs to see what this deal builds if you keep making it.</div>
  }
  const month = projectionSentence(lines, 30)
  const year = projectionSentence(lines, 365)
  const realistic = keepRate !== null && keepRate < 1 ? projectionSentence(lines, 30, keepRate) : null

  return (
    <div className="stack-sm neg-projection">
      {month && (
        <p>
          <span className="neg-proj-label mono">30 days</span> This deal, repeated, = <strong className="neg-gold">{month}</strong>.
        </p>
      )}
      {year && (
        <p>
          <span className="neg-proj-label mono">1 year</span> = <strong className="neg-gold">{year}</strong>. That is a different person.
        </p>
      )}
      {realistic && (
        <p className="muted small">
          Honestly: you've kept {Math.round(keepRate! * 100)}% of recent deals, so a realistic month is closer to {realistic}.
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
  return <span className={`chip neg-status neg-status-${status}`}>{STATUS_LABEL[status]}</span>
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
          Needs completed: <span className="mono neg-gold">{pct}%</span>
        </div>
        <div className="small muted">
          Suggested: <StatusChip status={suggested} />
        </div>
      </div>
      <div className="neg-status-pick" role="radiogroup" aria-label="Deal status">
        {(['kept', 'partial', 'broken'] as const).map((s) => (
          <button
            key={s}
            role="radio"
            aria-checked={status === s}
            className={`btn btn-sm neg-pick neg-pick-${s} ${status === s ? 'on' : ''}`}
            onClick={() => setStatus(s)}
          >
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
          ? `${fmtMin(owed)} of need-work will carry forward. Tomorrow, Future You collects it first.`
          : 'Nothing carries forward. Clean slate tomorrow.'}
      </div>
      <div className="row">
        <button className="btn btn-gold" onClick={save}>
          {deal.status === 'open' ? 'Close the deal' : 'Update review'}
        </button>
      </div>
    </div>
  )
}
