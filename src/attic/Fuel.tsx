import { useMemo, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useLiveQuery } from 'dexie-react-hooks'
import { db } from '../db/db'
import type { Dare } from '../db/types'
import { downloadText, exportJson, importJson } from './backup'
import { CATEGORY_FACET, FACETS, FACET_INFO, categoriesOf, type Facet } from './facets'
import { activeDays, categoryCounts, facetScores, POINTS, recentScores, streak, weakestFacet, WINDOW_DAYS } from './fuel'
import type { LabEntryX } from './shared'
import { CATEGORIES, CATEGORY_COLORS, type Category } from './topics'

function setFilter(cats: Category[]) {
  try {
    localStorage.setItem('lab.filter', JSON.stringify(cats))
  } catch {
    /* ignore */
  }
}

export default function Fuel() {
  const navigate = useNavigate()
  const entries = useLiveQuery(() => db.lab.toArray(), []) as LabEntryX[] | undefined
  const dares = useLiveQuery(() => db.dares.toArray(), []) as Dare[] | undefined
  const fileRef = useRef<HTMLInputElement>(null)
  const [msg, setMsg] = useState('')

  const stats = useMemo(() => {
    const e = entries ?? []
    const d = dares ?? []
    const recent = recentScores(e, d)
    const all = facetScores(e, d)
    const recentTotal = FACETS.reduce((n, f) => n + recent[f], 0)
    const max = Math.max(1, ...FACETS.map((f) => recent[f]))
    const counts = categoryCounts(e)
    const untouched = CATEGORIES.filter((c) => !counts.get(c))
    return {
      recent,
      all,
      recentTotal,
      max,
      weakest: weakestFacet(recent),
      streak: streak(activeDays(e, d)),
      daresDone: d.filter((x) => x.status === 'done').length,
      untouched,
    }
  }, [entries, dares])

  if (!entries || !dares) return <div className="empty">Measuring your fuel…</div>

  const spinFacet = (f: Facet) => {
    setFilter(categoriesOf(f))
    navigate('/')
  }
  const spinCategory = (c: Category) => {
    setFilter([c])
    navigate('/')
  }

  const doExport = async () => {
    downloadText(await exportJson())
    setMsg('Backup downloaded.')
  }
  const doImport = async (file: File | undefined) => {
    if (!file) return
    try {
      const added = await importJson(await file.text())
      setMsg(`Imported ${added.lab} entr${added.lab === 1 ? 'y' : 'ies'} and ${added.dares} dare${added.dares === 1 ? '' : 's'}.`)
    } catch (e) {
      setMsg(e instanceof Error ? e.message : String(e))
    } finally {
      if (fileRef.current) fileRef.current.value = ''
    }
  }

  const weak = FACET_INFO[stats.weakest]

  return (
    <div className="stack">
      <section className="attic-fuel-stats">
        <div className="panel">
          <div className="panel-title">Fuel · last {WINDOW_DAYS} days</div>
          <div className="big-number">{stats.recentTotal}</div>
        </div>
        <div className="panel">
          <div className="panel-title">Streak</div>
          <div className="big-number">
            {stats.streak}
            <span className="attic-unit"> day{stats.streak === 1 ? '' : 's'}</span>
          </div>
        </div>
        <div className="panel">
          <div className="panel-title">Dares done</div>
          <div className="big-number">{stats.daresDone}</div>
        </div>
      </section>

      <section className="panel stack">
        <div>
          <h3 className="lab-save-title">Your openness</h3>
          <p className="small muted">
            Each topic you log feeds its facet ({POINTS.topic} point, +{POINTS.wrote} if you write about it). Each dare done adds {POINTS.dare}.
          </p>
        </div>
        <div className="attic-bars">
          {FACETS.map((f) => {
            const info = FACET_INFO[f]
            const v = stats.recent[f]
            const low = f === stats.weakest
            return (
              <div key={f} className={`attic-bar-row${low ? ' low' : ''}`} style={{ ['--c' as string]: info.color }}>
                <div className="attic-bar-head">
                  <span className="attic-bar-name">
                    {info.name}
                    {low && <span className="attic-low-tag">Running low</span>}
                  </span>
                  <span className="attic-bar-val">
                    {v}
                    <span className="muted"> · {stats.all[f]} all time</span>
                  </span>
                </div>
                <div className="attic-bar-track" role="meter" aria-label={`${info.name} fuel`} aria-valuemin={0} aria-valuemax={stats.max} aria-valuenow={v}>
                  <div className="attic-bar-fill" style={{ width: `${Math.max(2, (v / stats.max) * 100)}%` }} />
                </div>
                <p className="attic-bar-blurb">{info.blurb}</p>
              </div>
            )
          })}
        </div>
      </section>

      <section className="panel stack lab-totd" style={{ ['--c' as string]: weak.color }}>
        <div className="lab-totd-eyebrow">
          <span>Feed this next</span>
        </div>
        <h2 className="lab-totd-name" style={{ color: weak.color }}>
          {weak.name}
        </h2>
        <p className="lab-totd-hook">{weak.blurb}</p>
        <p className="small muted">
          Draws from {categoriesOf(stats.weakest).join(', ')}.
        </p>
        <div className="row">
          <button className="btn btn-gold" onClick={() => spinFacet(stats.weakest)}>
            Spin {weak.name.toLowerCase()} topics
          </button>
          <button className="btn lab-btn-tint" onClick={() => navigate(`/dares?facet=${stats.weakest}`)}>
            Dare me ({weak.name.toLowerCase()})
          </button>
        </div>
      </section>

      {stats.untouched.length > 0 && (
        <section className="panel stack">
          <div>
            <h3 className="lab-save-title">Rooms you’ve never opened</h3>
            <p className="small muted">
              {stats.untouched.length} of {CATEGORIES.length} categories have never been explored. Tap one to spin it.
            </p>
          </div>
          <div className="lab-chips attic-wrap" role="group" aria-label="Unexplored categories">
            {stats.untouched.map((c) => (
              <button
                key={c}
                className="chip lab-chip"
                style={{ ['--c' as string]: CATEGORY_COLORS[c] }}
                onClick={() => spinCategory(c)}
                title={FACET_INFO[CATEGORY_FACET[c]].name}
              >
                <i className="lab-chip-dot" aria-hidden /> {c}
              </button>
            ))}
          </div>
        </section>
      )}

      <section className="panel stack">
        <div>
          <h3 className="lab-save-title">Backup</h3>
          <p className="small muted">Everything lives only in this browser. Download a copy now and then. Importing merges and never deletes.</p>
        </div>
        <div className="row">
          <button className="btn" onClick={doExport}>
            Download backup
          </button>
          <button className="btn" onClick={() => fileRef.current?.click()}>
            Import backup
          </button>
          <input ref={fileRef} type="file" accept="application/json,.json" hidden onChange={(e) => doImport(e.target.files?.[0])} />
        </div>
        {msg && <p className="small muted">{msg}</p>}
      </section>
    </div>
  )
}
