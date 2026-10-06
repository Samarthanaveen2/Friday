// Plain-JSON backup of the Attic: export everything, import by merging.
// Also reads the Lab part of an unencrypted Samartha Tower backup.
import { db } from '../db/db'
import type { Dare, LabEntry } from '../db/types'
import { dayKey } from '../lib/date'

export const APP_ID = 'the-attic'
const TOWER_ID = 'samartha-tower'

export async function exportJson(): Promise<string> {
  const [lab, dares] = await Promise.all([db.lab.toArray(), db.dares.toArray()])
  return JSON.stringify({ app: APP_ID, version: 1, exportedAt: new Date().toISOString(), data: { lab, dares } }, null, 2)
}

export function downloadText(text: string, filename = `attic-backup-${dayKey()}.json`) {
  const url = URL.createObjectURL(new Blob([text], { type: 'application/json' }))
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  a.remove()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}

const isObj = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v)

const labKey = (e: Pick<LabEntry, 'createdAt' | 'topics'>) => `${e.createdAt}|${e.topics.join('|')}`
const dareKey = (d: Pick<Dare, 'createdAt' | 'text'>) => `${d.createdAt}|${d.text}`

/** Merge a backup into the database. Rows already present are skipped. Returns how many were added. */
export async function importJson(text: string): Promise<{ lab: number; dares: number }> {
  let json: unknown
  try {
    json = JSON.parse(text)
  } catch {
    throw new Error('That file is not valid JSON.')
  }
  if (!isObj(json) || (json.app !== APP_ID && json.app !== TOWER_ID)) throw new Error('That file is not an Attic or Tower backup.')
  if (json.encrypted === true) throw new Error('Encrypted Tower backups can’t be read here. Export an unencrypted one instead.')
  if (!isObj(json.data)) throw new Error('The backup has no data section.')

  const lab = (Array.isArray(json.data.lab) ? json.data.lab : []).filter(
    (r): r is LabEntry => isObj(r) && typeof r.createdAt === 'number' && Array.isArray(r.topics),
  )
  const dares = (Array.isArray(json.data.dares) ? json.data.dares : []).filter(
    (r): r is Dare => isObj(r) && typeof r.createdAt === 'number' && typeof r.text === 'string',
  )

  let added = { lab: 0, dares: 0 }
  await db.transaction('rw', db.lab, db.dares, async () => {
    const haveLab = new Set((await db.lab.toArray()).map(labKey))
    const haveDares = new Set((await db.dares.toArray()).map(dareKey))
    const newLab = lab.filter((r) => !haveLab.has(labKey(r))).map(({ id: _id, ...r }) => ({ ...r, links: Array.isArray(r.links) ? r.links : [] }))
    const newDares = dares.filter((r) => !haveDares.has(dareKey(r))).map(({ id: _id, ...r }) => r)
    if (newLab.length) await db.lab.bulkAdd(newLab)
    if (newDares.length) await db.dares.bulkAdd(newDares)
    added = { lab: newLab.length, dares: newDares.length }
  })
  return added
}
