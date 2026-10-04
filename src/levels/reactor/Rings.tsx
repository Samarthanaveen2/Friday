import { useEffect, useState } from 'react'

export interface ActivityRing {
  label: string
  color: string
  value: number // 0..1
}

/** Activity-style concentric rings — outermost is the first ring. */
export default function Rings({ rings, size = 200 }: { rings: ActivityRing[]; size?: number }) {
  // Start at zero on mount so the rings animate in, then follow live values.
  const [mounted, setMounted] = useState(false)
  useEffect(() => {
    const id = requestAnimationFrame(() => setMounted(true))
    return () => cancelAnimationFrame(id)
  }, [])

  const V = 200
  const C = V / 2
  const stroke = 18
  const gap = 4
  const avg = rings.length ? Math.round((rings.reduce((s, r) => s + Math.max(0, Math.min(1, r.value)), 0) / rings.length) * 100) : 0

  return (
    <svg
      viewBox={`0 0 ${V} ${V}`}
      width={size}
      height={size}
      className="home-rings"
      role="img"
      aria-label={`Today's progress ${avg} percent. ` + rings.map((r) => `${r.label} ${Math.round(r.value * 100)}%`).join(', ')}
    >
      {rings.map((ring, i) => {
        const r = C - stroke / 2 - 2 - i * (stroke + gap)
        const circ = 2 * Math.PI * r
        const v = mounted ? Math.max(0, Math.min(1, ring.value)) : 0
        return (
          <g key={ring.label} style={{ ['--ring' as string]: ring.color }}>
            <circle cx={C} cy={C} r={r} className="home-ring-track" strokeWidth={stroke} />
            <circle
              cx={C}
              cy={C}
              r={r}
              className="home-ring-fill"
              strokeWidth={stroke}
              strokeDasharray={circ}
              strokeDashoffset={circ * (1 - v)}
              opacity={v > 0 ? 1 : 0}
              transform={`rotate(-90 ${C} ${C})`}
            />
          </g>
        )
      })}
    </svg>
  )
}
