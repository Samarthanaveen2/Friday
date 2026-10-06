import Dexie, { type EntityTable } from 'dexie'
import type { Dare, LabEntry, Setting } from './types'

// Single local-first database. Nothing leaves the device.
// The name and version 1 are kept from Samartha Tower so existing Lab entries carry over.
// Only indexed fields are listed below; any other fields on the objects are stored too.
// If you add a table or index, add a new db.version(n).stores({...}).
export const db = new Dexie('samartha-tower') as Dexie & {
  lab: EntityTable<LabEntry, 'id'>
  dares: EntityTable<Dare, 'id'>
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

db.version(2).stores({
  dares: '++id, createdAt, status, facet',
})
