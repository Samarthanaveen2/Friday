import { useEffect, useRef, useState, type ReactNode } from 'react'
import { useLiveQuery } from 'dexie-react-hooks'
import LevelHeader from '../../components/LevelHeader'
import { TABLES, getSetting, setSetting } from '../../db/db'
import { LEVELS } from '../../lib/levels'
import {
  LAST_BACKUP_KEY,
  TABLE_LABELS,
  VaultError,
  backupFileName,
  buildBackup,
  countAll,
  countsOf,
  decryptEnvelope,
  downloadText,
  encryptText,
  formatBytes,
  parseFileText,
  restoreAll,
  timeAgo,
  total,
  validateBackup,
  wipeAll,
  type Counts,
  type EncryptedEnvelope,
  type ValidBackup,
} from './backup'
import './vault.css'

const DAY = 86_400_000
const RESET_PHRASE = 'RESET TOWER'

function errMsg(e: unknown): string {
  if (e instanceof VaultError) return e.message
  if (e instanceof Error) return `Unexpected error: ${e.message}`
  return 'Unexpected error.'
}

type Notice = { tone: 'ok' | 'warn' | 'error' | 'info'; text: ReactNode } | null

function NoticeBox({ notice }: { notice: Notice }) {
  if (!notice) return null
  return (
    <div className={`vault-notice vault-notice-${notice.tone}`} role={notice.tone === 'error' ? 'alert' : 'status'}>
      {notice.text}
    </div>
  )
}

export default function Vault() {
  const counts = useLiveQuery(countAll, [])
  const lastBackup = useLiveQuery(() => getSetting<number | null>(LAST_BACKUP_KEY, null), [])

  return (
    <div className="vault">
      <LevelHeader path="/vault" right={<BackupStatusBadge lastBackup={lastBackup} />} />
      <div className="vault-grid">
        <BackupPanel lastBackup={lastBackup} counts={counts} />
        <RestorePanel counts={counts} />
        <StatsPanel counts={counts} />
        <DangerPanel counts={counts} />
        <AboutPanel />
      </div>
    </div>
  )
}

// ---------------- status badge ----------------

function backupAge(lastBackup: number | null | undefined) {
  if (lastBackup === undefined) return { label: '…', stale: false }
  if (!lastBackup) return { label: 'Never backed up', stale: true }
  return { label: `Last backup: ${timeAgo(lastBackup)}`, stale: Date.now() - lastBackup > 7 * DAY }
}

function BackupStatusBadge({ lastBackup }: { lastBackup: number | null | undefined }) {
  const { label, stale } = backupAge(lastBackup)
  return (
    <div className={`vault-badge ${stale ? 'vault-badge-warn' : 'vault-badge-ok'}`}>
      <span className="vault-dot" aria-hidden />
      {label}
    </div>
  )
}

// ---------------- backup ----------------

function BackupPanel({ lastBackup, counts }: { lastBackup: number | null | undefined; counts?: Counts }) {
  const [encrypt, setEncrypt] = useState(false)
  const [pw, setPw] = useState('')
  const [pw2, setPw2] = useState('')
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<Notice>(null)
  const { label, stale } = backupAge(lastBackup)

  const pwProblem = encrypt
    ? !pw
      ? 'Enter a password.'
      : pw.length < 8
        ? 'Use at least 8 characters.'
        : pw !== pw2
          ? 'Passwords do not match.'
          : null
    : null

  async function exportNow() {
    setBusy(true)
    setNotice(null)
    try {
      const backup = await buildBackup()
      const json = JSON.stringify(backup, null, 2)
      const text = encrypt ? JSON.stringify(await encryptText(json, pw), null, 2) : json
      downloadText(text, backupFileName())
      await setSetting(LAST_BACKUP_KEY, Date.now())
      const rows = Object.values(backup.data).reduce((n, r) => n + (r?.length ?? 0), 0)
      setNotice({
        tone: 'ok',
        text: (
          <>
            Saved <span className="mono">{backupFileName()}</span> — {rows} rows
            {encrypt ? ', encrypted with AES-256. Keep the password somewhere safe: it cannot be recovered.' : '.'}
          </>
        ),
      })
      setPw('')
      setPw2('')
    } catch (e) {
      setNotice({ tone: 'error', text: errMsg(e) })
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className="panel vault-panel vault-span-2">
      <div className="panel-title">Backup</div>
      <div className="vault-backup">
        <div className="stack-sm">
          <p>
            Download every table of the Tower as a single JSON file. Your data lives only in this browser — a backup is
            the only copy that survives a cleared cache or a lost device.
          </p>
          <div className={`vault-nudge ${stale ? 'vault-nudge-warn' : ''}`}>
            <strong>{label}.</strong>{' '}
            {lastBackup === null
              ? 'Make your first backup now — it takes a second.'
              : stale
                ? 'It has been over a week. A fresh backup is a good idea.'
                : 'You are covered.'}
          </div>
        </div>

        <div className="stack-sm">
          <label className="vault-check">
            <input type="checkbox" checked={encrypt} onChange={(e) => setEncrypt(e.target.checked)} />
            <span>Encrypt with a password</span>
          </label>
          {encrypt && (
            <div className="vault-pw stack-sm">
              <input
                className="input"
                type="password"
                placeholder="Password (min 8 characters)"
                autoComplete="new-password"
                value={pw}
                onChange={(e) => setPw(e.target.value)}
              />
              <input
                className="input"
                type="password"
                placeholder="Repeat password"
                autoComplete="new-password"
                value={pw2}
                onChange={(e) => setPw2(e.target.value)}
              />
              <p className="small muted">
                PBKDF2-SHA256 (250k rounds) → AES-GCM 256. There is no recovery if you forget it.
              </p>
            </div>
          )}
          <div className="row">
            <button className="btn btn-primary" onClick={exportNow} disabled={busy || !!pwProblem}>
              {busy ? (encrypt ? 'Encrypting…' : 'Exporting…') : 'Download backup'}
            </button>
            {counts && <span className="small muted mono">{total(counts)} rows</span>}
            {pwProblem && (pw || pw2) && <span className="small vault-text-warn">{pwProblem}</span>}
          </div>
        </div>
      </div>
      <NoticeBox notice={notice} />
    </section>
  )
}

// ---------------- restore ----------------

type RestoreState =
  | { step: 'idle' }
  | { step: 'locked'; fileName: string; envelope: EncryptedEnvelope }
  | { step: 'preview'; fileName: string; backup: ValidBackup; encrypted: boolean }

function RestorePanel({ counts }: { counts?: Counts }) {
  const fileRef = useRef<HTMLInputElement>(null)
  const [state, setState] = useState<RestoreState>({ step: 'idle' })
  const [pw, setPw] = useState('')
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<Notice>(null)

  function reset() {
    setState({ step: 'idle' })
    setPw('')
    if (fileRef.current) fileRef.current.value = ''
  }

  async function onFile(file: File | undefined) {
    if (!file) return
    setNotice(null)
    try {
      if (file.size > 200 * 1024 * 1024) throw new VaultError('That file is too large to be a Tower backup.')
      const parsed = parseFileText(await file.text())
      if (parsed.kind === 'encrypted') setState({ step: 'locked', fileName: file.name, envelope: parsed.envelope })
      else setState({ step: 'preview', fileName: file.name, backup: parsed.backup, encrypted: false })
    } catch (e) {
      setNotice({ tone: 'error', text: errMsg(e) })
      reset()
    }
  }

  async function unlock() {
    if (state.step !== 'locked') return
    setBusy(true)
    setNotice(null)
    try {
      const text = await decryptEnvelope(state.envelope, pw)
      let json: unknown
      try {
        json = JSON.parse(text)
      } catch {
        throw new VaultError('Decrypted content is not valid JSON.')
      }
      setState({ step: 'preview', fileName: state.fileName, backup: validateBackup(json), encrypted: true })
      setPw('')
    } catch (e) {
      setNotice({ tone: 'error', text: errMsg(e) })
    } finally {
      setBusy(false)
    }
  }

  async function confirmRestore() {
    if (state.step !== 'preview') return
    setBusy(true)
    setNotice(null)
    try {
      await restoreAll(state.backup.data)
      // The file itself is proof of a backup at its export time.
      const exported = state.backup.exportedAt ? Date.parse(state.backup.exportedAt) : NaN
      if (Number.isFinite(exported) && exported > (await getSetting<number>(LAST_BACKUP_KEY, 0))) {
        await setSetting(LAST_BACKUP_KEY, exported)
      }
      const n = total(countsOf(state.backup.data))
      setNotice({ tone: 'ok', text: `Restore complete — ${n} rows loaded. The Tower now matches the backup.` })
      reset()
    } catch (e) {
      setNotice({ tone: 'error', text: errMsg(e) })
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className="panel vault-panel vault-span-2">
      <div className="panel-title">Restore</div>
      <input
        ref={fileRef}
        type="file"
        accept="application/json,.json"
        className="vault-file"
        tabIndex={-1}
        aria-hidden
        onChange={(e) => onFile(e.target.files?.[0])}
      />
      {state.step === 'idle' && (
        <div className="row-between">
          <p className="muted">
            Load a backup file (plain or encrypted). You will see exactly what is inside before anything changes.
          </p>
          <button className="btn" onClick={() => fileRef.current?.click()}>
            Choose backup file…
          </button>
        </div>
      )}

      {state.step === 'locked' && (
        <form
          className="stack-sm"
          onSubmit={(e) => {
            e.preventDefault()
            unlock()
          }}
        >
          <p>
            <span className="mono">{state.fileName}</span> is encrypted. Enter its password to read it.
          </p>
          <div className="row vault-unlock">
            <input
              className="input"
              type="password"
              placeholder="Backup password"
              autoComplete="current-password"
              autoFocus
              value={pw}
              onChange={(e) => setPw(e.target.value)}
            />
            <button className="btn btn-primary" type="submit" disabled={busy || !pw}>
              {busy ? 'Decrypting…' : 'Unlock'}
            </button>
            <button className="btn btn-ghost" type="button" onClick={reset} disabled={busy}>
              Cancel
            </button>
          </div>
        </form>
      )}

      {state.step === 'preview' && (
        <div className="stack">
          <div className="row-between">
            <div>
              <div className="mono small">{state.fileName}</div>
              <div className="small muted">
                {state.backup.exportedAt
                  ? `Exported ${new Date(state.backup.exportedAt).toLocaleString()} (${timeAgo(Date.parse(state.backup.exportedAt))})`
                  : 'Export date unknown'}
                {' · '}format v{state.backup.version}
                {state.encrypted && ' · decrypted'}
              </div>
            </div>
          </div>
          <table className="vault-table">
            <thead>
              <tr>
                <th>Table</th>
                <th className="num">Now</th>
                <th className="num">In backup</th>
              </tr>
            </thead>
            <tbody>
              {TABLES.map((t) => {
                const now = counts?.[t] ?? 0
                const next = state.backup.data[t].length
                return (
                  <tr key={t}>
                    <td>{TABLE_LABELS[t]}</td>
                    <td className="num muted">{now}</td>
                    <td className={`num ${next < now ? 'vault-text-warn' : ''}`}>{next}</td>
                  </tr>
                )
              })}
              <tr className="vault-total">
                <td>Total</td>
                <td className="num muted">{counts ? total(counts) : 0}</td>
                <td className="num">{total(countsOf(state.backup.data))}</td>
              </tr>
            </tbody>
          </table>
          {state.backup.ignored.length > 0 && (
            <p className="small muted">Ignoring unknown tables: {state.backup.ignored.join(', ')}.</p>
          )}
          <div className="vault-notice vault-notice-warn">
            Restoring <strong>replaces all current data</strong> with the contents of this file. It happens in a single
            transaction: if anything fails, nothing changes. Consider downloading a backup of the current state first.
          </div>
          <div className="row">
            <button className="btn btn-gold" onClick={confirmRestore} disabled={busy}>
              {busy ? 'Restoring…' : 'Replace everything with this backup'}
            </button>
            <button className="btn btn-ghost" onClick={reset} disabled={busy}>
              Cancel
            </button>
          </div>
        </div>
      )}
      <NoticeBox notice={notice} />
    </section>
  )
}

// ---------------- stats ----------------

type Persist = 'unknown' | 'persisted' | 'not-persisted' | 'denied' | 'unsupported'

function StatsPanel({ counts }: { counts?: Counts }) {
  const [estimate, setEstimate] = useState<{ usage: number; quota: number } | null | 'unsupported'>(null)
  const [persist, setPersist] = useState<Persist>('unknown')
  const [asking, setAsking] = useState(false)
  const totalRows = counts ? total(counts) : undefined

  useEffect(() => {
    let alive = true
    const s = navigator.storage
    if (!s?.estimate) setEstimate('unsupported')
    else
      s.estimate()
        .then((e) => alive && setEstimate({ usage: e.usage ?? 0, quota: e.quota ?? 0 }))
        .catch(() => alive && setEstimate('unsupported'))
    if (!s?.persisted) setPersist('unsupported')
    else
      s.persisted()
        .then((p) => alive && setPersist(p ? 'persisted' : 'not-persisted'))
        .catch(() => alive && setPersist('unsupported'))
    return () => {
      alive = false
    }
  }, [totalRows])

  async function requestPersist() {
    setAsking(true)
    try {
      const ok = await navigator.storage.persist()
      setPersist(ok ? 'persisted' : 'denied')
    } catch {
      setPersist('denied')
    } finally {
      setAsking(false)
    }
  }

  const max = counts ? Math.max(1, ...TABLES.map((t) => counts[t])) : 1
  const pct = estimate && estimate !== 'unsupported' && estimate.quota ? (estimate.usage / estimate.quota) * 100 : 0

  const persistText: Record<Persist, string> = {
    unknown: 'Checking…',
    persisted: 'Persistent — the browser will not evict Tower data under storage pressure.',
    'not-persisted': 'Best-effort — the browser may clear data if the device runs low on space.',
    denied: 'The browser declined for now. Installing the app or using it often usually earns persistence.',
    unsupported: 'This browser does not support persistent storage requests.',
  }

  return (
    <section className="panel vault-panel">
      <div className="panel-title">Storage</div>
      <div className="stack">
        <div>
          <div className="row-between vault-kv">
            <span className="muted small">Used on this device</span>
            <span className="mono">
              {estimate === null
                ? '…'
                : estimate === 'unsupported'
                  ? 'n/a'
                  : `${formatBytes(estimate.usage)} / ${formatBytes(estimate.quota)}`}
            </span>
          </div>
          <div className="vault-meter" aria-hidden>
            <span style={{ width: `${Math.max(pct, pct > 0 ? 1 : 0)}%` }} />
          </div>
          <p className="small muted vault-mt">Approximate; includes the app's cached files.</p>
        </div>

        <ul className="vault-counts">
          {TABLES.map((t) => (
            <li key={t}>
              <span className="vault-count-label">{TABLE_LABELS[t]}</span>
              <span className="vault-bar" aria-hidden>
                <span style={{ width: `${counts ? (counts[t] / max) * 100 : 0}%` }} />
              </span>
              <span className="mono vault-count-num">{counts ? counts[t] : '…'}</span>
            </li>
          ))}
        </ul>

        <div className="stack-sm">
          <div className="row-between">
            <span className={`vault-badge ${persist === 'persisted' ? 'vault-badge-ok' : 'vault-badge-muted'}`}>
              <span className="vault-dot" aria-hidden />
              {persist === 'persisted' ? 'Persistent storage' : 'Best-effort storage'}
            </span>
            {persist !== 'persisted' && persist !== 'unsupported' && (
              <button className="btn btn-sm" onClick={requestPersist} disabled={asking}>
                {asking ? 'Asking…' : 'Request persistence'}
              </button>
            )}
          </div>
          <p className="small muted">{persistText[persist]}</p>
        </div>
      </div>
    </section>
  )
}

// ---------------- danger zone ----------------

function DangerPanel({ counts }: { counts?: Counts }) {
  const [phrase, setPhrase] = useState('')
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<Notice>(null)
  const armed = phrase === RESET_PHRASE

  async function wipe() {
    if (!armed) return
    setBusy(true)
    setNotice(null)
    try {
      await wipeAll()
      setPhrase('')
      setNotice({ tone: 'info', text: 'The Tower has been reset. Every table is empty.' })
    } catch (e) {
      setNotice({ tone: 'error', text: errMsg(e) })
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className="panel vault-panel vault-danger">
      <div className="panel-title">Danger zone</div>
      <div className="stack-sm">
        <p>
          Permanently erase <strong>everything</strong> — {counts ? total(counts) : '…'} rows across deals, truths,
          lab entries, habits, letters and settings. This cannot be undone.
        </p>
        <label className="label" htmlFor="vault-reset">
          Type <span className="mono vault-text-danger">{RESET_PHRASE}</span> to confirm
        </label>
        <input
          id="vault-reset"
          className="input mono"
          value={phrase}
          onChange={(e) => setPhrase(e.target.value)}
          placeholder={RESET_PHRASE}
          autoComplete="off"
          spellCheck={false}
        />
        <div className="row">
          <button className="btn btn-danger" onClick={wipe} disabled={!armed || busy}>
            {busy ? 'Wiping…' : 'Wipe everything'}
          </button>
        </div>
      </div>
      <NoticeBox notice={notice} />
    </section>
  )
}

// ---------------- about ----------------

const LEVEL_BLURBS: Record<string, string> = {
  '/': 'The core. Letters across time and a pulse on where today stands against the future.',
  '/negotiator': 'Each morning, Present You and Future You strike a deal: wants, needs and if-then rules.',
  '/truth': 'A private chamber for saying the thing — lies, avoided conversations, truths about yourself.',
  '/lab': 'Draw random topics, collide them, follow rabbit holes and keep what you learn.',
  '/forge': 'Keystone habits tied to identity, with weekly reviews that fix instead of shame.',
}

function AboutPanel() {
  return (
    <section className="panel vault-panel vault-span-2">
      <div className="panel-title">About the Tower</div>
      <div className="vault-about">
        <div className="stack-sm">
          <p>
            Samartha Tower is a personal operating system built as a climb. Each level trains one trait — planning,
            honesty, openness, conscientiousness — around a single reactor core that connects who you are today with
            who you are becoming.
          </p>
          <p className="muted">
            <strong className="vault-text-cyan">Local and private by design.</strong> There are no accounts, no
            servers, no analytics and no AI. Every word lives in this browser's IndexedDB and never leaves the device
            unless you export it yourself. That also means you are the backup plan — use the Vault.
          </p>
        </div>
        <ol className="vault-levels">
          {LEVELS.filter((l) => l.path !== '/vault').map((l) => (
            <li key={l.path} style={{ ['--accent' as string]: l.accent }}>
              <span className="vault-level-num mono">{l.number}</span>
              <div>
                <div className="vault-level-name">
                  {l.name} <span className="muted small">· {l.trait}</span>
                </div>
                <div className="small muted">{LEVEL_BLURBS[l.path] ?? l.tagline}</div>
              </div>
            </li>
          ))}
        </ol>
      </div>
    </section>
  )
}
