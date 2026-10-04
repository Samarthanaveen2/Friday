// The Forge — data helpers and pure stats. No streak here ever "resets to zero" in the UI:
// we lead with total identity votes and 30-day consistency, and treat the current run as secondary.
import { useLiveQuery } from 'dexie-react-hooks'
import { db } from '../../db/db'
import type { Habit, HabitLog, WeeklyReview } from '../../db/types'
import { addDays, dayKey, weekStart } from '../../lib/date'

/** Habit with Forge-only extras (stored as non-indexed fields). */
export interface ForgeHabit extends Habit {
  tiny?: string // the "minimum version", e.g. "Read 1 page"
  archivedAt?: number
}

/** Log with Forge-only extras. */
export interface ForgeLog extends HabitLog {
  tiny?: boolean // cast via the tiny version
  at?: number
}

export type ExperimentResult = 'worked' | 'partly' | 'didnt'

export interface ForgeReview extends WeeklyReview {
  experimentResult?: ExperimentResult // how last week's fix went, judged this week
  updatedAt?: number
}

export const SOFT_CAP = 5
export const CONSISTENCY_WINDOW = 30
export const HEATMAP_WEEKS = 16

export interface Preset {
  name: string
  identity: string
  tiny: string
}

export const PRESETS: Preset[] = [
  { name: 'Read 10 pages', identity: 'I am a reader', tiny: 'Read 1 page' },
  { name: 'Train for 30 min', identity: 'I am someone who trains', tiny: 'Put on shoes, 10 squats' },
  { name: 'Walk 20 minutes', identity: 'I am someone who moves every day', tiny: 'Walk to the end of the street' },
  { name: 'Write 200 words', identity: 'I am a writer', tiny: 'Write one sentence' },
  { name: 'Meditate 10 min', identity: 'I am someone who stays calm under pressure', tiny: '3 slow breaths' },
  { name: 'Plan tomorrow', identity: 'I am someone who keeps promises to Future Me', tiny: 'Write tomorrow’s one thing' },
  { name: 'Tidy for 10 min', identity: 'I am someone who keeps order', tiny: 'Put away 3 things' },
  { name: 'Phone out of bedroom', identity: 'I am someone who protects my sleep', tiny: 'Phone on the far shelf' },
  { name: 'Study / practise skill', identity: 'I am someone who gets better daily', tiny: '2 minutes of practice' },
  { name: 'Drink water first', identity: 'I am someone who looks after my body', tiny: 'One glass' },
]

export function defaultTiny(name: string): string {
  const n = name.trim()
  return n ? `2 minutes of: ${n.toLowerCase()}` : 'Just 2 minutes'
}

export function tinyFor(h: ForgeHabit): string {
  return h.tiny?.trim() || defaultTiny(h.name)
}

// ---------- writes ----------

export async function setVote(habitId: number, date: string, done: boolean, tiny = false) {
  const existing = (await db.habitLogs.where('[habitId+date]').equals([habitId, date]).first()) as ForgeLog | undefined
  if (!done) {
    if (existing?.id != null) await db.habitLogs.delete(existing.id)
    return
  }
  const row: ForgeLog = { habitId, date, done: true, tiny, at: Date.now() }
  if (existing?.id != null) await db.habitLogs.update(existing.id, row)
  else await db.habitLogs.add(row)
}

export async function toggleVote(habitId: number, date: string) {
  const existing = await db.habitLogs.where('[habitId+date]').equals([habitId, date]).first()
  await setVote(habitId, date, !existing?.done)
}

// ---------- pure stats ----------

export type DoneIndex = Map<number, Set<string>>

export function indexLogs(logs: HabitLog[]): DoneIndex {
  const m: DoneIndex = new Map()
  for (const l of logs) {
    if (!l.done) continue
    let s = m.get(l.habitId)
    if (!s) m.set(l.habitId, (s = new Set()))
    s.add(l.date)
  }
  return m
}

export type HabitState = 'done' | 'open' | 'missed-one' | 'recover' | 'new'

export interface HabitStats {
  votes: number
  doneToday: boolean
  doneYesterday: boolean
  /** consecutive missed days before today (only counted since creation) */
  missedRun: number
  state: HabitState
  consistency: number // 0..100
  windowDays: number
  windowDone: number
  /** true when the habit is younger than the 30-day window */
  sinceStart: boolean
  run: number // current run of done days (ending today or yesterday)
  best: number
}

export function habitStats(h: Habit, done: Set<string> | undefined, today = dayKey()): HabitStats {
  const d = done ?? new Set<string>()
  const created = dayKey(new Date(h.createdAt))
  // Earliest day that counts: creation day, or earliest vote (in case they backfilled yesterday).
  let start = created
  for (const k of d) if (k < start) start = k
  const yesterday = addDays(today, -1)
  const doneToday = d.has(today)
  const doneYesterday = d.has(yesterday)

  let missedRun = 0
  for (let k = yesterday; k >= start && !d.has(k); k = addDays(k, -1)) missedRun++

  // consistency over last 30 days (today counts only if already done — the day isn't over)
  let windowDays = 0
  let windowDone = 0
  const sinceStart = addDays(today, -(CONSISTENCY_WINDOW - 1)) < start
  for (let i = 0; i < CONSISTENCY_WINDOW; i++) {
    const k = addDays(today, -i)
    if (k < start) break
    if (i === 0 && !doneToday) continue
    windowDays++
    if (d.has(k)) windowDone++
  }
  const consistency = windowDays ? Math.round((windowDone / windowDays) * 100) : 0

  let run = 0
  for (let k = doneToday ? today : yesterday; d.has(k); k = addDays(k, -1)) run++

  let best = 0
  const sorted = [...d].sort()
  let cur = 0
  let prev = ''
  for (const k of sorted) {
    cur = prev && addDays(prev, 1) === k ? cur + 1 : 1
    if (cur > best) best = cur
    prev = k
  }

  let state: HabitState
  if (doneToday) state = 'done'
  else if (start >= today) state = 'new'
  else if (missedRun >= 2) state = 'recover'
  else if (missedRun === 1) state = 'missed-one'
  else state = 'open'

  return { votes: d.size, doneToday, doneYesterday, missedRun, state, consistency, windowDays, windowDone, sinceStart, run, best }
}

export interface HeatCell {
  key: string
  value: number // 0..1
  count: number
  total: number
  future: boolean
}

/** Columns = weeks (oldest first), rows = Mon..Sun. */
export function heatmapGrid(habits: Habit[], idx: DoneIndex, weeks = HEATMAP_WEEKS, today = dayKey()): HeatCell[][] {
  const first = addDays(weekStart(today), -7 * (weeks - 1))
  const cols: HeatCell[][] = []
  for (let w = 0; w < weeks; w++) {
    const col: HeatCell[] = []
    for (let r = 0; r < 7; r++) {
      const key = addDays(first, w * 7 + r)
      const future = key > today
      let total = 0
      let count = 0
      for (const h of habits) {
        if (dayKey(new Date(h.createdAt)) > key && !idx.get(h.id!)?.has(key)) continue
        total++
        if (idx.get(h.id!)?.has(key)) count++
      }
      col.push({ key, count, total, value: total ? count / total : 0, future })
    }
    cols.push(col)
  }
  return cols
}

// ---------- Reactor export ----------

async function computeToday(): Promise<{ done: number; total: number }> {
  const today = dayKey()
  const habits = (await db.habits.toArray()).filter((h) => !h.archived)
  if (!habits.length) return { done: 0, total: 0 }
  const ids = new Set(habits.map((h) => h.id))
  const logs = await db.habitLogs.where('date').equals(today).toArray()
  const done = new Set(logs.filter((l) => l.done && ids.has(l.habitId)).map((l) => l.habitId)).size
  return { done, total: habits.length }
}

/** Today's identity votes across active keystone habits. */
export function forgeTodaySummary(): Promise<{ done: number; total: number }> {
  return computeToday()
}

/** Live version for React: undefined while loading. */
export function useForgeTodaySummary(): { done: number; total: number } | undefined {
  return useLiveQuery(computeToday, [])
}
