import { useLiveQuery } from 'dexie-react-hooks'
import { db } from '../../db/db'
import type { Deal, DealStatus } from '../../db/types'
import { addDays, dayKey, fromDayKey, weekStart } from '../../lib/date'

export interface NegotiatorStats {
  deal?: Deal
  status?: DealStatus
  itemsDone: number
  itemsTotal: number
  score: number // 0..1
}

export interface TruthStats {
  today: number
  thisWeek: number
  streak: number
  score: number
}

export interface LabStats {
  total: number
  today: number
  topics: number
  score: number
}

export interface ForgeStats {
  habits: number
  doneToday: number
  score: number
}

export interface Last30 {
  windowDays: number // days of data the rates are based on (7..30)
  hasData: boolean
  keptDeals: number
  votes: number
  truths: number
  holes: number
}

export interface ReactorData {
  today: string
  negotiator: NegotiatorStats
  truth: TruthStats
  lab: LabStats
  forge: ForgeStats
  power: number // 0..100
  last30: Last30
}

const DAY = 86_400_000

/** Live, cross-level snapshot for the Reactor. Reads every level's table directly. */
export function useReactorData(today: string = dayKey()): ReactorData | undefined {
  return useLiveQuery(async () => {
    const [deals, truths, lab, habits, logs] = await Promise.all([
      db.deals.toArray(),
      db.truths.toArray(),
      db.lab.toArray(),
      db.habits.toArray(),
      db.habitLogs.toArray(),
    ])

    // ---- Negotiator
    const deal = deals.find((d) => d.date === today)
    const items = deal ? [...(deal.wants ?? []), ...(deal.needs ?? [])] : []
    const itemsDone = items.filter((i) => i.done).length
    let negScore = 0
    if (deal) {
      if (deal.status === 'kept') negScore = 1
      else negScore = 0.4 + 0.6 * (items.length ? itemsDone / items.length : 0)
    }

    // ---- Truth
    const truthDays = new Set(truths.map((t) => dayKey(new Date(t.createdAt))))
    const wk = fromDayKey(weekStart(today)).getTime()
    const truthsToday = truths.filter((t) => dayKey(new Date(t.createdAt)) === today).length
    let streak = 0
    let cursor = truthDays.has(today) ? today : addDays(today, -1)
    while (truthDays.has(cursor)) {
      streak++
      cursor = addDays(cursor, -1)
    }

    // ---- Lab
    const labToday = lab.filter((e) => dayKey(new Date(e.createdAt)) === today).length
    const topicSet = new Set<string>()
    lab.forEach((e) => (e.topics ?? []).forEach((t) => topicSet.add(t.trim().toLowerCase())))

    // ---- Forge
    const active = habits.filter((h) => !h.archived)
    const activeIds = new Set(active.map((h) => h.id))
    const doneToday = logs.filter((l) => l.date === today && l.done && activeIds.has(l.habitId)).length

    // ---- Last 30 days (for projection)
    const now = Date.now()
    const since = addDays(today, -29)
    const sinceMs = fromDayKey(since).getTime()
    const firstTimes = [
      ...deals.map((d) => fromDayKey(d.date).getTime()),
      ...truths.map((t) => t.createdAt),
      ...lab.map((e) => e.createdAt),
      ...logs.map((l) => fromDayKey(l.date).getTime()),
      ...habits.map((h) => h.createdAt),
    ]
    const first = firstTimes.length ? Math.min(...firstTimes) : now
    const daysOfData = Math.ceil((now - first) / DAY) + 1
    const windowDays = Math.min(30, Math.max(7, daysOfData))

    const last30: Last30 = {
      windowDays,
      keptDeals: deals.filter((d) => d.date >= since && d.status === 'kept').length,
      votes: logs.filter((l) => l.date >= since && l.done).length,
      truths: truths.filter((t) => t.createdAt >= sinceMs).length,
      holes: lab.filter((e) => e.createdAt >= sinceMs).length,
      hasData: false,
    }
    last30.hasData = last30.keptDeals + last30.votes + last30.truths + last30.holes > 0

    const negotiator: NegotiatorStats = { deal, status: deal?.status, itemsDone, itemsTotal: items.length, score: negScore }
    const truth: TruthStats = {
      today: truthsToday,
      thisWeek: truths.filter((t) => t.createdAt >= wk).length,
      streak,
      score: truthsToday > 0 ? 1 : 0,
    }
    const labStats: LabStats = { total: lab.length, today: labToday, topics: topicSet.size, score: labToday > 0 ? 1 : 0 }
    const forge: ForgeStats = {
      habits: active.length,
      doneToday,
      score: active.length ? Math.min(1, doneToday / active.length) : 0,
    }
    const power = Math.round(((negotiator.score + truth.score + labStats.score + forge.score) / 4) * 100)

    return { today, negotiator, truth, lab: labStats, forge, power, last30 }
  }, [today])
}
