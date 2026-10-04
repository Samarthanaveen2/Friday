import Dexie, { type EntityTable } from 'dexie'
import type { Deal, Habit, HabitLog, LabEntry, Letter, Setting, Truth, WeeklyReview } from './types'

// Single local-first database. Nothing leaves the device.
// Only indexed fields are listed below; any other fields on the objects are stored too.
// If you add a table or index, bump the version with a new db.version(n).stores({...}).
export const db = new Dexie('samartha-tower') as Dexie & {
  deals: EntityTable<Deal, 'id'>
  truths: EntityTable<Truth, 'id'>
  lab: EntityTable<LabEntry, 'id'>
  habits: EntityTable<Habit, 'id'>
  habitLogs: EntityTable<HabitLog, 'id'>
  reviews: EntityTable<WeeklyReview, 'id'>
  letters: EntityTable<Letter, 'id'>
  settings: EntityTable<Setting, 'key'>
}

db.version(1).stores({
  deals: '++id, &date, status, createdAt',
  truths: '++id, createdAt, kind, status, who, topic',
  lab: '++id, createdAt, starred',
  habits: '++id, createdAt, archived',
  habitLogs: '++id, habitId, date, &[habitId+date]',
  reviews: '++id, &weekStart, createdAt',
  letters: '++id, createdAt, unlockAt, opened',
  settings: '&key',
})

export const TABLES = ['deals', 'truths', 'lab', 'habits', 'habitLogs', 'reviews', 'letters', 'settings'] as const

export async function getSetting<T>(key: string, fallback: T): Promise<T> {
  const row = await db.settings.get(key)
  return row ? (row.value as T) : fallback
}

export async function setSetting(key: string, value: unknown) {
  await db.settings.put({ key, value })
}
