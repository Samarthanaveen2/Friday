import { useEffect, useState } from 'react'

interface Props {
  title: string
  subtitle?: string
  error?: string | null
  /** Changes to this number clear the entry (and shake if `error` is set). */
  errorTick?: number
  submitLabel?: string
  onSubmit: (pin: string) => void
  onCancel?: () => void
  cancelLabel?: string
  busy?: boolean
}

const KEYS = ['1', '2', '3', '4', '5', '6', '7', '8', '9']

export default function Keypad({ title, subtitle, error, errorTick = 0, submitLabel = 'Enter', onSubmit, onCancel, cancelLabel = 'Cancel', busy }: Props) {
  const [pin, setPin] = useState('')
  const [shaking, setShaking] = useState(false)

  useEffect(() => {
    if (!errorTick) return
    setPin('')
    if (!error) return
    setShaking(true)
    const t = setTimeout(() => setShaking(false), 450)
    return () => clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [errorTick])

  const press = (d: string) => setPin((p) => (p.length >= 6 ? p : p + d))
  const back = () => setPin((p) => p.slice(0, -1))
  const submit = () => {
    if (pin.length >= 4 && !busy) {
      onSubmit(pin)
    }
  }

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement | null
      if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA')) return
      if (/^\d$/.test(e.key)) press(e.key)
      else if (e.key === 'Backspace') back()
      else if (e.key === 'Enter' && target?.tagName !== 'BUTTON') submit()
      else if (e.key === 'Escape' && onCancel) onCancel()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  })

  return (
    <div className={`truth-keypad ${shaking ? 'truth-shake' : ''}`}>
      <div className="truth-keypad-title">{title}</div>
      {subtitle && <div className="truth-keypad-sub muted small">{subtitle}</div>}
      <div className="truth-dots" aria-label={`${pin.length} digits entered`}>
        {Array.from({ length: 6 }, (_, i) => (
          <span key={i} className={`truth-dot ${i < pin.length ? 'filled' : ''} ${i >= 4 ? 'optional' : ''}`} />
        ))}
      </div>
      <div className="truth-keypad-error small" role="alert">
        {error || ' '}
      </div>
      <div className="truth-keys">
        {KEYS.map((k) => (
          <button key={k} type="button" className="truth-key" onClick={() => press(k)}>
            {k}
          </button>
        ))}
        <button type="button" className="truth-key truth-key-fn" onClick={back} aria-label="Delete digit" disabled={!pin}>
          ⌫
        </button>
        <button type="button" className="truth-key" onClick={() => press('0')}>
          0
        </button>
        <button type="button" className="truth-key truth-key-go" onClick={submit} disabled={pin.length < 4 || busy} aria-label={submitLabel}>
          ↵
        </button>
      </div>
      <div className="row" style={{ justifyContent: 'center' }}>
        <button type="button" className="btn btn-sm truth-btn-red" onClick={submit} disabled={pin.length < 4 || busy}>
          {submitLabel}
        </button>
        {onCancel && (
          <button type="button" className="btn btn-ghost btn-sm" onClick={onCancel}>
            {cancelLabel}
          </button>
        )}
      </div>
    </div>
  )
}
