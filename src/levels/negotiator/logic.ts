import type { Deal, DealItem, DealStatus } from '../../db/types'
import { addDays, dayKey } from '../../lib/date'

/**
 * Extra fields the Negotiator stores on a Deal record (Dexie keeps non-indexed fields).
 * All minute amounts for debt are in NEED-minutes: time Future You is owed.
 */
/** One line of the back-and-forth before the deal. */
export interface NegMessage {
  id: string
  from: 'present' | 'future'
  text: string
}

/** One negotiation. A day can hold several; each adds its terms to the day's deal. */
export interface NegTalk {
  id: string
  at: number
  thread: NegMessage[]
}

export interface NegDeal extends Deal {
  /** Every negotiation that went into today's deal, in order. */
  talks?: NegTalk[]
  /** Legacy: the single conversation from before a day could hold several. */
  thread?: NegMessage[]
  /** Exchange rate snapshot at sealing: 1 need-minute earns `rate` want-minutes. */
  rate?: number
  /** Need-minutes inherited from the previous deal (debt Future You was owed). */
  owedIn?: number
  /** Need-minutes Present You borrowed when sealing an unbalanced deal. */
  debtTaken?: number
  /** Need-minutes still owed after the evening review; carries into tomorrow. */
  owedOut?: number
  /** Completion percentage of needs at review time (0-100). */
  completion?: number
}

export const RATE_KEY = 'negotiator.rate'
export const DEFAULT_RATE = 1
export const RATE_OPTIONS = [0.5, 0.75, 1, 1.5, 2]

export const sumMinutes = (items: DealItem[]) => items.reduce((s, i) => s + (i.minutes && i.minutes > 0 ? i.minutes : 0), 0)
export const doneMinutes = (items: DealItem[]) => sumMinutes(items.filter((i) => i.done))

export interface Balance {
  needMin: number
  wantMin: number
  owedIn: number
  /** Want-minutes earned after paying back inherited debt. */
  earned: number
  /** earned - wantMin, in want-minutes. Negative = in debt. */
  surplus: number
  /** Need-minutes Present You would have to borrow to seal. 0 if balanced. */
  debt: number
  balanced: boolean
}

export function computeBalance(wants: DealItem[], needs: DealItem[], rate: number, owedIn: number): Balance {
  const needMin = sumMinutes(needs)
  const wantMin = sumMinutes(wants)
  const earned = Math.max(0, needMin - owedIn) * rate
  const surplus = earned - wantMin
  // If needs don't even cover inherited debt, the remainder of that is still owed too.
  const uncoveredOwed = Math.max(0, owedIn - needMin)
  const debt = surplus < 0 ? Math.ceil(-surplus / rate) + uncoveredOwed : uncoveredOwed
  return { needMin, wantMin, owedIn, earned, surplus, debt, balanced: debt === 0 }
}

/** Percentage of need-work completed. Uses minutes when given, else item count. */
export function completionPct(needs: DealItem[]): number {
  if (needs.length === 0) return 100
  const total = sumMinutes(needs)
  if (total > 0) {
    // Items without minutes count as 15 min so they still matter.
    const weight = (i: DealItem) => (i.minutes && i.minutes > 0 ? i.minutes : 15)
    const all = needs.reduce((s, i) => s + weight(i), 0)
    const done = needs.filter((i) => i.done).reduce((s, i) => s + weight(i), 0)
    return Math.round((done / all) * 100)
  }
  return Math.round((needs.filter((i) => i.done).length / needs.length) * 100)
}

export function suggestStatus(pct: number): Exclude<DealStatus, 'open'> {
  if (pct >= 90) return 'kept'
  if (pct >= 50) return 'partial'
  return 'broken'
}

/** Need-minutes still owed after a review. */
export function computeOwedOut(deal: NegDeal, status: Exclude<DealStatus, 'open'>): number {
  const borrowed = deal.debtTaken ?? 0
  if (status === 'kept') return borrowed
  const undone = sumMinutes(deal.needs.filter((n) => !n.done))
  return borrowed + undone
}

export function fmtMin(min: number): string {
  const m = Math.round(min)
  if (m < 60) return `${m}m`
  const h = Math.floor(m / 60)
  const r = m % 60
  return r ? `${h}h ${r}m` : `${h}h`
}

export function fmtHours(min: number): string {
  const h = min / 60
  if (h < 1) return `${Math.round(min)} minutes`
  if (h < 10) return `${Math.round(h * 10) / 10} hours`
  return `${Math.round(h)} hours`
}

/** Debt the newest past deal handed to today. */
export function inheritedOwed(deals: NegDeal[], today: string): { owed: number; from?: NegDeal; unreviewed?: NegDeal } {
  const past = deals.filter((d) => d.date < today).sort((a, b) => b.date.localeCompare(a.date))
  const last = past[0]
  if (!last) return { owed: 0 }
  if (last.status === 'open') return { owed: last.debtTaken ?? 0, from: last, unreviewed: last }
  return { owed: last.owedOut ?? 0, from: last }
}

/** Consecutive kept days, counting back from the most recent reviewed day. */
export function keptStreak(deals: NegDeal[], today: string = dayKey()): number {
  const byDate = new Map(deals.map((d) => [d.date, d]))
  let cursor = today
  // Today's deal only counts once reviewed; skip it if still open.
  const t = byDate.get(cursor)
  if (!t || t.status === 'open') cursor = addDays(cursor, -1)
  let streak = 0
  for (;;) {
    const d = byDate.get(cursor)
    if (!d || d.status !== 'kept') break
    streak++
    cursor = addDays(cursor, -1)
  }
  return streak
}

export function keepStats(deals: NegDeal[], today: string = dayKey()) {
  const since = addDays(today, -29)
  const recent = deals.filter((d) => d.date >= since && d.date <= today && d.status !== 'open')
  const kept = recent.filter((d) => d.status === 'kept').length
  const partial = recent.filter((d) => d.status === 'partial').length
  const broken = recent.filter((d) => d.status === 'broken').length
  const reviewed = recent.length
  return { reviewed, kept, partial, broken, rate: reviewed ? kept / reviewed : null }
}

/* ---------------- Future projection ---------------- */

interface Category {
  key: string
  label: string // "hours of deep work"
  unit: string // "workouts"
  match: RegExp
}

const CATEGORIES: Category[] = [
  { key: 'work', label: 'of deep work', unit: 'focused sessions', match: /deep|work|focus|project|code|coding|write|writing|ship|build|study|thesis|essay|report/i },
  { key: 'body', label: 'of training', unit: 'workouts', match: /gym|workout|run|lift|exercise|yoga|swim|cycle|bike|walk|stretch|train|cardio|sport/i },
  { key: 'skill', label: 'of skill practice', unit: 'practice sessions', match: /learn|practice|course|language|guitar|piano|draw|skill|lesson|duolingo|instrument/i },
  { key: 'read', label: 'of reading', unit: 'reading sessions', match: /read|book/i },
  { key: 'mind', label: 'of stillness', unit: 'meditations', match: /meditat|breath|journal|reflect|pray/i },
  { key: 'home', label: 'of life admin', unit: 'admin blocks', match: /clean|tidy|admin|email|bills|laundry|cook|meal|groceries|plan/i },
]

export interface ProjectionLine {
  key: string
  minutesPerDay: number
  itemsPerDay: number
  label: string
  unit: string
}

export function projectNeeds(needs: DealItem[]): ProjectionLine[] {
  const lines = new Map<string, ProjectionLine>()
  for (const n of needs) {
    const cat = CATEGORIES.find((c) => c.match.test(n.text))
    const key = cat?.key ?? 'other'
    const line = lines.get(key) ?? {
      key,
      minutesPerDay: 0,
      itemsPerDay: 0,
      label: cat?.label ?? 'invested in Future You',
      unit: cat?.unit ?? 'promises kept',
    }
    line.minutesPerDay += n.minutes && n.minutes > 0 ? n.minutes : 0
    line.itemsPerDay += 1
    lines.set(key, line)
  }
  return [...lines.values()].sort((a, b) => b.minutesPerDay - a.minutesPerDay)
}

export function projectionSentence(lines: ProjectionLine[], days: number, factor = 1): string {
  const parts = lines.map((l) =>
    l.minutesPerDay > 0
      ? `${fmtHours(l.minutesPerDay * days * factor)} ${l.label}`
      : `${Math.round(l.itemsPerDay * days * factor)} ${l.unit}`,
  )
  if (parts.length === 0) return ''
  if (parts.length === 1) return parts[0]
  return parts.slice(0, -1).join(', ') + ' and ' + parts[parts.length - 1]
}

/** A deal's negotiations, including the single legacy thread. */
export function talksOf(deal: NegDeal): NegTalk[] {
  if (deal.talks?.length) return deal.talks
  return deal.thread?.length ? [{ id: 'legacy', at: deal.createdAt, thread: deal.thread }] : []
}

/** Items agreed in a given negotiation. Untagged items belong to the first one. */
export function itemsOfTalk(items: DealItem[], talks: NegTalk[], talkId: string): DealItem[] {
  const first = talks[0]?.id
  return items.filter((i) => (i.talk && talks.some((t) => t.id === i.talk) ? i.talk === talkId : talkId === first))
}
