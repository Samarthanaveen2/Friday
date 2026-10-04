import type { ReactNode } from 'react'
import { LEVELS } from '../lib/levels'

/** Standard header for a level page. `path` must match an entry in LEVELS. */
export default function LevelHeader({ path, right }: { path: string; right?: ReactNode }) {
  const level = LEVELS.find((l) => l.path === path)!
  return (
    <header className="level-header row-between" style={{ ['--accent' as string]: level.accent }}>
      <div>
        <div className="level-number">
          Level {level.number} · {level.trait}
        </div>
        <h1 className="level-title">{level.name}</h1>
        <p className="level-tagline">{level.tagline}</p>
      </div>
      {right}
    </header>
  )
}
