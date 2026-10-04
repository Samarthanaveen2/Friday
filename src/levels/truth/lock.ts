// Truth Chamber PIN lock.
// The PIN keeps out casual eyes. The data itself is NOT encrypted — it lives in IndexedDB in plain form.
import { getSetting, setSetting, db } from '../../db/db'

export const PIN_KEY = 'truth.pin'
export const PIN_OFFERED_KEY = 'truth.pinOffered'
/** Re-lock after the tab has been hidden this long. */
export const HIDDEN_RELOCK_MS = 2 * 60 * 1000

export interface StoredPin {
  salt: string // hex
  hash: string // hex SHA-256 of salt + ':' + pin
}

// In-memory unlock state for this tab. Cleared on reload, on leaving the chamber, and after long hidden periods.
let unlocked = false

function toHex(buf: ArrayBuffer | Uint8Array): string {
  const bytes = buf instanceof Uint8Array ? buf : new Uint8Array(buf)
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('')
}

async function hashPin(pin: string, salt: string): Promise<string> {
  const data = new TextEncoder().encode(`${salt}:${pin}`)
  return toHex(await crypto.subtle.digest('SHA-256', data))
}

export function isValidPin(pin: string): boolean {
  return /^\d{4,6}$/.test(pin)
}

export async function getStoredPin(): Promise<StoredPin | null> {
  const v = await getSetting<StoredPin | null>(PIN_KEY, null)
  return v && typeof v === 'object' && 'hash' in v && 'salt' in v ? v : null
}

export async function hasPin(): Promise<boolean> {
  return (await getStoredPin()) !== null
}

export async function verifyPin(pin: string): Promise<boolean> {
  const stored = await getStoredPin()
  if (!stored) return true
  return (await hashPin(pin, stored.salt)) === stored.hash
}

export async function setPin(pin: string): Promise<void> {
  if (!isValidPin(pin)) throw new Error('PIN must be 4–6 digits')
  const salt = toHex(crypto.getRandomValues(new Uint8Array(16)))
  await setSetting(PIN_KEY, { salt, hash: await hashPin(pin, salt) } satisfies StoredPin)
  await setSetting(PIN_OFFERED_KEY, true)
  unlocked = true
}

export async function removePin(): Promise<void> {
  await db.settings.delete(PIN_KEY)
  await setSetting(PIN_OFFERED_KEY, true)
}

/** Try to unlock with a PIN. Returns true on success. */
export async function unlockTruth(pin: string): Promise<boolean> {
  const ok = await verifyPin(pin)
  if (ok) unlocked = true
  return ok
}

export function lockTruth(): void {
  unlocked = false
}

/** True when a PIN is set and the chamber hasn't been unlocked in this tab. Safe to call from any level. */
export async function isTruthLocked(): Promise<boolean> {
  if (unlocked) return false
  return hasPin()
}
