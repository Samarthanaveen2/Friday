import { useEffect, useRef, useState } from 'react'
import { NavLink, Navigate, Route, Routes } from 'react-router-dom'
import { useLiveQuery } from 'dexie-react-hooks'
import LevelHeader from '../../components/LevelHeader'
import { db, getSetting, setSetting } from '../../db/db'
import Confess from './Confess'
import Ledger from './Ledger'
import Patterns from './Patterns'
import Keypad from './Keypad'
import PinFlow, { type PinFlowMode } from './PinFlow'
import { HIDDEN_RELOCK_MS, PIN_KEY, PIN_OFFERED_KEY, getStoredPin, lockTruth, unlockTruth } from './lock'
import { CheckIcon, LockIcon } from './icons'
import './truth.css'

type Phase = 'loading' | 'offer' | 'setup' | 'locked' | 'open'

const HONEST_NOTE = 'The PIN keeps out casual eyes. Your entries are stored unencrypted in this browser, on this device only.'

export default function Truth() {
  const [phase, setPhase] = useState<Phase>('loading')
  const [error, setError] = useState<string | null>(null)
  const [tick, setTick] = useState(0)
  const [busy, setBusy] = useState(false)
  const [pinMode, setPinMode] = useState<PinFlowMode | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const hiddenAt = useRef<number | null>(null)
  const pinRow = useLiveQuery(() => db.settings.get(PIN_KEY), [])
  const hasPin = !!pinRow

  // Locked on every visit: reset unlock state on mount and when leaving.
  useEffect(() => {
    let alive = true
    lockTruth()
    ;(async () => {
      const [pin, offered] = await Promise.all([getStoredPin(), getSetting<boolean>(PIN_OFFERED_KEY, false)])
      if (!alive) return
      setPhase(pin ? 'locked' : offered ? 'open' : 'offer')
    })()
    return () => {
      alive = false
      lockTruth()
    }
  }, [])

  // Re-lock after being hidden for a while.
  useEffect(() => {
    const onVis = async () => {
      if (document.visibilityState === 'hidden') {
        hiddenAt.current = Date.now()
        return
      }
      const since = hiddenAt.current
      hiddenAt.current = null
      if (since && Date.now() - since >= HIDDEN_RELOCK_MS && (await getStoredPin())) {
        lockTruth()
        setPinMode(null)
        setPhase('locked')
      }
    }
    document.addEventListener('visibilitychange', onVis)
    return () => document.removeEventListener('visibilitychange', onVis)
  }, [])

  // Clear transient notices.
  useEffect(() => {
    if (!notice) return
    const t = setTimeout(() => setNotice(null), 4000)
    return () => clearTimeout(t)
  }, [notice])

  const tryUnlock = async (pin: string) => {
    setBusy(true)
    try {
      if (await unlockTruth(pin)) {
        setError(null)
        setPhase('open')
      } else {
        setError('Not quite. Take a breath and try again.')
        setTick((t) => t + 1)
      }
    } finally {
      setBusy(false)
    }
  }

  const skipOffer = async () => {
    await setSetting(PIN_OFFERED_KEY, true)
    setPhase('open')
  }

  const lockNow = () => {
    lockTruth()
    setPinMode(null)
    setError(null)
    setPhase('locked')
  }

  const header = (
    <LevelHeader
      path="/truth"
      right={
        phase === 'open' ? (
          <div className="row truth-header-actions">
            {hasPin && (
              <button type="button" className="btn btn-sm" onClick={lockNow} title="Lock this page">
                <LockIcon /> Lock
              </button>
            )}
            <button type="button" className="btn btn-ghost btn-sm truth-ghost" onClick={() => setPinMode(pinMode ? null : hasPin ? 'change' : 'set')}>
              {pinMode ? 'Close' : 'PIN settings'}
            </button>
          </div>
        ) : undefined
      }
    />
  )

  if (phase === 'loading')
    return (
      <div className="truth">
        {header}
        <div className="empty">Loading…</div>
      </div>
    )

  if (phase === 'offer' || phase === 'setup')
    return (
      <div className="truth">
        {header}
        <section className="panel truth-panel truth-gate">
          {phase === 'offer' ? (
            <div className="stack truth-offer">
              <div className="truth-gate-glyph" aria-hidden>
                <LockIcon size={26} />
              </div>
              <h2>A private room</h2>
              <p className="muted">
                This is where you write down what you lied about, avoided, or told yourself, so you can find the courage to say it. Would you like a PIN to keep it private?
              </p>
              <div className="stack-sm truth-offer-actions">
                <button type="button" className="btn truth-btn-primary" onClick={() => setPhase('setup')}>
                  Set a PIN
                </button>
                <button type="button" className="btn btn-ghost truth-ghost" onClick={skipOffer}>
                  Skip for now
                </button>
              </div>
              <p className="small muted truth-note">{HONEST_NOTE} You can add a PIN later.</p>
            </div>
          ) : (
            <>
              <PinFlow
                mode="set"
                onDone={(msg) => {
                  setNotice(msg)
                  setPhase('open')
                }}
                onCancel={() => setPhase('offer')}
                cancelLabel="Back"
              />
              <p className="small muted truth-note">{HONEST_NOTE}</p>
            </>
          )}
        </section>
      </div>
    )

  if (phase === 'locked')
    return (
      <div className="truth">
        {header}
        <section className="panel truth-panel truth-gate">
          <Keypad title="Enter PIN" subtitle="Truth is locked" error={error} errorTick={tick} busy={busy} submitLabel="Unlock" onSubmit={tryUnlock} />
          <p className="small muted truth-note">{HONEST_NOTE}</p>
        </section>
      </div>
    )

  return (
    <div className="truth">
      {header}

      {notice && (
        <div className="truth-notice" role="status">
          <CheckIcon /> {notice}
        </div>
      )}

      {pinMode && (
        <section className="panel truth-panel truth-pin-settings">
          <div className="truth-pin-head">
            <div className="truth-section-title">PIN settings</div>
            {hasPin && (
              <div className="truth-seg truth-seg-sm" role="tablist">
                <button type="button" role="tab" aria-selected={pinMode === 'change'} className={`truth-seg-btn ${pinMode === 'change' ? 'active' : ''}`} onClick={() => setPinMode('change')}>
                  Change
                </button>
                <button type="button" role="tab" aria-selected={pinMode === 'remove'} className={`truth-seg-btn ${pinMode === 'remove' ? 'active' : ''}`} onClick={() => setPinMode('remove')}>
                  Remove
                </button>
              </div>
            )}
          </div>
          <PinFlow
            key={pinMode}
            mode={hasPin ? pinMode : 'set'}
            onDone={(msg) => {
              setNotice(msg)
              setPinMode(null)
            }}
            onCancel={() => setPinMode(null)}
          />
          <p className="small muted truth-note">
            {HONEST_NOTE} {hasPin ? 'It re-locks every visit and after 2 minutes away.' : ''}
          </p>
        </section>
      )}

      <nav className="truth-seg truth-tabs" aria-label="Truth sections">
        <NavLink end to="/truth" className={({ isActive }) => `truth-seg-btn ${isActive ? 'active' : ''}`}>
          Confess
        </NavLink>
        <NavLink to="/truth/ledger" className={({ isActive }) => `truth-seg-btn ${isActive ? 'active' : ''}`}>
          Ledger
        </NavLink>
        <NavLink to="/truth/patterns" className={({ isActive }) => `truth-seg-btn ${isActive ? 'active' : ''}`}>
          Patterns
        </NavLink>
      </nav>

      <Routes>
        <Route index element={<Confess />} />
        <Route path="ledger" element={<Ledger />} />
        <Route path="patterns" element={<Patterns />} />
        <Route path="*" element={<Navigate to="/truth" replace />} />
      </Routes>
    </div>
  )
}
