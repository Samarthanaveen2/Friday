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
import { NEED_PRESETS, NEGOTIATION_LINES, WANT_PRESETS } from './presets'

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
          <div className="panel-title">Unfinished business · {prettyDay(unreviewed.date)}</div>
          <p className="small" style={{ marginBottom: 12 }}>
            That deal was never closed. Be honest about how it went before striking a new one.
          </p>
          <ReviewPanel deal={unreviewed} compact />
        </div>
      )}

      <div className="neg-intro">
        <div className="mono neg-intro-date">{prettyDay(today)} · Opening negotiations</div>
        <p className="muted">{line}</p>
      </div>

      {owedIn > 0 && !unreviewed && (
        <div className="neg-owed">
          <div className="neg-owed-num mono">{fmtMin(owedIn)}</div>
          <div>
            <div className="neg-owed-title">Future You is owed</div>
            <div className="small muted">
              Carried from {owedFrom ? prettyDay(owedFrom.date) : 'your last deal'}
              {owedFrom?.status && owedFrom.status !== 'open' ? ` (${owedFrom.status})` : ''}. It gets paid first, out of today's needs.
            </div>
          </div>
        </div>
      )}

      <div className="panel neg-table-panel">
        <div className="neg-table">
          <ItemColumn
            side="present"
            title="Present You wants"
            subtitle="Fun, rest, scrolling, gaming"
            items={draft.wants}
            onChange={(wants) => setDraft((d) => ({ ...d, wants }))}
            presets={WANT_PRESETS}
            placeholder="I want…"
          />
          <div className="neg-vs" aria-hidden>
            <span>VS</span>
          </div>
          <ItemColumn
            side="future"
            title="Future You needs"
            subtitle="Work, health, skills"
            items={draft.needs}
            onChange={(needs) => setDraft((d) => ({ ...d, needs }))}
            presets={NEED_PRESETS}
            placeholder="I need…"
          />
        </div>

        <BalanceMeter balance={balance} rate={rate} rates={RATE_OPTIONS} onRate={(r) => setSetting(RATE_KEY, r)} />
      </div>

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
            <input type="checkbox" checked={acceptDebt} onChange={(e) => setAcceptDebt(e.target.checked)} />
            <span>
              Present You takes on <strong className="neg-red">{fmtMin(balance.debt)}</strong> of debt. Future You will collect it tomorrow,
              before anything else.
            </span>
          </label>
        )}
        <div className="row-between">
          <div className="small muted">
            {!hasAnything
              ? 'Nothing to sign yet.'
              : balance.balanced
                ? 'Both sides agree. Ready to sign.'
                : acceptDebt
                  ? 'Signing on credit.'
                  : 'Future You will not sign an unbalanced deal.'}
          </div>
          <button className="btn btn-gold neg-seal-btn" disabled={!canSeal} onClick={seal}>
            Seal the deal
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
      <div className="panel glow neg-sealed-head">
        <div className="neg-seal-stamp mono" aria-hidden>
          SEALED
        </div>
        <div className="row-between">
          <div>
            <div className="mono neg-intro-date">{prettyDay(deal.date)} · Deal in force</div>
            <div className="neg-sealed-sub muted small">
              Signed {new Date(deal.createdAt).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}
              {deal.rate && deal.rate !== 1 ? ` · rate 1:${deal.rate}` : ''}
              {deal.debtTaken ? ` · on credit (${fmtMin(deal.debtTaken)} debt)` : ''}
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
            <span className="mono neg-gold">{pct}%</span> of Future You's needs delivered
          </span>
          {needTotal > 0 && (
            <span className="mono muted">
              {fmtMin(needDone)} / {fmtMin(needTotal)}
            </span>
          )}
        </div>
      </div>

      <div className="panel neg-table-panel">
        <div className="neg-table">
          <SealedColumn side="present" title="Present You gets" hint="Paid for. Enjoy it, guilt-free." items={deal.wants} onToggle={(id) => toggle('wants', id)} />
          <div className="neg-vs" aria-hidden>
            <span>⇄</span>
          </div>
          <SealedColumn side="future" title="Future You gets" hint="Tick each one off as you deliver it." items={deal.needs} onToggle={(id) => toggle('needs', id)} />
        </div>
      </div>

      <div className="grid-2">
        <div className="panel">
          <div className="panel-title">If-then rules · kept?</div>
          {deal.rules.length === 0 ? (
            <div className="neg-side-empty small">No rules in this deal. Add some tomorrow; they make deals easier to keep.</div>
          ) : (
            <ul className="neg-rules">
              {deal.rules.map((r) => (
                <li key={r.id} className={`neg-rule neg-check ${r.kept ? 'done' : ''}`}>
                  <label className="neg-check-label">
                    <input type="checkbox" checked={!!r.kept} onChange={() => toggleRule(r.id)} />
                    <span className="neg-rule-text">
                      <span className="neg-kw">If</span> {r.when} <span className="neg-kw">then I will</span> {r.then}
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
        <div className="panel-title">{reviewed ? 'Evening review · closed' : 'Evening review'}</div>
        {reviewed && deal.review && <p className="neg-review-quote">“{deal.review}”</p>}
        <ReviewPanel key={deal.status + (deal.reviewedAt ?? '')} deal={deal} />
      </div>

      {!reviewed && (
        <div className="row neg-tear">
          {tearing ? (
            <>
              <span className="small muted">Tear up the deal and renegotiate? Your items go back on the table.</span>
              <button className="btn btn-danger btn-sm" onClick={tearUp}>
                Tear it up
              </button>
              <button className="btn btn-ghost btn-sm" onClick={() => setTearing(false)}>
                Keep it
              </button>
            </>
          ) : (
            <button className="btn btn-ghost btn-sm" onClick={() => setTearing(true)}>
              Renegotiate…
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
    <section className={`neg-side neg-side-${side}`}>
      <div className="neg-side-head">
        <div>
          <div className="neg-side-title">{title}</div>
          <div className="muted small">{hint}</div>
        </div>
        <div className="neg-side-total mono">{fmtMin(sumMinutes(items))}</div>
      </div>
      {items.length === 0 ? (
        <div className="neg-side-empty small">{side === 'present' ? 'Nothing asked for. Noble.' : 'No needs on this deal.'}</div>
      ) : (
        <ul className="neg-items">
          {items.map((i) => (
            <li key={i.id} className={`neg-check ${i.done ? 'done' : ''}`}>
              <label className="neg-check-label">
                <input type="checkbox" checked={!!i.done} onChange={() => onToggle(i.id)} />
                <span className="neg-check-text">{i.text}</span>
                {i.minutes ? <span className="mono muted small">{fmtMin(i.minutes)}</span> : null}
              </label>
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}
