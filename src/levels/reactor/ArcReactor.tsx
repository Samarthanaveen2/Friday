export interface ReactorRing {
  label: string
  color: string
  value: number // 0..1
}

/** Animated arc reactor. Inner rings = per-level progress; core brightness = total power. */
export default function ArcReactor({ power, rings }: { power: number; rings: ReactorRing[] }) {
  const p = Math.max(0, Math.min(100, power)) / 100
  const C = 150
  const radii = [104, 90, 76, 62]
  const segments = Array.from({ length: 10 }, (_, i) => i * 36)
  const ticks = Array.from({ length: 60 }, (_, i) => i * 6)

  return (
    <div className="rx-reactor" style={{ ['--power' as string]: p }} role="img" aria-label={`Reactor at ${power} percent power`}>
      <svg viewBox="0 0 300 300" className="rx-reactor-svg">
        <defs>
          <radialGradient id="rx-core" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="#ffffff" />
            <stop offset="35%" stopColor="#bff4ff" />
            <stop offset="70%" stopColor="#4fd8ff" stopOpacity="0.8" />
            <stop offset="100%" stopColor="#4fd8ff" stopOpacity="0" />
          </radialGradient>
          <radialGradient id="rx-halo" cx="50%" cy="50%" r="50%">
            <stop offset="55%" stopColor="#4fd8ff" stopOpacity="0" />
            <stop offset="80%" stopColor="#4fd8ff" stopOpacity="0.16" />
            <stop offset="100%" stopColor="#4fd8ff" stopOpacity="0" />
          </radialGradient>
          <filter id="rx-blur" x="-50%" y="-50%" width="200%" height="200%">
            <feGaussianBlur stdDeviation="3" />
          </filter>
        </defs>

        <circle cx={C} cy={C} r={148} fill="url(#rx-halo)" className="rx-halo" />

        {/* outer tick ring, slow spin */}
        <g className="rx-spin rx-spin-slow">
          {ticks.map((a) => (
            <line
              key={a}
              x1={C}
              y1={C - 142}
              x2={C}
              y2={C - (a % 30 === 0 ? 132 : 137)}
              transform={`rotate(${a} ${C} ${C})`}
              className={a % 30 === 0 ? 'rx-tick rx-tick-major' : 'rx-tick'}
            />
          ))}
        </g>

        {/* dashed rings counter-rotating */}
        <g className="rx-spin rx-spin-rev">
          <circle cx={C} cy={C} r={126} className="rx-dash rx-dash-a" />
        </g>
        <g className="rx-spin rx-spin-med">
          <circle cx={C} cy={C} r={118} className="rx-dash rx-dash-b" />
        </g>

        {/* level rings */}
        {rings.map((ring, i) => {
          const r = radii[i] ?? 60 - i * 10
          const circ = 2 * Math.PI * r
          const v = Math.max(0, Math.min(1, ring.value))
          return (
            <g key={ring.label} className={'rx-level-ring' + (v >= 1 ? ' rx-full' : v > 0 ? ' rx-on' : '')} style={{ ['--ring' as string]: ring.color }}>
              <circle cx={C} cy={C} r={r} className="rx-track" />
              <circle
                cx={C}
                cy={C}
                r={r}
                className="rx-progress"
                strokeDasharray={`${circ * v} ${circ}`}
                transform={`rotate(-90 ${C} ${C})`}
              />
            </g>
          )
        })}

        {/* coil segments */}
        <g className="rx-spin rx-spin-coil">
          {segments.map((a) => (
            <rect key={a} x={C - 5} y={C - 52} width={10} height={14} rx={2} transform={`rotate(${a} ${C} ${C})`} className="rx-coil" />
          ))}
        </g>

        {/* core */}
        <circle cx={C} cy={C} r={36} className="rx-core-ring" />
        <circle cx={C} cy={C} r={34} fill="url(#rx-core)" className="rx-core-glow" filter="url(#rx-blur)" />
        <circle cx={C} cy={C} r={22} fill="url(#rx-core)" className="rx-core" />
        <polygon points={`${C},${C - 26} ${C + 22.5},${C + 13} ${C - 22.5},${C + 13}`} className="rx-tri" />
      </svg>
    </div>
  )
}
