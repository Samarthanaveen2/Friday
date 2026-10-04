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
const LETTERS: Record<string, string> = { '2': 'ABC', '3': 'DEF', '4': 'GHI', '5': 'JKL', '6': 'MNO', '7': 'PQRS', '8': 'TUV', '9': 'WXYZ' }

export default function Keypad({ title, subtitle, error, errorTick = 0, submitLabel = 'Enter', onSubmit, onCancel, cancelLabel = 'Cancel', busy }: Props) {
  const [pin, setPin] = useState('')
  const [shaking, setShaking] = useState(false)

  useEffect(() => {
    if (!errorTick) return
    setPin('')
    if (!error) return
    setShaking(true)
    const t = setTimeout(() => setShaking(false), 400)
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

  const dots = Math.max(4, pin.length)
  const canSubmit = pin.length >= 4 && !busy

  return (
    <div className="truth-keypad">
      <div className="truth-keypad-title">{title}</div>
      <div className="truth-keypad-sub">{subtitle || '\u00a0'}</div>
      <div className={`truth-dots ${shaking ? 'truth-shake' : ''}`} aria-label={`${pin.length} digits entered`}>
        {Array.from({ length: dots }, (_, i) => (
          <span key={i} className={`truth-dot ${i < pin.length ? 'filled' : ''}`} />
        ))}
      </div>
      <div className="truth-keypad-error" role="alert">
        {error || '\u00a0'}
      </div>
      <div className="truth-keys">
        {KEYS.map((k) => (
          <button key={k} type="button" className="truth-key" onClick={() => press(k)}>
            <span className="truth-key-digit">{k}</span>
            <span className="truth-key-letters">{LETTERS[k] || '\u00a0'}</span>
          </button>
        ))}
        {onCancel ? (
          <button type="button" className="truth-key-text" onClick={onCancel}>
            {cancelLabel}
          </button>
        ) : (
          <span />
        )}
        <button type="button" className="truth-key" onClick={() => press('0')}>
          <span className="truth-key-digit">0</span>
        </button>
        <button type="button" className="truth-key-text" onClick={back} aria-label="Delete digit" disabled={!pin}>
          Delete
        </button>
      </div>
      <button type="button" className="btn truth-btn-primary truth-keypad-submit" onClick={submit} disabled={!canSubmit}>
        {submitLabel}
      </button>
    </div>
  )
}
