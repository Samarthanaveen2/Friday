// Backup / restore engine for the Vault. Pure logic, no UI.
import { db, TABLES } from '../../db/db'
import { dayKey } from '../../lib/date'

export type TableName = (typeof TABLES)[number]
export type TableData = Record<TableName, unknown[]>
export type Counts = Record<TableName, number>

export const APP_ID = 'samartha-tower'
export const BACKUP_VERSION = 1
export const LAST_BACKUP_KEY = 'vault.lastBackup'
const PBKDF2_ITERATIONS = 250_000

export interface BackupFile {
  app: typeof APP_ID
  version: number
  exportedAt: string
  data: Partial<Record<string, unknown[]>>
}

export interface EncryptedEnvelope {
  app: typeof APP_ID
  encrypted: true
  version: number
  kdf: { name: 'PBKDF2'; hash: 'SHA-256'; iterations: number }
  cipher: 'AES-GCM-256'
  salt: string
  iv: string
  ciphertext: string
}

export class VaultError extends Error {}

// ---------- counts ----------

export async function countAll(): Promise<Counts> {
  const entries = await Promise.all(TABLES.map(async (t) => [t, await db.table(t).count()] as const))
  return Object.fromEntries(entries) as Counts
}

export function countsOf(data: TableData): Counts {
  return Object.fromEntries(TABLES.map((t) => [t, data[t].length])) as Counts
}

export function total(counts: Counts): number {
  return TABLES.reduce((sum, t) => sum + counts[t], 0)
}

// ---------- export ----------

export async function buildBackup(): Promise<BackupFile> {
  const data: Record<string, unknown[]> = {}
  await db.transaction('r', TABLES.map((t) => db.table(t)), async () => {
    for (const t of TABLES) data[t] = await db.table(t).toArray()
  })
  return { app: APP_ID, version: BACKUP_VERSION, exportedAt: new Date().toISOString(), data }
}

export function backupFileName(d = new Date()): string {
  return `samartha-tower-backup-${dayKey(d)}.json`
}

export function downloadText(text: string, filename: string) {
  const blob = new Blob([text], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  a.remove()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}

// ---------- crypto ----------

function toB64(bytes: Uint8Array): string {
  let s = ''
  const chunk = 0x8000
  for (let i = 0; i < bytes.length; i += chunk) s += String.fromCharCode(...bytes.subarray(i, i + chunk))
  return btoa(s)
}

function fromB64(b64: string): Uint8Array<ArrayBuffer> {
  const s = atob(b64)
  const out = new Uint8Array(s.length)
  for (let i = 0; i < s.length; i++) out[i] = s.charCodeAt(i)
  return out
}

async function deriveKey(password: string, salt: Uint8Array<ArrayBuffer>, iterations: number) {
  const base = await crypto.subtle.importKey('raw', new TextEncoder().encode(password), 'PBKDF2', false, ['deriveKey'])
  return crypto.subtle.deriveKey(
    { name: 'PBKDF2', hash: 'SHA-256', salt, iterations },
    base,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt'],
  )
}

export async function encryptText(plain: string, password: string): Promise<EncryptedEnvelope> {
  if (!crypto?.subtle) throw new VaultError('Encryption needs a secure context (https or localhost).')
  const salt = crypto.getRandomValues(new Uint8Array(16))
  const iv = crypto.getRandomValues(new Uint8Array(12))
  const key = await deriveKey(password, salt, PBKDF2_ITERATIONS)
  const ct = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, new TextEncoder().encode(plain))
  return {
    app: APP_ID,
    encrypted: true,
    version: BACKUP_VERSION,
    kdf: { name: 'PBKDF2', hash: 'SHA-256', iterations: PBKDF2_ITERATIONS },
    cipher: 'AES-GCM-256',
    salt: toB64(salt),
    iv: toB64(iv),
    ciphertext: toB64(new Uint8Array(ct)),
  }
}

export async function decryptEnvelope(env: EncryptedEnvelope, password: string): Promise<string> {
  if (!crypto?.subtle) throw new VaultError('Decryption needs a secure context (https or localhost).')
  let salt, iv, ct
  try {
    salt = fromB64(env.salt)
    iv = fromB64(env.iv)
    ct = fromB64(env.ciphertext)
  } catch {
    throw new VaultError('The encrypted backup is damaged (invalid base64).')
  }
  const iterations = env.kdf?.iterations ?? PBKDF2_ITERATIONS
  const key = await deriveKey(password, salt, iterations)
  try {
    const plain = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, ct)
    return new TextDecoder().decode(plain)
  } catch {
    throw new VaultError('Wrong password, or the file has been modified.')
  }
}

// ---------- parse & validate ----------

export type Parsed =
  | { kind: 'encrypted'; envelope: EncryptedEnvelope }
  | { kind: 'plain'; backup: ValidBackup }

export interface ValidBackup {
  exportedAt: string | null
  version: number
  data: TableData
  ignored: string[] // unknown tables present in the file
}

function isObj(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v)
}

export function parseFileText(text: string): Parsed {
  let json: unknown
  try {
    json = JSON.parse(text)
  } catch {
    throw new VaultError('This file is not valid JSON. Pick a Samartha Tower backup (.json).')
  }
  if (!isObj(json) || json.app !== APP_ID) {
    throw new VaultError('This file is not a Samartha Tower backup (missing app: "samartha-tower").')
  }
  if (json.encrypted === true) {
    for (const f of ['salt', 'iv', 'ciphertext'] as const) {
      if (typeof json[f] !== 'string') throw new VaultError(`Encrypted backup is missing its "${f}".`)
    }
    return { kind: 'encrypted', envelope: json as unknown as EncryptedEnvelope }
  }
  return { kind: 'plain', backup: validateBackup(json) }
}

export function validateBackup(json: unknown): ValidBackup {
  if (!isObj(json) || json.app !== APP_ID) throw new VaultError('Decrypted content is not a Samartha Tower backup.')
  const version = typeof json.version === 'number' ? json.version : NaN
  if (!Number.isFinite(version)) throw new VaultError('Backup has no version number.')
  if (version > BACKUP_VERSION) {
    throw new VaultError(`Backup is from a newer Tower (format v${version}); this app reads up to v${BACKUP_VERSION}.`)
  }
  if (!isObj(json.data)) throw new VaultError('Backup has no "data" section.')
  const src = json.data
  const data = {} as TableData
  for (const t of TABLES) {
    const rows = src[t]
    if (rows === undefined) {
      data[t] = []
      continue
    }
    if (!Array.isArray(rows)) throw new VaultError(`Table "${t}" should be a list of rows.`)
    rows.forEach((r, i) => {
      if (!isObj(r)) throw new VaultError(`Row ${i + 1} in "${t}" is not an object.`)
      if (t === 'settings' ? typeof r.key !== 'string' : r.id !== undefined && typeof r.id !== 'number') {
        throw new VaultError(`Row ${i + 1} in "${t}" has an invalid primary key.`)
      }
    })
    data[t] = rows
  }
  const ignored = Object.keys(src).filter((k) => !(TABLES as readonly string[]).includes(k))
  return { exportedAt: typeof json.exportedAt === 'string' ? json.exportedAt : null, version, data, ignored }
}

// ---------- restore & wipe ----------

const allTables = () => TABLES.map((t) => db.table(t))

/** Replace ALL data atomically. If anything fails, nothing changes. */
export async function restoreAll(data: TableData) {
  try {
    await db.transaction('rw', allTables(), async () => {
      for (const t of TABLES) await db.table(t).clear()
      for (const t of TABLES) if (data[t].length) await db.table(t).bulkPut(data[t])
    })
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e)
    throw new VaultError(`Restore failed and was rolled back — your current data is untouched. (${msg})`)
  }
}

export async function wipeAll() {
  await db.transaction('rw', allTables(), async () => {
    for (const t of TABLES) await db.table(t).clear()
  })
}

// ---------- formatting ----------

export function timeAgo(ts: number, now = Date.now()): string {
  const s = Math.max(0, Math.round((now - ts) / 1000))
  if (s < 45) return 'just now'
  const m = Math.round(s / 60)
  if (m < 60) return `${m} minute${m === 1 ? '' : 's'} ago`
  const h = Math.round(m / 60)
  if (h < 24) return `${h} hour${h === 1 ? '' : 's'} ago`
  const d = Math.round(h / 24)
  if (d < 30) return `${d} day${d === 1 ? '' : 's'} ago`
  const mo = Math.round(d / 30)
  if (mo < 12) return `${mo} month${mo === 1 ? '' : 's'} ago`
  const y = Math.round(d / 365)
  return `${y} year${y === 1 ? '' : 's'} ago`
}

export function formatBytes(n: number): string {
  if (!Number.isFinite(n) || n <= 0) return '0 B'
  const units = ['B', 'KB', 'MB', 'GB', 'TB']
  const i = Math.min(units.length - 1, Math.floor(Math.log(n) / Math.log(1024)))
  const v = n / 1024 ** i
  return `${v < 10 && i > 0 ? v.toFixed(1) : Math.round(v)} ${units[i]}`
}

export const TABLE_LABELS: Record<TableName, string> = {
  deals: 'Deals',
  truths: 'Truths',
  lab: 'Lab entries',
  habits: 'Habits',
  habitLogs: 'Habit logs',
  reviews: 'Weekly reviews',
  letters: 'Letters',
  settings: 'Settings',
}
