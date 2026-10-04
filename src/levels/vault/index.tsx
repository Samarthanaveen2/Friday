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

// iOS Settings-style building blocks: a section header, an inset grouped list and a footer note.
function Section({ title, footer, children }: { title: string; footer?: ReactNode; children: ReactNode }) {
  return (
    <section className="vault-section">
      <h2 className="vault-section-title">{title}</h2>
      <div className="vault-group">{children}</div>
      {footer && <div className="vault-footer">{footer}</div>}
    </section>
  )
}

function Row({ label, value, sub, className = '' }: { label: ReactNode; value?: ReactNode; sub?: ReactNode; className?: string }) {
  return (
    <div className={`vault-row ${className}`}>
      <div className="vault-row-main">
        <div className="vault-row-label">{label}</div>
        {sub && <div className="vault-row-sub">{sub}</div>}
      </div>
      {value !== undefined && <div className="vault-row-value">{value}</div>}
    </div>
  )
}

function Chevron() {
  return (
    <svg className="vault-chevron" width="8" height="13" viewBox="0 0 8 13" aria-hidden>
      <path d="M1.5 1.5 6.5 6.5 1.5 11.5" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

export default function Vault() {
  const counts = useLiveQuery(countAll, [])
  const lastBackup = useLiveQuery(() => getSetting<number | null>(LAST_BACKUP_KEY, null), [])

  return (
    <div className="vault">
      <LevelHeader path="/vault" />
      <div className="vault-list">
        <BackupPanel lastBackup={lastBackup} counts={counts} />
        <RestorePanel counts={counts} />
        <StatsPanel counts={counts} />
        <DangerPanel counts={counts} />
        <AboutPanel />
      </div>
    </div>
  )
}

// ---------------- backup ----------------

function backupAge(lastBackup: number | null | undefined) {
  if (lastBackup === undefined) return { label: '…', stale: false }
  if (!lastBackup) return { label: 'Never', stale: true }
  return { label: timeAgo(lastBackup), stale: Date.now() - lastBackup > 7 * DAY }
}

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
            Saved {backupFileName()} with {rows} rows
            {encrypt ? ', encrypted with AES-256. Keep the password somewhere safe: it can’t be recovered.' : '.'}
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

  const nudge =
    lastBackup === null
      ? 'You haven’t made a backup yet. It only takes a second.'
      : stale
        ? 'It’s been over a week since your last backup.'
        : null

  return (
    <Section
      title="Backup"
      footer={
        <>
          {nudge && <span className="vault-footer-warn">{nudge} </span>}
          Your data lives only in this browser. A backup file is the only copy that survives a cleared cache or a lost
          device.
        </>
      }
    >
      <Row
        label="Last backup"
        value={<span className={stale ? 'vault-text-warn' : ''}>{label}</span>}
      />
      <label className="vault-row vault-row-toggle">
        <div className="vault-row-main">
          <div className="vault-row-label">Encrypt with a password</div>
        </div>
        <input
          type="checkbox"
          role="switch"
          className="vault-switch"
          checked={encrypt}
          onChange={(e) => setEncrypt(e.target.checked)}
        />
      </label>
      {encrypt && (
        <>
          <div className="vault-row vault-row-field">
            <input
              className="vault-field"
              type="password"
              placeholder="Password (at least 8 characters)"
              aria-label="Password"
              autoComplete="new-password"
              value={pw}
              onChange={(e) => setPw(e.target.value)}
            />
          </div>
          <div className="vault-row vault-row-field">
            <input
              className="vault-field"
              type="password"
              placeholder="Repeat password"
              aria-label="Repeat password"
              autoComplete="new-password"
              value={pw2}
              onChange={(e) => setPw2(e.target.value)}
            />
          </div>
          <div className="vault-row vault-row-note">
            {pwProblem && (pw || pw2) ? (
              <span className="vault-text-warn">{pwProblem}</span>
            ) : (
              <span>PBKDF2-SHA256 (250k rounds) with AES-GCM 256. There’s no way to recover a forgotten password.</span>
            )}
          </div>
        </>
      )}
      <button className="vault-row vault-action" onClick={exportNow} disabled={busy || !!pwProblem}>
        <span className="vault-row-label">{busy ? (encrypt ? 'Encrypting…' : 'Exporting…') : 'Download backup'}</span>
        {counts && <span className="vault-row-value">{total(counts)} rows</span>}
      </button>
      <NoticeBox notice={notice} />
    </Section>
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
      setNotice({ tone: 'ok', text: `Restore complete. ${n} rows loaded, and everything now matches the backup.` })
      reset()
    } catch (e) {
      setNotice({ tone: 'error', text: errMsg(e) })
    } finally {
      setBusy(false)
    }
  }

  const footer =
    state.step === 'preview' ? (
      <>
        <span className="vault-footer-warn">Restoring replaces all current data with this file.</span> It happens in a
        single step, so if anything fails nothing changes. You may want to download a backup of your current data
        first.
        {state.backup.ignored.length > 0 && <> Ignoring unknown tables: {state.backup.ignored.join(', ')}.</>}
      </>
    ) : (
      'Load a plain or encrypted backup file. You’ll see exactly what’s inside before anything changes.'
    )

  return (
    <Section title="Restore" footer={footer}>
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
        <button className="vault-row vault-action" onClick={() => fileRef.current?.click()}>
          <span className="vault-row-label">Choose backup file…</span>
          <Chevron />
        </button>
      )}

      {state.step === 'locked' && (
        <form
          onSubmit={(e) => {
            e.preventDefault()
            unlock()
          }}
        >
          <Row label="File" value={<span className="vault-ellipsis">{state.fileName}</span>} sub="Encrypted" />
          <div className="vault-row vault-row-field">
            <input
              className="vault-field"
              type="password"
              placeholder="Backup password"
              aria-label="Backup password"
              autoComplete="current-password"
              autoFocus
              value={pw}
              onChange={(e) => setPw(e.target.value)}
            />
          </div>
          <button className="vault-row vault-action" type="submit" disabled={busy || !pw}>
            <span className="vault-row-label">{busy ? 'Decrypting…' : 'Unlock'}</span>
          </button>
          <button className="vault-row vault-action vault-action-muted" type="button" onClick={reset} disabled={busy}>
            <span className="vault-row-label">Cancel</span>
          </button>
        </form>
      )}

      {state.step === 'preview' && (
        <>
          <Row
            label={<span className="vault-ellipsis">{state.fileName}</span>}
            sub={
              <>
                {state.backup.exportedAt
                  ? `Exported ${new Date(state.backup.exportedAt).toLocaleString()} (${timeAgo(Date.parse(state.backup.exportedAt))})`
                  : 'Export date unknown'}
                {' · '}format v{state.backup.version}
                {state.encrypted && ' · decrypted'}
              </>
            }
          />
          <div className="vault-row vault-row-head">
            <span className="vault-row-label">Table</span>
            <span className="vault-compare">
              <span>Now</span>
              <span>Backup</span>
            </span>
          </div>
          {TABLES.map((t) => {
            const now = counts?.[t] ?? 0
            const next = state.backup.data[t].length
            return (
              <div className="vault-row" key={t}>
                <span className="vault-row-label">{TABLE_LABELS[t]}</span>
                <span className="vault-compare">
                  <span className="vault-muted">{now}</span>
                  <span className={next < now ? 'vault-text-warn' : ''}>{next}</span>
                </span>
              </div>
            )
          })}
          <div className="vault-row vault-row-total">
            <span className="vault-row-label">Total</span>
            <span className="vault-compare">
              <span className="vault-muted">{counts ? total(counts) : 0}</span>
              <span>{total(countsOf(state.backup.data))}</span>
            </span>
          </div>
          <button className="vault-row vault-action" onClick={confirmRestore} disabled={busy}>
            <span className="vault-row-label">{busy ? 'Restoring…' : 'Replace everything with this backup'}</span>
          </button>
          <button className="vault-row vault-action vault-action-muted" onClick={reset} disabled={busy}>
            <span className="vault-row-label">Cancel</span>
          </button>
        </>
      )}
      <NoticeBox notice={notice} />
    </Section>
  )
}

// ---------------- storage ----------------

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

  const pct = estimate && estimate !== 'unsupported' && estimate.quota ? (estimate.usage / estimate.quota) * 100 : 0

  const persistText: Record<Persist, string> = {
    unknown: 'Checking storage…',
    persisted: 'Storage is persistent, so the browser won’t clear Tower data when space runs low.',
    'not-persisted': 'Storage is best-effort, so the browser may clear data if the device runs low on space.',
    denied: 'The browser declined for now. Installing the app or using it often usually earns persistent storage.',
    unsupported: 'This browser doesn’t support persistent storage requests.',
  }

  return (
    <Section
      title="Storage"
      footer={<>{persistText[persist]} Usage is approximate and includes the app’s cached files.</>}
    >
      <div className="vault-row vault-row-stack">
        <div className="vault-row-line">
          <span className="vault-row-label">Used on this device</span>
          <span className="vault-row-value">
            {estimate === null
              ? '…'
              : estimate === 'unsupported'
                ? 'n/a'
                : `${formatBytes(estimate.usage)} of ${formatBytes(estimate.quota)}`}
          </span>
        </div>
        <div className="vault-meter" aria-hidden>
          <span style={{ width: `${Math.max(pct, pct > 0 ? 1 : 0)}%` }} />
        </div>
      </div>
      {TABLES.map((t) => (
        <Row key={t} label={TABLE_LABELS[t]} value={counts ? counts[t] : '…'} />
      ))}
      <Row
        label="Persistent storage"
        value={
          persist === 'persisted' ? (
            'On'
          ) : persist === 'unsupported' ? (
            'Not available'
          ) : persist === 'unknown' ? (
            '…'
          ) : (
            <button className="vault-inline-action" onClick={requestPersist} disabled={asking}>
              {asking ? 'Asking…' : 'Turn on'}
            </button>
          )
        }
      />
    </Section>
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
      setNotice({ tone: 'info', text: 'Everything has been erased. Every table is now empty.' })
    } catch (e) {
      setNotice({ tone: 'error', text: errMsg(e) })
    } finally {
      setBusy(false)
    }
  }

  return (
    <Section
      title="Danger zone"
      footer={
        <>
          Permanently erases all {counts ? total(counts) : '…'} rows: deals, truths, lab entries, habits, letters and
          settings. This can’t be undone. Type <strong>{RESET_PHRASE}</strong> to confirm.
        </>
      }
    >
      <div className="vault-row vault-row-field">
        <input
          id="vault-reset"
          className="vault-field"
          aria-label={`Type ${RESET_PHRASE} to confirm`}
          value={phrase}
          onChange={(e) => setPhrase(e.target.value)}
          placeholder={`Type ${RESET_PHRASE}`}
          autoComplete="off"
          autoCapitalize="characters"
          spellCheck={false}
        />
      </div>
      <button className="vault-row vault-action vault-action-danger" onClick={wipe} disabled={!armed || busy}>
        <span className="vault-row-label">{busy ? 'Erasing…' : 'Erase all data'}</span>
      </button>
      <NoticeBox notice={notice} />
    </Section>
  )
}

// ---------------- about ----------------

const LEVEL_BLURBS: Record<string, string> = {
  '/': 'Letters across time, and a quiet look at how today is going.',
  '/negotiator': 'Each morning, agree a plan with Future You: wants, needs and if-then rules.',
  '/truth': 'A private place to say the thing: small lies, avoided conversations, truths about yourself.',
  '/lab': 'Draw random topics, combine them, follow rabbit holes and keep what you learn.',
  '/forge': 'Keystone habits tied to who you want to be, with weekly reviews that help rather than judge.',
}

function AboutPanel() {
  return (
    <Section
      title="About"
      footer="Private by design. There are no accounts, servers, analytics or AI. Everything stays in this browser and never leaves your device unless you export it, which also makes you the backup plan."
    >
      <Row label="Name" value="Samartha Tower" />
      <Row label="Storage" value="On this device only" />
      {LEVELS.filter((l) => l.path !== '/vault').map((l) => (
        <div className="vault-row vault-row-level" key={l.path} style={{ ['--accent' as string]: l.accent }}>
          <span className="vault-level-icon" aria-hidden>
            {l.number}
          </span>
          <div className="vault-row-main">
            <div className="vault-row-label">
              {l.name} <span className="vault-muted">· {l.trait}</span>
            </div>
            <div className="vault-row-sub">{LEVEL_BLURBS[l.path] ?? l.tagline}</div>
          </div>
        </div>
      ))}
    </Section>
  )
}
