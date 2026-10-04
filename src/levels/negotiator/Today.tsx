import { useEffect, useMemo, useState } from 'react'
import type { DealItem, IfThenRule } from '../../db/types'
import { db, setSetting } from '../../db/db'
import { prettyDay } from '../../lib/date'
import { BalanceMeter, ItemColumn, Projection, ReviewPanel, RulesEditor, StatusChip } from './components'
import {
  type NegDeal,
  RATE_KEY,
  RATE_OPTIONS,
  completionPct,
  computeBalance,
  doneMinutes,
  fmtMin,
  sumMinutes,
} from './logic'
import { NEGOTIATION_LINES } from './presets'

interface Draft {
  date: string
  wants: DealItem[]
  needs: DealItem[]
  rules: IfThenRule[]
}

const DRAFT_KEY = 'neg-draft'

function loadDraft(today: string): Draft {
  try {
    const raw = localStorage.getItem(DRAFT_KEY)
    if (raw) {
      const d = JSON.parse(raw) as Draft
      if (d.date === today) return d
    }
  } catch {
    /* storage unavailable */
  }
  return { date: today, wants: [], needs: [], rules: [] }
}

function saveDraft(d: Draft | null) {
  try {
    if (d) localStorage.setItem(DRAFT_KEY, JSON.stringify(d))
    else localStorage.removeItem(DRAFT_KEY)
  } catch {
    /* storage unavailable */
  }
}

/* ======================= Negotiation (no deal yet) ======================= */

export function Negotiation({
  today,
  rate,
  owedIn,
  owedFrom,
  unreviewed,
  keepRate,
}: {
  today: string
  rate: number
  owedIn: number
  owedFrom?: NegDeal
  unreviewed?: NegDeal
  keepRate: number | null
}) {
  const [draft, setDraft] = useState<Draft>(() => loadDraft(today))
  const [acceptDebt, setAcceptDebt] = useState(false)
  const [sealing, setSealing] = useState(false)
  const line = useMemo(() => NEGOTIATION_LINES[new Date().getDate() % NEGOTIATION_LINES.length], [])

  useEffect(() => saveDraft(draft), [draft])

  const balance = computeBalance(draft.wants, draft.needs, rate, owedIn)
  const hasAnything = draft.wants.length + draft.needs.length > 0
  const canSeal = hasAnything && (balance.balanced || acceptDebt) && !sealing

  useEffect(() => {
    if (balance.balanced) setAcceptDebt(false)
  }, [balance.balanced])

  const seal = async () => {
    if (!canSeal) return
    setSealing(true)
    const clean = (items: DealItem[]) => items.filter((i) => i.text.trim()).map((i) => ({ ...i, text: i.text.trim(), done: false }))
    const deal: NegDeal = {
      date: today,
      wants: clean(draft.wants),
      needs: clean(draft.needs),
      rules: draft.rules,
      status: 'open',
      createdAt: Date.now(),
      rate,
      owedIn,
      debtTaken: balance.debt,
    }
    try {
      const existing = await db.deals.where('date').equals(today).first()
      if (existing) await db.deals.put({ ...deal, id: existing.id })
      else await db.deals.add(deal)
      saveDraft(null)
    } finally {
      setSealing(false)
    }
  }

  return (
    <div className="stack">
      {unreviewed && (
        <div className="panel neg-alert">
          <div className="panel-title">Still open from {prettyDay(unreviewed.date)}</div>
          <p className="small" style={{ marginBottom: 12 }}>
            That deal was never closed. Take a moment to say how it went before making a new one.
          </p>
          <ReviewPanel deal={unreviewed} compact />
        </div>
      )}

      <div className="neg-intro">
        <div className="neg-intro-date">{prettyDay(today)}</div>
        <p className="muted">{line}</p>
      </div>

      {owedIn > 0 && !unreviewed && (
        <div className="neg-owed">
          <div className="neg-owed-num">{fmtMin(owedIn)}</div>
          <div>
            <div className="neg-owed-title">Carried over to today</div>
            <div className="small muted">
              Carried from {owedFrom ? prettyDay(owedFrom.date) : 'your last deal'}
              {owedFrom?.status && owedFrom.status !== 'open' ? ` (${owedFrom.status})` : ''}. It's paid back first, out of today's needs.
            </div>
          </div>
        </div>
      )}

      <div className="neg-table">
          <ItemColumn
            side="present"
            title="Present You wants"
            subtitle="Time for fun, or a choice that tempts you"
            items={draft.wants}
            onChange={(wants) => setDraft((d) => ({ ...d, wants }))}
            placeholder="I want…"
          />
          <ItemColumn
            side="future"
            title="Future You needs"
            subtitle="Time for what matters, or the better choice"
            items={draft.needs}
            onChange={(needs) => setDraft((d) => ({ ...d, needs }))}
            placeholder="I need…"
          />
      </div>

      <BalanceMeter balance={balance} decisions={[...draft.wants, ...draft.needs].filter((i) => !(i.minutes && i.minutes > 0)).length} rate={rate} rates={RATE_OPTIONS} onRate={(r) => setSetting(RATE_KEY, r)} />

      <div className="grid-2">
        <div className="panel">
          <div className="panel-title">If-then rules</div>
          <RulesEditor rules={draft.rules} onChange={(rules) => setDraft((d) => ({ ...d, rules }))} />
        </div>
        <div className="panel">
          <div className="panel-title">Future projection</div>
          <Projection needs={draft.needs} wants={draft.wants} keepRate={keepRate} />
        </div>
      </div>

      <div className="panel neg-seal-panel">
        {!balance.balanced && hasAnything && (
          <label className="neg-debt">
            <input className="neg-check-input" type="checkbox" checked={acceptDebt} onChange={(e) => setAcceptDebt(e.target.checked)} />
            <CheckCircle />
            <span>
              Borrow <strong>{fmtMin(balance.debt)}</strong> from tomorrow. It will come first in tomorrow's deal.
            </span>
          </label>
        )}
        <div className="row-between">
          <div className="small muted">
            {!hasAnything
              ? 'Add a few items to get started.'
              : balance.balanced
                ? 'Both sides are happy. Ready when you are.'
                : acceptDebt
                  ? 'Making the deal with borrowed time.'
                  : 'Balance the two sides, or borrow from tomorrow.'}
          </div>
          <button className="btn btn-gold neg-seal-btn" disabled={!canSeal} onClick={seal}>
            Make the deal
          </button>
        </div>
      </div>
    </div>
  )
}

/* ======================= Sealed deal (today) ======================= */

export function SealedDeal({ deal, keepRate }: { deal: NegDeal; keepRate: number | null }) {
  const [tearing, setTearing] = useState(false)
  const pct = completionPct(deal.needs)
  const needTotal = sumMinutes(deal.needs)
  const needDone = doneMinutes(deal.needs)
  const reviewed = deal.status !== 'open'

  const toggle = (key: 'wants' | 'needs', id: string) => {
    if (deal.id == null) return
    const items = deal[key].map((i) => (i.id === id ? { ...i, done: !i.done } : i))
    if (key === 'wants') db.deals.update(deal.id, { wants: items })
    else db.deals.update(deal.id, { needs: items })
  }
  const toggleRule = (id: string) => {
    if (deal.id == null) return
    db.deals.update(deal.id, { rules: deal.rules.map((r) => (r.id === id ? { ...r, kept: !r.kept } : r)) })
  }
  const tearUp = async () => {
    if (deal.id == null) return
    saveDraft({ date: deal.date, wants: deal.wants.map((w) => ({ ...w, done: false })), needs: deal.needs.map((n) => ({ ...n, done: false })), rules: deal.rules.map((r) => ({ ...r, kept: undefined })) })
    await db.deals.delete(deal.id)
  }

  return (
    <div className="stack">
      <div className="panel neg-sealed-head">
        <div className="row-between">
          <div>
            <div className="neg-intro-date">{prettyDay(deal.date)}</div>
            <div className="neg-sealed-title">Today's deal</div>
            <div className="neg-sealed-sub muted small">
              Made at {new Date(deal.createdAt).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}
              {deal.rate && deal.rate !== 1 ? ` · rate 1:${deal.rate}` : ''}
              {deal.debtTaken ? ` · ${fmtMin(deal.debtTaken)} borrowed` : ''}
              {deal.owedIn ? ` · repaying ${fmtMin(deal.owedIn)}` : ''}
            </div>
          </div>
          <StatusChip status={deal.status} />
        </div>
        <div className="neg-progress" aria-label={`${pct}% of needs done`}>
          <div className="neg-progress-fill" style={{ width: `${pct}%` }} />
        </div>
        <div className="row-between small">
          <span>
            <span className="neg-num-inline">{pct}%</span> of needs done
          </span>
          {needTotal > 0 && (
            <span className="neg-num-inline muted">
              {fmtMin(needDone)} / {fmtMin(needTotal)}
            </span>
          )}
        </div>
      </div>

      <div className="neg-table">
        <SealedColumn side="present" title="Present You gets" hint="Paid for. Enjoy it, guilt-free." items={deal.wants} onToggle={(id) => toggle('wants', id)} />
        <SealedColumn side="future" title="Future You gets" hint="Tick each one off as you finish it." items={deal.needs} onToggle={(id) => toggle('needs', id)} />
      </div>

      <div className="grid-2">
        <div className="panel">
          <div className="panel-title">If-then rules</div>
          {deal.rules.length === 0 ? (
            <div className="neg-hint small">No rules in this deal. Try adding one tomorrow; they make deals easier to keep.</div>
          ) : (
            <ul className="neg-list">
              {deal.rules.map((r) => (
                <li key={r.id} className={`neg-row neg-check ${r.kept ? 'done' : ''}`}>
                  <label className="neg-check-label">
                    <input className="neg-check-input" type="checkbox" checked={!!r.kept} onChange={() => toggleRule(r.id)} />
                    <CheckCircle />
                    <span className="neg-check-text">
                      <span className="neg-kw">If</span> {r.when}, <span className="neg-kw">then I will</span> {r.then}
                    </span>
                  </label>
                </li>
              ))}
            </ul>
          )}
        </div>
        <div className="panel">
          <div className="panel-title">What this deal builds</div>
          <Projection needs={deal.needs} wants={deal.wants} keepRate={keepRate} />
        </div>
      </div>

      <div className="panel neg-evening">
        <div className="panel-title">{reviewed ? 'Evening review · done' : 'Evening review'}</div>
        {reviewed && deal.review && <p className="neg-review-quote">“{deal.review}”</p>}
        <ReviewPanel key={deal.status + (deal.reviewedAt ?? '')} deal={deal} />
      </div>

      {!reviewed && (
        <div className="row neg-tear">
          {tearing ? (
            <>
              <span className="small muted">Start over? Your items go back into the editor.</span>
              <button className="btn btn-danger btn-sm" onClick={tearUp}>
                Start over
              </button>
              <button className="btn btn-ghost btn-sm" onClick={() => setTearing(false)}>
                Keep it
              </button>
            </>
          ) : (
            <button className="btn btn-ghost btn-sm" onClick={() => setTearing(true)}>
              Change this deal…
            </button>
          )}
        </div>
      )}
    </div>
  )
}

function SealedColumn({
  side,
  title,
  hint,
  items,
  onToggle,
}: {
  side: 'present' | 'future'
  title: string
  hint: string
  items: DealItem[]
  onToggle: (id: string) => void
}) {
  return (
    <section className={`panel neg-card neg-card-${side}`}>
      <header className="neg-card-head">
        <div>
          <div className="neg-card-title">
            <span className="neg-label-dot" aria-hidden />
            {title}
          </div>
          <div className="muted small">{hint}</div>
        </div>
        <div className="neg-card-total">{fmtMin(sumMinutes(items))}</div>
      </header>
      <div className="neg-card-body">
        {items.length === 0 ? (
          <div className="neg-hint small">{side === 'present' ? 'Nothing asked for today.' : 'No needs in this deal.'}</div>
        ) : (
          <ul className="neg-list">
            {items.map((i) => (
              <li key={i.id} className={`neg-row neg-check ${i.done ? 'done' : ''}`}>
                <label className="neg-check-label">
                  <input className="neg-check-input" type="checkbox" checked={!!i.done} onChange={() => onToggle(i.id)} />
                  <CheckCircle />
                  <span className="neg-check-text">{i.text}</span>
                  {i.minutes ? <span className="neg-row-mins">{fmtMin(i.minutes)}</span> : null}
                </label>
              </li>
            ))}
          </ul>
        )}
      </div>
    </section>
  )
}

function CheckCircle() {
  return (
    <span className="neg-circle" aria-hidden>
      <svg viewBox="0 0 24 24" width="14" height="14">
        <path d="M6 12.5l4 4 8-9" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    </span>
  )
}
