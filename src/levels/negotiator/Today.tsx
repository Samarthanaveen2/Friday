import { useEffect, useMemo, useState } from 'react'
import type { DealItem } from '../../db/types'
import { db, setSetting } from '../../db/db'
import { prettyDay, uid } from '../../lib/date'
import { BalanceMeter, ItemColumn, NegThread, Projection, ReviewPanel, StandingRules, StatusChip } from './components'
import {
  type NegDeal,
  type NegMessage,
  type NegTalk,
  RATE_KEY,
  RATE_OPTIONS,
  completionPct,
  computeBalance,
  doneMinutes,
  fmtMin,
  itemsOfTalk,
  sumMinutes,
  talksOf,
} from './logic'
import { NEGOTIATION_LINES } from './presets'
import { useStandingRules } from './rules'

/** One negotiation still in progress. Several can be open at once. */
interface Draft {
  id: string
  /** The back-and-forth before agreeing. */
  thread: NegMessage[]
  /** 'talk' while negotiating, 'terms' once both sides agree and write down the deal. */
  stage: 'talk' | 'terms'
  wants: DealItem[] // what Present You gets
  needs: DealItem[] // what Present You owes Future You
}

const DRAFTS_KEY = 'neg-drafts'
const LEGACY_KEYS = ['neg-draft', 'neg-draft-more']

const blankDraft = (): Draft => ({ id: uid(), thread: [], stage: 'talk', wants: [], needs: [] })

function openingThread(wants: DealItem[], needs: DealItem[]): NegMessage[] {
  return [
    ...wants.map((w) => ({ id: uid(), from: 'present' as const, text: w.text })),
    ...needs.map((n) => ({ id: uid(), from: 'future' as const, text: n.text })),
  ]
}

function loadDrafts(today: string): Draft[] {
  try {
    const raw = localStorage.getItem(DRAFTS_KEY)
    if (raw) {
      const saved = JSON.parse(raw) as { date: string; drafts: Draft[] }
      if (saved.date === today) return saved.drafts
    }
    // Drafts saved before several negotiations could be open at once.
    const out: Draft[] = []
    for (const k of LEGACY_KEYS) {
      const old = localStorage.getItem(k)
      if (!old) continue
      const d = JSON.parse(old) as Partial<Draft> & { date: string; wants: DealItem[]; needs: DealItem[] }
      if (d.date !== today) continue
      out.push(
        d.thread?.length
          ? { id: uid(), thread: d.thread, stage: d.stage ?? 'talk', wants: d.wants, needs: d.needs }
          : { ...blankDraft(), thread: openingThread(d.wants, d.needs) },
      )
    }
    return out
  } catch {
    return []
  }
}

function saveDrafts(today: string, drafts: Draft[]) {
  try {
    localStorage.setItem(DRAFTS_KEY, JSON.stringify({ date: today, drafts }))
    LEGACY_KEYS.forEach((k) => localStorage.removeItem(k))
  } catch {
    /* storage unavailable */
  }
}

/* ======================= Today ======================= */

export function TodayPage({
  today,
  rate,
  deal,
  owedIn,
  owedFrom,
  unreviewed,
  keepRate,
}: {
  today: string
  rate: number
  /** Today's deal, once at least one negotiation has been agreed. */
  deal?: NegDeal
  owedIn: number
  owedFrom?: NegDeal
  unreviewed?: NegDeal
  keepRate: number | null
}) {
  const [drafts, setDrafts] = useState<Draft[]>(() => {
    const saved = loadDrafts(today)
    return saved.length || deal ? saved : [blankDraft()]
  })
  const rules = useStandingRules()
  const line = useMemo(() => NEGOTIATION_LINES[new Date().getDate() % NEGOTIATION_LINES.length], [])
  const reviewed = !!deal && deal.status !== 'open'

  useEffect(() => saveDrafts(today, drafts), [today, drafts])

  const update = (d: Draft) => setDrafts((all) => all.map((x) => (x.id === d.id ? d : x)))
  const remove = (id: string) => setDrafts((all) => all.filter((x) => x.id !== id))
  const addDraft = () => setDrafts((all) => [...all, blankDraft()])

  const reopen = async () => {
    if (!deal || deal.id == null) return
    const talks = talksOf(deal)
    const fresh = (items: DealItem[]) => items.map((i) => ({ ...i, done: false, talk: undefined }))
    const back: Draft[] = talks.length
      ? talks.map((t) => ({
          id: uid(),
          thread: t.thread,
          stage: 'terms',
          wants: fresh(itemsOfTalk(deal.wants, talks, t.id)),
          needs: fresh(itemsOfTalk(deal.needs, talks, t.id)),
        }))
      : [{ ...blankDraft(), thread: openingThread(deal.wants, deal.needs) }]
    setDrafts((all) => [...back, ...all])
    await db.deals.delete(deal.id)
  }

  const projectionNeeds = deal ? deal.needs : drafts.flatMap((d) => d.needs)
  const projectionWants = deal ? deal.wants : drafts.flatMap((d) => d.wants)

  return (
    <div className="stack">
      {!deal && unreviewed && (
        <div className="panel neg-alert">
          <div className="panel-title">Still open from {prettyDay(unreviewed.date)}</div>
          <p className="small" style={{ marginBottom: 12 }}>
            That deal was never closed. Take a moment to say how it went before making a new one.
          </p>
          <ReviewPanel deal={unreviewed} compact />
        </div>
      )}

      {deal ? (
        <SealedDeal deal={deal} />
      ) : (
        <div className="neg-intro">
          <div className="neg-intro-date">{prettyDay(today)}</div>
          <p className="muted">{line}</p>
        </div>
      )}

      {!deal && owedIn > 0 && !unreviewed && (
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

      {!reviewed && (
        <>
          {drafts.map((d, i) => (
            <NegotiationCard
              key={d.id}
              draft={d}
              title={drafts.length > 1 ? `Negotiation ${i + 1}` : deal ? 'New negotiation' : 'The negotiation'}
              today={today}
              rate={rate}
              owedIn={deal ? 0 : owedIn}
              hasDeal={!!deal}
              onChange={update}
              onRemove={() => remove(d.id)}
            />
          ))}
          <button className="btn neg-more-btn" onClick={addDraft}>
            + New negotiation
          </button>
        </>
      )}

      <div className="grid-2">
        <StandingRules rules={rules} />
        <div className="panel">
          <div className="panel-title">{deal ? 'What this deal builds' : 'Future projection'}</div>
          <Projection needs={projectionNeeds} wants={projectionWants} keepRate={keepRate} />
        </div>
      </div>

      {deal && <TalksPanel deal={deal} />}

      {deal && (
        <div className="panel neg-evening">
          <div className="panel-title">{reviewed ? 'Evening review · done' : 'Evening review'}</div>
          {reviewed && deal.review && <p className="neg-review-quote">“{deal.review}”</p>}
          <ReviewPanel key={deal.status + (deal.reviewedAt ?? '')} deal={deal} />
        </div>
      )}

      {deal && !reviewed && <ReopenDeal onReopen={reopen} />}
    </div>
  )
}

/* ======================= One negotiation ======================= */

function NegotiationCard({
  draft,
  title,
  today,
  rate,
  owedIn,
  hasDeal,
  onChange,
  onRemove,
}: {
  draft: Draft
  title: string
  today: string
  rate: number
  owedIn: number
  hasDeal: boolean
  onChange: (d: Draft) => void
  onRemove: () => void
}) {
  const [acceptDebt, setAcceptDebt] = useState(false)
  const [sealing, setSealing] = useState(false)
  const [discarding, setDiscarding] = useState(false)
  const rules = useStandingRules()
  const set = (patch: Partial<Draft>) => onChange({ ...draft, ...patch })

  const balance = computeBalance(draft.wants, draft.needs, rate, owedIn)
  const hasAnything = draft.wants.length + draft.needs.length > 0
  const timed = [...draft.wants, ...draft.needs].some((i) => i.minutes && i.minutes > 0) || owedIn > 0
  const canSeal = hasAnything && (balance.balanced || acceptDebt) && !sealing
  const empty = draft.thread.length === 0 && !hasAnything

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
      onRemove()
    } finally {
      setSealing(false)
    }
  }

  return (
    <section className="panel neg-nego">
      <header className="neg-nego-head">
        <div className="panel-title">
          {title}
          {draft.stage === 'terms' ? ' · writing the terms' : ''}
        </div>
        {discarding ? (
          <span className="row">
            <button className="btn btn-danger btn-sm" onClick={onRemove}>
              Discard
            </button>
            <button className="btn btn-ghost btn-sm" onClick={() => setDiscarding(false)}>
              Keep
            </button>
          </span>
        ) : (
          <button className="btn btn-ghost btn-sm" onClick={() => (empty ? onRemove() : setDiscarding(true))}>
            {empty ? 'Close' : 'Discard…'}
          </button>
        )}
      </header>

      {draft.stage === 'talk' ? (
        <>
          {draft.thread.length === 0 && (
            <p className="small muted neg-rules-note">
              Start with what Present You wants. Then answer as Future You. Go back and forth until you both agree.
            </p>
          )}
          <NegThread messages={draft.thread} onChange={(thread) => set({ thread })} />
          <div className="neg-step-actions">
            <span className="small muted">{draft.thread.length ? 'Agreed? Write down the terms. Or leave it open and come back later.' : ''}</span>
            <button className="btn btn-gold" disabled={draft.thread.length === 0} onClick={() => set({ stage: 'terms' })}>
              We agree
            </button>
          </div>
        </>
      ) : (
        <div className="stack">
          {draft.thread.length > 0 && (
            <div className="neg-nego-past">
              <details className="neg-thread-past">
                <summary>How you got here · {draft.thread.length} {draft.thread.length === 1 ? 'message' : 'messages'}</summary>
                <NegThread messages={draft.thread} />
              </details>
              <button className="btn btn-ghost btn-sm" onClick={() => set({ stage: 'talk' })}>
                Keep negotiating
              </button>
            </div>
          )}

          <div className="neg-table">
            <ItemColumn
              side="present"
              title="You get"
              subtitle="What Present You walks away with"
              items={draft.wants}
              onChange={(wants) => set({ wants })}
              placeholder="e.g. 2 hours of reels"
            />
            <ItemColumn
              side="future"
              title="You owe"
              subtitle="What you promise Future You in return"
              items={draft.needs}
              onChange={(needs) => set({ needs })}
              placeholder="e.g. lights off after that"
            />
          </div>

          {timed && <BalanceMeter balance={balance} decisions={0} rate={rate} rates={RATE_OPTIONS} onRate={(r) => setSetting(RATE_KEY, r)} />}

          <div className="neg-seal-panel">
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
                {hasDeal ? "Add to today's deal" : 'Make the deal'}
              </button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}

/* ======================= Today's agreed deal ======================= */

function SealedDeal({ deal }: { deal: NegDeal }) {
  const pct = completionPct(deal.needs)
  const needTotal = sumMinutes(deal.needs)
  const needDone = doneMinutes(deal.needs)

  const toggle = (key: 'wants' | 'needs', id: string) => {
    if (deal.id == null) return
    const items = deal[key].map((i) => (i.id === id ? { ...i, done: !i.done } : i))
    if (key === 'wants') db.deals.update(deal.id, { wants: items })
    else db.deals.update(deal.id, { needs: items })
  }

  return (
    <>
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
    </>
  )
}

function TalksPanel({ deal }: { deal: NegDeal }) {
  const talks = talksOf(deal)
  if (!talks.length) return null
  return (
    <div className="panel">
      <div className="panel-title">{talks.length === 1 ? 'Agreed today' : `Agreed today · ${talks.length} negotiations`}</div>
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
  )
}

function ReopenDeal({ onReopen }: { onReopen: () => void }) {
  const [asking, setAsking] = useState(false)
  return (
    <div className="row neg-tear">
      {asking ? (
        <>
          <span className="small muted">Reopen? Each agreed negotiation goes back to being editable.</span>
          <button className="btn btn-danger btn-sm" onClick={onReopen}>
            Reopen
          </button>
          <button className="btn btn-ghost btn-sm" onClick={() => setAsking(false)}>
            Keep it
          </button>
        </>
      ) : (
        <button className="btn btn-ghost btn-sm" onClick={() => setAsking(true)}>
          Change this deal…
        </button>
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
