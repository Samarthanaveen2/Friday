import { useState } from 'react'
import Keypad from './Keypad'
import { removePin, setPin, verifyPin } from './lock'

export type PinFlowMode = 'set' | 'change' | 'remove'

type Step = 'old' | 'new' | 'confirm'

interface Props {
  mode: PinFlowMode
  onDone: (message: string) => void
  onCancel: () => void
  cancelLabel?: string
}

/** Set, change or remove the chamber PIN. Change/remove require the old PIN. */
export default function PinFlow({ mode, onDone, onCancel, cancelLabel }: Props) {
  const [step, setStep] = useState<Step>(mode === 'set' ? 'new' : 'old')
  const [first, setFirst] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [tick, setTick] = useState(0)
  const [busy, setBusy] = useState(false)

  const fail = (msg: string) => {
    setError(msg)
    setTick((t) => t + 1)
  }

  const handle = async (pin: string) => {
    setBusy(true)
    try {
      if (step === 'old') {
        if (!(await verifyPin(pin))) return fail('That’s not the current PIN.')
        setError(null)
        if (mode === 'remove') {
          await removePin()
          onDone('PIN removed. The chamber is open on this device.')
        } else {
          setStep('new')
          setTick((t) => t + 1)
        }
      } else if (step === 'new') {
        setFirst(pin)
        setError(null)
        setStep('confirm')
        setTick((t) => t + 1)
      } else {
        if (pin !== first) {
          setStep('new')
          setFirst('')
          return fail('Those didn’t match. Let’s try again.')
        }
        await setPin(pin)
        onDone(mode === 'change' ? 'PIN changed.' : 'PIN set. The chamber will lock each time you return.')
      }
    } finally {
      setBusy(false)
    }
  }

  const title =
    step === 'old' ? 'Enter current PIN' : step === 'new' ? (mode === 'change' ? 'Choose a new PIN' : 'Choose a PIN') : 'Once more to confirm'
  const subtitle = step === 'old' ? (mode === 'remove' ? 'To remove the lock' : 'To change the lock') : step === 'new' ? '4 to 6 digits' : undefined

  return (
    <Keypad
      title={title}
      subtitle={subtitle}
      error={error}
      errorTick={tick}
      busy={busy}
      submitLabel={step === 'confirm' ? 'Confirm' : step === 'old' && mode === 'remove' ? 'Remove PIN' : 'Next'}
      onSubmit={handle}
      onCancel={onCancel}
      cancelLabel={cancelLabel}
    />
  )
}
