import { useEffect, useMemo, useState } from 'react'
import type { DealItem, IfThenRule } from '../../db/types'
import { db, setSetting } from '../../db/db'
import { prettyDay, uid } from '../../lib/date'
import { BalanceMeter, ItemColumn, NegThread, Projection, ReviewPanel, StandingRules, StatusChip } from './components'
import {
  type NegDeal,
  type NegMessage,
  type NegTalk,
  talksOf,
  RATE_KEY,
  RATE_OPTIONS,
  completionPct,
  computeBalance,
  doneMinutes,
  fmtMin,
  sumMinutes,
} from './logic'
import { NEGOTIATION_LINES } from './presets'
import { useStandingRules } from './rules'

interface Draft {
  date: string
  /** The back-and-forth before agreeing. */
  thread: NegMessage[]
  /** 'talk' while negotiating, 'terms' once both sides agree and write down the deal. */
  stage: 'talk' | 'terms'
  wants: DealItem[] // what Present You gets
  needs: DealItem[] // what Present You owes Future You
  rules?: IfThenRule[] // legacy; rules are standing now
}

const DRAFT_KEY = 'neg-draft'
/** A further negotiation started after today's deal already exists. */
const MORE_KEY = 'neg-draft-more'

function openingThread(wants: DealItem[], needs: DealItem[]): NegMessage[] {
  return [
    ...wants.map((w) => ({ id: uid(), from: 'present' as const, text: w.text })),
    ...needs.map((n) => ({ id: uid(), from: 'future' as const, text: n.text })),
  ]
}

function loadDraft(today: string, key = DRAFT_KEY): Draft {
  try {
    const raw = localStorage.getItem(key)
    if (raw) {
      const d = JSON.parse(raw) as Draft
      if (d.date === today) {
        if (d.thread?.length) return d
        // Older drafts had no conversation: turn their two sides into the opening messages.
        return { date: d.date, stage: 'talk', wants: [], needs: [], thread: openingThread(d.wants, d.needs) }
      }
    }
  } catch {
    /* storage unavailable */
  }
  return { date: today, thread: [], stage: 'talk', wants: [], needs: [] }
}

function saveDraft(d: Draft | null, key = DRAFT_KEY) {
  try {
    if (d) localStorage.setItem(key, JSON.stringify(d))
    else localStorage.removeItem(key)
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
  embedded = false,
  onDone,
}: {
  today: string
  rate: number
  owedIn: number
  owedFrom?: NegDeal
  unreviewed?: NegDeal
  keepRate: number | null
  /** A further negotiation inside today's existing deal. */
  embedded?: boolean
  onDone?: () => void
}) {
  const key = embedded ? MORE_KEY : DRAFT_KEY
  const [draft, setDraft] = useState<Draft>(() => loadDraft(today, key))
  const [acceptDebt, setAcceptDebt] = useState(false)
  const [sealing, setSealing] = useState(false)
  const rules = useStandingRules()
  const line = useMemo(() => NEGOTIATION_LINES[new Date().getDate() % NEGOTIATION_LINES.length], [])

  useEffect(() => saveDraft(draft, key), [draft, key])

  const balance = computeBalance(draft.wants, draft.needs, rate, owedIn)
  const hasAnything = draft.wants.length + draft.needs.length > 0
  const timed = [...draft.wants, ...draft.needs].some((i) => i.minutes && i.minutes > 0) || owedIn > 0
  const canSeal = hasAnything && (balance.balanced || acceptDebt) && !sealing

  useEffect(() => {
    if (balance.balanced) setAcceptDebt(false)
  }, [balance.balanced])

  const seal = async () => {
    if (!canSeal) return
    setSealing(true)
    const talk: NegTalk = { id: uid(), at: Date.now(), thread: draft.thread }
    const clean = (items: DealItem[]) =>
      items.filter((i) => i.text.trim()).map((i) => ({ ...i, text: i.text.trim(), done: false, talk: talk.id }))
    try {
      const existing = (await db.deals.where('date').equals(today).first()) as NegDeal | undefined
      if (existing?.id != null) {
        // Another negotiation today: its terms join the day's deal.
        await db.deals.update(existing.id, {
          wants: [...existing.wants, ...clean(draft.wants)],
          needs: [...existing.needs, ...clean(draft.needs)],
          talks: [...talksOf(existing), talk],
          debtTaken: (existing.debtTaken ?? 0) + balance.debt,
          rules: rules ?? existing.rules,
        } as Partial<NegDeal>)
      } else {
        const deal: NegDeal = {
          date: today,
          wants: clean(draft.wants),
          needs: clean(draft.needs),
          talks: [talk],
          // Snapshot of the standing rules, so History shows what was in force that day.
          rules: rules ?? [],
          status: 'open',
          createdAt: Date.now(),
          rate,
          owedIn,
          debtTaken: balance.debt,
        }
        await db.deals.add(deal)
      }
      saveDraft(null, key)
      onDone?.()
    } finally {
      setSealing(false)
    }
  }

  return (
    <div className="stack">
      {!embedded && unreviewed && (
        <div className="panel neg-alert">
          <div className="panel-title">Still open from {prettyDay(unreviewed.date)}</div>
          <p className="small" style={{ marginBottom: 12 }}>
            That deal was never closed. Take a moment to say how it went before making a new one.
          </p>
          <ReviewPanel deal={unreviewed} compact />
        </div>
      )}

      {!embedded && (
        <div className="neg-intro">
          <div className="neg-intro-date">{prettyDay(today)}</div>
          <p className="muted">{line}</p>
        </div>
      )}

      {!embedded && owedIn > 0 && !unreviewed && (
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

      {draft.stage === 'talk' ? (
        <div className="panel">
          <div className="panel-title">{embedded ? 'New negotiation' : 'The negotiation'}</div>
          {draft.thread.length === 0 && (
            <p className="small muted neg-rules-note">
              Start with what Present You wants. Then answer as Future You. Go back and forth until you both agree.
            </p>
          )}
          <NegThread messages={draft.thread} onChange={(thread) => setDraft((d) => ({ ...d, thread }))} />
          <div className="neg-step-actions">
            <span className="row">
              {embedded && (
                <button className="btn btn-ghost btn-sm" onClick={() => { saveDraft(null, key); onDone?.() }}>
                  Cancel
                </button>
              )}
              <span className="small muted">{draft.thread.length ? 'Agreed? Write down the terms.' : ''}</span>
            </span>
            <button className="btn btn-gold" disabled={draft.thread.length === 0} onClick={() => setDraft((d) => ({ ...d, stage: 'terms' }))}>
              We agree
            </button>
          </div>
        </div>
      ) : (
        <>
          {draft.thread.length > 0 && (
            <div className="panel">
              <details className="neg-thread-past">
                <summary>How you got here · {draft.thread.length} {draft.thread.length === 1 ? 'message' : 'messages'}</summary>
                <NegThread messages={draft.thread} />
              </details>
              <div className="neg-step-actions">
                <span />
                <button className="btn btn-ghost btn-sm" onClick={() => setDraft((d) => ({ ...d, stage: 'talk' }))}>
                  Keep negotiating
                </button>
              </div>
            </div>
          )}

          <div className="neg-table">
            <ItemColumn
              side="present"
              title="You get"
              subtitle="What Present You walks away with"
              items={draft.wants}
              onChange={(wants) => setDraft((d) => ({ ...d, wants }))}
              placeholder="e.g. 2 hours of reels"
            />
            <ItemColumn
              side="future"
              title="You owe"
              subtitle="What you promise Future You in return"
              items={draft.needs}
              onChange={(needs) => setDraft((d) => ({ ...d, needs }))}
              placeholder="e.g. lights off after that"
            />
          </div>

          {timed && <BalanceMeter balance={balance} decisions={0} rate={rate} rates={RATE_OPTIONS} onRate={(r) => setSetting(RATE_KEY, r)} />}
        </>
      )}

      {!embedded && (
        <div className="grid-2">
          <StandingRules rules={rules} />
          <div className="panel">
            <div className="panel-title">Future projection</div>
            <Projection needs={draft.needs} wants={draft.wants} keepRate={keepRate} />
          </div>
        </div>
      )}

      {draft.stage === 'terms' && (
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
              ? 'Write down what you each get from the deal.'
              : balance.balanced
                ? 'Both sides agree. Ready when you are.'
                : acceptDebt
                  ? 'Making the deal with borrowed time.'
                  : 'Balance the two sides, or borrow from tomorrow.'}
          </div>
          <button className="btn btn-gold neg-seal-btn" disabled={!canSeal} onClick={seal}>
            {embedded ? "Add to today's deal" : 'Make the deal'}
          </button>
        </div>
      </div>
      )}
    </div>
  )
}

/* ======================= Sealed deal (today) ======================= */

export function SealedDeal({ deal, keepRate, rate }: { deal: NegDeal; keepRate: number | null; rate: number }) {
  const [tearing, setTearing] = useState(false)
  const [more, setMore] = useState(() => {
    try {
      return !!localStorage.getItem(MORE_KEY)
    } catch {
      return false
    }
  })
  const talks = talksOf(deal)
  const rules = useStandingRules()
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
  const tearUp = async () => {
    if (deal.id == null) return
    const thread = talks.flatMap((t) => t.thread)
    if (thread.length) {
      saveDraft({ date: deal.date, thread, stage: 'terms', wants: deal.wants.map((w) => ({ ...w, done: false, talk: undefined })), needs: deal.needs.map((n) => ({ ...n, done: false, talk: undefined })) })
    } else {
      // A deal from before negotiations were a conversation: its two sides become the opening messages.
      saveDraft({ date: deal.date, thread: openingThread(deal.wants, deal.needs), stage: 'talk', wants: [], needs: [] })
    }
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
        <div className="neg-progress" aria-label={`${pct}% of promises kept`}>
          <div className="neg-progress-fill" style={{ width: `${pct}%` }} />
        </div>
        <div className="row-between small">
          <span>
            <span className="neg-num-inline">{pct}%</span> of promises kept
          </span>
          {needTotal > 0 && (
            <span className="neg-num-inline muted">
              {fmtMin(needDone)} / {fmtMin(needTotal)}
            </span>
          )}
        </div>
      </div>

      <div className="neg-table">
        <SealedColumn side="present" title="You get" hint="Agreed. Enjoy it, guilt-free." items={deal.wants} onToggle={(id) => toggle('wants', id)} />
        <SealedColumn side="future" title="You owe" hint="Tick each one off as you keep it." items={deal.needs} onToggle={(id) => toggle('needs', id)} />
      </div>

      <div className="grid-2">
        <StandingRules rules={rules} />
        <div className="panel">
          <div className="panel-title">What this deal builds</div>
          <Projection needs={deal.needs} wants={deal.wants} keepRate={keepRate} />
        </div>
      </div>

      {talks.length > 0 && (
        <div className="panel">
          <div className="panel-title">{talks.length === 1 ? 'The negotiation' : `Today's negotiations · ${talks.length}`}</div>
          <div className="stack-sm">
            {talks.map((t, i) => (
              <details key={t.id} className="neg-thread-past">
                <summary>
                  {talks.length > 1 ? `Negotiation ${i + 1} · ` : ''}
                  {new Date(t.at).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })} · {t.thread.length}{' '}
                  {t.thread.length === 1 ? 'message' : 'messages'}
                </summary>
                <NegThread messages={t.thread} />
              </details>
            ))}
          </div>
        </div>
      )}

      {!reviewed &&
        (more ? (
          <Negotiation embedded today={deal.date} rate={rate} owedIn={0} keepRate={keepRate} onDone={() => setMore(false)} />
        ) : (
          <button className="btn neg-more-btn" onClick={() => setMore(true)}>
            + New negotiation
          </button>
        ))}

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
        {sumMinutes(items) > 0 && <div className="neg-card-total">{fmtMin(sumMinutes(items))}</div>}
      </header>
      <div className="neg-card-body">
        {items.length === 0 ? (
          <div className="neg-hint small">{side === 'present' ? 'Nothing taken today.' : 'Nothing owed in this deal.'}</div>
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
