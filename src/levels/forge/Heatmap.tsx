import { useState } from 'react'
import { fromDayKey, prettyDay } from '../../lib/date'
import { HEATMAP_WEEKS, heatmapGrid, type DoneIndex, type ForgeHabit } from './stats'

const DAY_LABELS = ['Mon', '', 'Wed', '', 'Fri', '', 'Sun']

function level(v: number, count: number): number {
  if (count === 0) return 0
  if (v < 0.34) return 1
  if (v < 0.67) return 2
  if (v < 1) return 3
  return 4
}

export default function Heatmap({ habits, idx }: { habits: ForgeHabit[]; idx: DoneIndex }) {
  const active = habits.filter((h) => !h.archived)
  const [sel, setSel] = useState<number | 'all'>('all')
  const chosen = sel === 'all' ? active : habits.filter((h) => h.id === sel)
  const cols = heatmapGrid(chosen, idx)

  const cells = cols.flat().filter((c) => !c.future)
  const votes = cells.reduce((a, c) => a + c.count, 0)
  const activeDays = cells.filter((c) => c.count > 0).length

  const months = cols.map((col, i) => {
    const d = fromDayKey(col[0].key)
    const prev = i > 0 ? fromDayKey(cols[i - 1][0].key) : null
    return !prev || prev.getMonth() !== d.getMonth() ? d.toLocaleDateString(undefined, { month: 'short' }) : ''
  })

  if (active.length === 0 && habits.length === 0) {
    return <div className="empty">Your heatmap fills in as you check off habits.</div>
  }

  return (
    <section className="panel forge-panel">
      <div className="row-between forge-heat-head">
        <div className="panel-title forge-tight">Last {HEATMAP_WEEKS} weeks</div>
        <div className="muted small mono">
          {votes} check-ins · {activeDays} active days
        </div>
      </div>

      <div className="forge-presets forge-heat-tabs">
        <button className={`chip forge-chip ${sel === 'all' ? 'active' : ''}`} onClick={() => setSel('all')}>
          All habits
        </button>
        {active.map((h) => (
          <button key={h.id} className={`chip forge-chip ${sel === h.id ? 'active' : ''}`} onClick={() => setSel(h.id!)}>
            {h.name}
          </button>
        ))}
      </div>

      {sel !== 'all' && <p className="forge-identity small forge-heat-id">{chosen[0]?.identity}</p>}

      <div className="forge-heat" style={{ ['--weeks' as string]: HEATMAP_WEEKS }}>
        <div className="forge-heat-months">
          <span />
          {months.map((m, i) => (
            <span key={i}>{m}</span>
          ))}
        </div>
        <div className="forge-heat-body">
          <div className="forge-heat-days">
            {DAY_LABELS.map((l, i) => (
              <span key={i}>{l}</span>
            ))}
          </div>
          {cols.map((col, i) => (
            <div key={i} className="forge-heat-col">
              {col.map((c) => (
                <span
                  key={c.key}
                  className={`forge-heat-cell l${level(c.value, c.count)} ${c.future ? 'future' : ''}`}
                  title={c.future ? '' : `${prettyDay(c.key)}: ${c.total ? `${c.count}/${c.total}` : 'no habits yet'}`}
                />
              ))}
            </div>
          ))}
        </div>
      </div>

      <div className="row-between forge-heat-legend small muted">
        <span>Empty squares are rest days. Notice the filled ones.</span>
        <span className="row forge-legend-scale">
          Less
          {[0, 1, 2, 3, 4].map((l) => (
            <span key={l} className={`forge-heat-cell l${l}`} />
          ))}
          More
        </span>
      </div>
    </section>
  )
}
